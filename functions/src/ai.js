const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { admin, db } = require("./init");
const { defineSecret } = require("firebase-functions/params");
const { enforceRateLimit, getClientIpFromRawRequest, dayKeyIstanbul } = require("./utils");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

/**
 * AI Çıktısını temizler (Hassas verileri maskeler)
 */
function sanitizeOutput(text) {
  if (!text || typeof text !== 'string') return text;
  let sanitized = text.replace(/\b0?\d{3}[\s-]?\d{3}[\s-]?\d{2}[\s-]?\d{2}\b/g, '***-***-**-**'); // Tel
  sanitized = sanitized.replace(/\b[\w\.-]+@[\w\.-]+\.\w{2,4}\b/g, '***@***.***'); // Email
  sanitized = sanitized.replace(/\b\d{11}\b/g, '***********'); // TC vb.
  return sanitized;
}

/**
 * Ham test verilerini işleyip Gemini için kısa bir özet çıkarır.
 * Bu fonksiyon CPU'da çalışır ve çok hızlıdır.
 */
function createPerformanceSummary(completedTests) {
  if (!completedTests || completedTests.length === 0) {
    return {
      totalSolved: 0,
      weakTopics: "Henüz yeterli veri yok.",
      strongTopics: "Henüz yeterli veri yok.",
      testCount: 0
    };
  }

  const topicStats = {};
  let totalQuestions = 0;

  // 1. Veriyi Oku ve Grupla (Aggregation)
  completedTests.forEach(test => {
    const topic = test.topicName || test.topic || "Genel";
    const correct = parseInt(test.correctCount || 0);
    const total = parseInt(test.questionCount || 0);

    if (!topicStats[topic]) {
      topicStats[topic] = { correct: 0, total: 0 };
    }
    topicStats[topic].correct += correct;
    topicStats[topic].total += total;
    totalQuestions += total;
  });

  // 2. İstatistikleri Hesapla
  const results = Object.keys(topicStats).map(topic => {
    const data = topicStats[topic];
    const accuracy = data.total > 0 ? (data.correct / data.total) * 100 : 0;
    return { topic, accuracy, volume: data.total };
  });

  // 3. Sırala ve Filtrele
  const weakTopics = results
    .filter(r => r.accuracy < 60)
    .sort((a, b) => a.accuracy - b.accuracy)
    .slice(0, 5)
    .map(r => `${r.topic} (%${r.accuracy.toFixed(0)})`)
    .join(", ");

  const strongTopics = results
    .filter(r => r.accuracy > 80)
    .map(r => r.topic)
    .join(", ");

  return {
    totalSolved: totalQuestions,
    weakTopics: weakTopics || "Belirgin bir zayıf konu yok.",
    strongTopics: strongTopics || "Henüz ustalaşılan konu yok.",
    testCount: completedTests.length
  };
}

// --- AYARLAR ---
const GEMINI_PROMPT_MAX_CHARS = parseInt(process.env.GEMINI_PROMPT_MAX_CHARS || "120000", 10);
const DEFAULT_JSON_TOKENS = parseInt(process.env.GEMINI_MAX_OUTPUT_TOKENS_JSON || "8192", 10);
const DEFAULT_TEXT_TOKENS = parseInt(process.env.GEMINI_MAX_OUTPUT_TOKENS_TEXT || "2048", 10);
const GEMINI_RATE_LIMIT_WINDOW_SEC = parseInt(process.env.GEMINI_RATE_LIMIT_WINDOW_SEC || "60", 10);
const GEMINI_RATE_LIMIT_MAX = parseInt(process.env.GEMINI_RATE_LIMIT_MAX || "12", 10);
const GEMINI_RATE_LIMIT_IP_MAX = parseInt(process.env.GEMINI_RATE_LIMIT_IP_MAX || "30", 10);

const PREMIUM_RATE_LIMIT_PER_MINUTE = parseInt(process.env.PREMIUM_RATE_LIMIT_PER_MINUTE || "14", 10);
const PREMIUM_RATE_LIMIT_PER_HOUR = parseInt(process.env.PREMIUM_RATE_LIMIT_PER_HOUR || "500", 10);

const MAX_RETRY_ATTEMPTS = 3;
const RETRY_DELAY_MS = 2000;

// Kategori bazlı aylık limitler
const MONTHLY_LIMITS = {
  workshop: 350,
  weekly_plan: 60,
  chat: 2000,
  question_solver: 1000
};

// Retry Helper
async function retryWithBackoff(fn, maxAttempts = MAX_RETRY_ATTEMPTS, baseDelay = RETRY_DELAY_MS) {
  let lastError;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      const status = error?.response?.status || error?.status;
      const is429 = status === 429 || (error.message && error.message.includes('429'));
      const is503 = status === 503 || (error.message && error.message.includes('503'));

      if ((is429 || is503) && attempt < maxAttempts) {
        const delay = baseDelay * Math.pow(2, attempt - 1);
        logger.warn(`Retry attempt ${attempt}/${maxAttempts} after ${delay}ms`, { error: error.message });
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }
      throw error;
    }
  }
  throw lastError;
}

exports.generateGemini = onCall(
  { region: "us-central1", timeoutSeconds: 300, memory: "512MiB", secrets: [GEMINI_API_KEY], enforceAppCheck: true, maxInstances: 20, concurrency: 10 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Oturum gerekli");
    }

    // 1. Kullanıcı Kontrolleri
    const userDoc = await db.collection("users").doc(request.auth.uid).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "Kullanıcı bulunamadı.");
    }

    const userData = userDoc.data();
    const isPremium = userData.isPremium || false;
    const requestType = request.data?.requestType || 'chat';
    const expectJson = !!request.data?.expectJson;
    let prompt = request.data?.prompt;

    // 2. Limit Kontrolleri (Free / Premium)
    if (!isPremium && requestType === 'question_solver') {
      const today = new Date().toLocaleString('sv-SE', { timeZone: 'Europe/Istanbul' }).substring(0, 10);
      const dailyUsageRef = db.collection("users").doc(request.auth.uid).collection("daily_usage").doc(today);
      const dailyUsageDoc = await dailyUsageRef.get();
      const usageData = dailyUsageDoc.exists ? dailyUsageDoc.data() : {};

      if ((usageData.questions_solved || 0) >= 3) {
        throw new HttpsError("permission-denied", "Günlük 3 soru hakkınız doldu. Premium ile sınırsız çözün.");
      }

      await dailyUsageRef.set({
        questions_solved: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    }

    if (!isPremium && (requestType !== 'question_solver' && requestType !== 'chat')) {
      throw new HttpsError("permission-denied", "Bu özellik yalnızca premium kullanıcılara açıktır.");
    }

    if (!Object.keys(MONTHLY_LIMITS).includes(requestType)) {
      throw new HttpsError("invalid-argument", "Geçersiz işlem türü.");
    }

    // 3. Görsel Kontrolü
    const imageBase64 = typeof request.data?.imageBase64 === 'string' ? request.data.imageBase64.trim() : null;
    const imageMimeType = typeof request.data?.imageMimeType === 'string' ? request.data.imageMimeType.trim() : 'image/jpeg';

    if (requestType === 'question_solver' && !imageBase64) {
      throw new HttpsError("invalid-argument", "Soru görseli gerekli.");
    }

    // 4. Rate Limiting (DoS Koruması)
    const uidKey = `gemini_uid_${request.auth.uid}`;
    const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
    const ipKey = `gemini_ip_${ip}`;

    try {
      await Promise.all([
        enforceRateLimit(uidKey, GEMINI_RATE_LIMIT_WINDOW_SEC, GEMINI_RATE_LIMIT_MAX),
        enforceRateLimit(ipKey, GEMINI_RATE_LIMIT_WINDOW_SEC, GEMINI_RATE_LIMIT_IP_MAX),
        isPremium ? enforceRateLimit(`prem_min_${request.auth.uid}`, 60, PREMIUM_RATE_LIMIT_PER_MINUTE) : Promise.resolve(),
        isPremium ? enforceRateLimit(`prem_hr_${request.auth.uid}`, 3600, PREMIUM_RATE_LIMIT_PER_HOUR) : Promise.resolve(),
      ]);
    } catch (e) {
      throw new HttpsError("resource-exhausted", "Çok fazla istek. Lütfen biraz bekleyin.");
    }

    // 5. Aylık Kota Kontrolü (Premium)
    if (isPremium) {
      const currentMonth = new Date().toLocaleString('sv-SE', { timeZone: 'Europe/Istanbul' }).substring(0, 7);
      const usageRef = db.collection("users").doc(request.auth.uid).collection("monthly_usage").doc(currentMonth);

      await db.runTransaction(async (tx) => {
        const doc = await tx.get(usageRef);
        const current = (doc.exists ? doc.data()[requestType] : 0) || 0;
        if (current >= MONTHLY_LIMITS[requestType]) {
          throw new HttpsError("resource-exhausted", `Aylık ${requestType} limitinize ulaştınız.`);
        }
        tx.set(usageRef, { [requestType]: admin.firestore.FieldValue.increment(1) }, { merge: true });
      });
    }

    // 6. MODEL ve PARAMETRE AYARLARI
    // question_solver ve workshop -> gemini-3 (Güçlü)
    // weekly_plan ve chat -> gemini-2.5 (Hızlı)
    const modelId = (requestType === 'question_solver' || requestType === 'workshop')
      ? "gemini-3-flash-preview"
      : "gemini-2.5-flash";

    let effectiveMaxTokens = expectJson ? DEFAULT_JSON_TOKENS : DEFAULT_TEXT_TOKENS;
    if (requestType === 'weekly_plan') effectiveMaxTokens = 50000;
    if (requestType === 'workshop') effectiveMaxTokens = 10000;

    let temperature = request.data?.temperature || 0.5;
    if (expectJson) temperature = Math.min(temperature, 0.3);

    // --- KRİTİK OPTİMİZASYON: HAFTALIK PLAN İÇİN VERİ ANALİZİ ---
    if (requestType === 'weekly_plan') {
      try {
        // Kullanıcının client'tan ham veriyi göndermesini beklemek yerine,
        // Backend burada hızlıca veriyi çekip özetler.
        const testsSnapshot = await db.collection("users")
          .doc(request.auth.uid)
          .collection("completedTests")
          .orderBy("completedAt", "desc")
          .limit(300) // Son 300 test yeterli bir örneklem
          .get();

        const testsData = testsSnapshot.docs.map(d => d.data());
        const performanceSummary = createPerformanceSummary(testsData);

        // Prompt'a analiz raporunu ekle
        prompt += `\n\n### SİSTEM TARAFINDAN OLUŞTURULAN GÜNCEL ANALİZ RAPORU ###\n` +
                  `- Toplam Çözülen Soru: ${performanceSummary.totalSolved}\n` +
                  `- Analiz Edilen Test Sayısı: ${performanceSummary.testCount}\n` +
                  `- ACİL EĞİLİNMESİ GEREKEN (ZAYIF) KONULAR: [ ${performanceSummary.weakTopics} ]\n` +
                  `- İYİ OLDUĞU KONULAR (Tekrar Yeterli): [ ${performanceSummary.strongTopics} ]\n` +
                  `NOT: Lütfen planı oluştururken bu analiz raporundaki zayıf konulara öncelik ver.`;

        logger.info("Weekly Plan Optimization Applied", { uid: request.auth.uid, summary: performanceSummary });
      } catch (err) {
        logger.error("Weekly plan analysis failed", err);
        // Hata olsa bile devam et, sadece analizsiz plan yapar.
      }
    }
    // -------------------------------------------------------------

    const normalizedPrompt = prompt.replace(/\s+/g, " ").trim();

    // 7. Gemini API Çağrısı
    try {
      const body = {
        contents: [{
          parts: [
            { text: normalizedPrompt },
            ...(requestType === 'question_solver' && imageBase64
              ? [{ inlineData: { mimeType: imageMimeType, data: imageBase64 } }]
              : [])
          ]
        }],
        generationConfig: {
          temperature,
          maxOutputTokens: effectiveMaxTokens,
          ...(expectJson ? { responseMimeType: "application/json" } : {})
        },
        safetySettings: [
          { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE" }
        ]
      };

      const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelId}:generateContent?key=${GEMINI_API_KEY.value()}`;

      const { resp, data } = await retryWithBackoff(async () => {
        const ac = new AbortController();
        const t = setTimeout(() => ac.abort(), 280_000); // 280sn timeout

        const response = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(body),
          signal: ac.signal,
        }).finally(() => clearTimeout(t));

        if (response.status === 429) throw new Error("429 Rate limit exceeded");
        if (!response.ok) throw new Error(`Gemini status ${response.status}`);

        const responseData = await response.json();
        return { resp: response, data: responseData };
      });

      if (data?.candidates?.[0]?.finishReason === 'SAFETY') {
        throw new HttpsError("failed-precondition", "İçerik güvenlik filtresine takıldı.");
      }

      const rawCandidate = data?.candidates?.[0]?.content?.parts?.[0]?.text || "";
      const candidate = sanitizeOutput(rawCandidate);
      const tokensUsed = Number(data?.usageMetadata?.totalTokenCount || 0);

      // 8. Loglama (Maliyet Takibi)
      const day = dayKeyIstanbul();
      db.collection("ai_usage").doc(`${request.auth.uid}_${day}`).set({
        uid: request.auth.uid,
        day,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        calls: admin.firestore.FieldValue.increment(1),
        tokensUsedTotal: admin.firestore.FieldValue.increment(tokensUsed),
        [`models.${modelId}.calls`]: admin.firestore.FieldValue.increment(1),
        [`types.${requestType}.calls`]: admin.firestore.FieldValue.increment(1),
      }, { merge: true }).catch(() => {});

      return { raw: candidate, tokensLimit: effectiveMaxTokens, modelId, tokensUsed };

    } catch (e) {
      logger.error("AI Error", { error: String(e), modelId });
      if (e instanceof HttpsError) throw e;
      if (String(e).includes('429')) throw new HttpsError("resource-exhausted", "Sistem yoğun, lütfen tekrar deneyin.");
      throw new HttpsError("internal", "AI servisi yanıt vermedi.");
    }
  }
);