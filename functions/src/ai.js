const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { admin, db } = require("./init");
const { defineSecret } = require("firebase-functions/params");
const { enforceRateLimit, getClientIpFromRawRequest, dayKeyIstanbul } = require("./utils");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// İçerik moderasyon fonksiyonları - Google Play ve App Store uyumluluk için
function containsInappropriateContent(text) {
  if (!text || typeof text !== 'string') return false;

  const lowerText = text.toLowerCase();

  // Yasaklı kelime listesi (Türkçe ve İngilizce)
  const blockedPatterns = [
    // Şiddet ve zarar içerikli
    /\b(öldür|intihar|zarar ver|kes|yak)\b/gi,
    /\b(kill|suicide|harm|hurt|violence)\b/gi,
    // Cinsel içerik
    /\b(seks|porno|cinsel|sex|porn|sexual)\b/gi,
    // Nefret söylemi
    /\b(ırkçı|racist|nefret|hate)\b/gi,
    // Uyuşturucu ve yasal olmayan içerik
    /\b(uyuşturucu|esrar|kokain|eroin|drug|cocaine|heroin)\b/gi,
    /\b(kumar|bahis|gambl)\b/gi,
    // Silah ve tehlikeli materyaller
    /\b(silah|bomba|patlayıcı|weapon|bomb|explosive)\b/gi,
  ];

  for (const pattern of blockedPatterns) {
    if (pattern.test(text)) {
      return true;
    }
  }

  return false;
}

function sanitizeOutput(text) {
  if (!text || typeof text !== 'string') return text;

  // Telefon numaralarını maskele
  let sanitized = text.replace(/\b0?\d{3}[\s-]?\d{3}[\s-]?\d{2}[\s-]?\d{2}\b/g, '***-***-**-**');

  // E-posta adreslerini maskele
  sanitized = sanitized.replace(/\b[\w\.-]+@[\w\.-]+\.\w{2,4}\b/g, '***@***.***');

  // 11 haneli TC kimlik benzeri sayıları maskele
  sanitized = sanitized.replace(/\b\d{11}\b/g, '***********');

  return sanitized;
}

// Güvenlik ve kötüye kullanım önleme ayarları
// Varsayılanlar maliyeti düşürecek şekilde daraltıldı; env ile aşılabilir.
const GEMINI_PROMPT_MAX_CHARS = parseInt(process.env.GEMINI_PROMPT_MAX_CHARS || "20000", 10);
const DEFAULT_JSON_TOKENS = parseInt(process.env.GEMINI_MAX_OUTPUT_TOKENS_JSON || "8192", 10);
const DEFAULT_TEXT_TOKENS = parseInt(process.env.GEMINI_MAX_OUTPUT_TOKENS_TEXT || "2048", 10);
const GEMINI_RATE_LIMIT_WINDOW_SEC = parseInt(process.env.GEMINI_RATE_LIMIT_WINDOW_SEC || "60", 10);
const GEMINI_RATE_LIMIT_MAX = parseInt(process.env.GEMINI_RATE_LIMIT_MAX || "12", 10); // 5 -> 12 (60 saniyede 12 istek, Gemini free tier: 15/min)
const GEMINI_RATE_LIMIT_IP_MAX = parseInt(process.env.GEMINI_RATE_LIMIT_IP_MAX || "30", 10); // 20 -> 30

// Premium kullanıcılar için ek rate limit ayarları (Cüzdan DoS koruması)
const PREMIUM_RATE_LIMIT_PER_MINUTE = parseInt(process.env.PREMIUM_RATE_LIMIT_PER_MINUTE || "14", 10); // 10 -> 14 (Gemini: 15/min, buffer bırak)
const PREMIUM_RATE_LIMIT_PER_HOUR = parseInt(process.env.PREMIUM_RATE_LIMIT_PER_HOUR || "500", 10); // 100 -> 500 (Gemini: 1500/day, saatlik ~60 beklenen)

// Retry mekanizması için ayarlar
const MAX_RETRY_ATTEMPTS = 3;
const RETRY_DELAY_MS = 2000; // 2 saniye

// Exponential backoff ile retry helper
async function retryWithBackoff(fn, maxAttempts = MAX_RETRY_ATTEMPTS, baseDelay = RETRY_DELAY_MS) {
  let lastError;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      // 429 (rate limit) veya 503 (service unavailable) hataları için retry yap
      const status = error?.response?.status || error?.status;
      const is429 = status === 429 || (error.message && error.message.includes('429'));
      const is503 = status === 503 || (error.message && error.message.includes('503'));

      if ((is429 || is503) && attempt < maxAttempts) {
        const delay = baseDelay * Math.pow(2, attempt - 1); // Exponential backoff: 2s, 4s, 8s
        logger.warn(`Retry attempt ${attempt}/${maxAttempts} after ${delay}ms`, {
          error: error.message,
          status
        });
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }
      throw error;
    }
  }
  throw lastError;
}

exports.generateGemini = onCall(
  { region: "us-central1", timeoutSeconds: 60, memory: "256MiB", secrets: [GEMINI_API_KEY], enforceAppCheck: true, maxInstances: 20, concurrency: 10 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Oturum gerekli");
    }

    // Premium kontrolü
    const userDoc = await db.collection("users").doc(request.auth.uid).get();
    if (!userDoc.exists || !userDoc.data().isPremium) {
      throw new HttpsError("permission-denied", "Bu özellik yalnızca premium kullanıcılara açıktır.");
    }

    const prompt = request.data?.prompt;
    const expectJson = !!request.data?.expectJson;

    // Sıcaklık aralığını güvenli tut; JSON isteklerinde daha deterministik
    let temperature = 0.7;
    if (typeof request.data?.temperature === "number" && isFinite(request.data.temperature)) {
      temperature = Math.min(1.0, Math.max(0.1, request.data.temperature));
    }
    if (expectJson) {
      // JSON çıktılarda halüsinasyonu azaltmak için üst sınırı düşür
      temperature = Math.min(temperature, 0.3);
    }

    // Model seçimi: Politika gereği tüm çağrılar sabit model kullanır
    const requestedModel = typeof request.data?.model === "string" ? String(request.data.model).trim() : null;
    if (requestedModel && requestedModel.toLowerCase() !== "gemini-2.5-flash-lite") {
      logger.info("Model override enforced", { requestedModel, enforced: "gemini-2.5-flash-lite" });
    }
    const modelId = "gemini-2.5-flash-lite";

    if (typeof prompt !== "string" || !prompt.trim()) {
      throw new HttpsError("invalid-argument", "Geçerli bir prompt gerekli");
    }
    if (prompt.length > GEMINI_PROMPT_MAX_CHARS) {
      throw new HttpsError("invalid-argument", `Prompt çok uzun (>${GEMINI_PROMPT_MAX_CHARS}).`);
    }

    // İçerik moderasyonu - uygunsuz içerik kontrolü
    if (containsInappropriateContent(prompt)) {
      logger.warn("Inappropriate content detected in prompt", {
        uid: request.auth.uid.substring(0, 6) + "***",
        promptLength: prompt.length
      });
      throw new HttpsError(
        "invalid-argument",
        "İsteğiniz uygunsuz içerik barındırıyor. Lütfen eğitim ve motivasyon odaklı sorular sorun."
      );
    }

    const normalizedPrompt = prompt.replace(/\s+/g, " ").trim();

    // Oran sınırlama: kullanıcı ve IP bazlı
    const uidKey = `gemini_uid_${request.auth.uid}`;
    const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
    const ipKey = `gemini_ip_${ip}`;

    // Premium kullanıcılar için ek "Cüzdan DoS" koruması
    const premiumMinuteKey = `gemini_premium_minute_${request.auth.uid}`;
    const premiumHourKey = `gemini_premium_hour_${request.auth.uid}`;

    try {
      await Promise.all([
        enforceRateLimit(uidKey, GEMINI_RATE_LIMIT_WINDOW_SEC, GEMINI_RATE_LIMIT_MAX),
        enforceRateLimit(ipKey, GEMINI_RATE_LIMIT_WINDOW_SEC, GEMINI_RATE_LIMIT_IP_MAX),
        // Premium kullanıcı için dakikalık limit (60 saniye, 10 istek)
        enforceRateLimit(premiumMinuteKey, 60, PREMIUM_RATE_LIMIT_PER_MINUTE),
        // Premium kullanıcı için saatlik limit (3600 saniye, 100 istek)
        enforceRateLimit(premiumHourKey, 3600, PREMIUM_RATE_LIMIT_PER_HOUR),
      ]);
    } catch (rateLimitError) {
      logger.warn("Rate limit exceeded for premium user", {
        uid: request.auth.uid.substring(0, 6) + "***",
        error: String(rateLimitError)
      });
      throw new HttpsError(
        "resource-exhausted",
        "Çok fazla istek gönderdiniz. Lütfen bir süre bekleyip tekrar deneyin. (Dakikada maksimum 10, saatte maksimum 100 istek)"
      );
    }

    // AYLIK "yıldız" kotası (günlük yerine aylık yenilenir - MALİYET OPTİMİZASYONU)
    const currentMonth = new Date().toLocaleString('sv-SE', { timeZone: 'Europe/Istanbul' }).substring(0, 7); // Örn: '2025-10'
    const starRef = db.collection("users").doc(request.auth.uid).collection("stars").doc(currentMonth);
    await db.runTransaction(async (tx) => {
      const starDoc = await tx.get(starRef);
      if (!starDoc.exists) {
        // Belge yoksa, varsayılan 1500 aylık yıldızla oluştur ve bu çağrı için 1 düş
        tx.set(starRef, { balance: 1499, createdAt: new Date() });
        logger.info(`Monthly star quota initialized for user ${request.auth.uid}`, { month: currentMonth, balance: 1499 });
      } else {
        const currentBalance = starDoc.data().balance || 0;
        if (currentBalance <= 0) {
          throw new HttpsError("resource-exhausted", "Aylık AI kullanım limitine ulaştınız.");
        }
        tx.update(starRef, { balance: currentBalance - 1 });
        logger.info(`Star deducted for user ${request.auth.uid}`, { month: currentMonth, newBalance: currentBalance - 1 });
      }
    });

    try {
      // İsteğe bağlı maxOutputTokens (güvenli aralıkta kırpılır)
      const reqMaxTokensRaw = request.data?.maxOutputTokens;
      let effectiveMaxTokens = expectJson ? DEFAULT_JSON_TOKENS : DEFAULT_TEXT_TOKENS;
      if (typeof reqMaxTokensRaw === 'number' && isFinite(reqMaxTokensRaw)) {
        const clamped = Math.max(256, Math.min(reqMaxTokensRaw, 8192));
        effectiveMaxTokens = clamped;
      }

      const body = {
        contents: [{ parts: [{ text: normalizedPrompt }] }],
        generationConfig: {
          temperature,
          maxOutputTokens: effectiveMaxTokens,
          ...(expectJson ? { responseMimeType: "application/json" } : {}),
        },
        // Güvenlik filtreleri: zararlı içerikleri engelle
        safetySettings: [
          { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
        ],
      };

      const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelId}:generateContent?key=${GEMINI_API_KEY.value()}`;

      // Retry mekanizması ile Gemini API çağrısı
      const { resp, data } = await retryWithBackoff(async () => {
        // Zaman aşımı kontrolü (55s):
        const ac = new AbortController();
        const t = setTimeout(() => ac.abort(), 55_000);

        const response = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(body),
          signal: ac.signal,
        }).finally(() => clearTimeout(t));

        // 429 hatası için özel işlem
        if (response.status === 429) {
          const errorBody = await response.text().catch(() => '');
          logger.warn("Gemini API rate limit (429)", {
            modelId,
            uid: request.auth.uid.substring(0, 6) + "***",
            errorBody: errorBody.substring(0, 200)
          });
          const error = new Error("Rate limit exceeded");
          error.status = 429;
          error.response = { status: 429 };
          throw error;
        }

        if (!response.ok) {
          logger.warn("Gemini response not ok", { status: response.status, modelId });
          const error = new Error(`Gemini request failed with status ${response.status}`);
          error.status = response.status;
          error.response = { status: response.status };
          throw error;
        }

        const responseData = await response.json();
        return { resp: response, data: responseData };
      });

      // Güvenlik filtreleme kontrolü
      const finishReason = data?.candidates?.[0]?.finishReason;
      if (finishReason === 'SAFETY') {
        logger.warn("Gemini response blocked by safety filters", {
          uid: request.auth.uid.substring(0, 6) + "***",
          modelId
        });
        throw new HttpsError(
          "failed-precondition",
          "AI yanıtı güvenlik filtreleri tarafından engellendi. Lütfen farklı bir şekilde deneyin."
        );
      }

      const rawCandidate = data?.candidates?.[0]?.content?.parts?.[0]?.text || "";

      // Output sanitizasyonu - hassas bilgileri maskele
      const candidate = sanitizeOutput(rawCandidate);

      // Çıktıda uygunsuz içerik kontrolü (ek güvenlik katmanı)
      if (containsInappropriateContent(candidate)) {
        logger.warn("Inappropriate content detected in AI response", {
          uid: request.auth.uid.substring(0, 6) + "***",
          modelId
        });
        throw new HttpsError(
          "failed-precondition",
          "AI yanıtı uygun olmayan içerik barındırıyor. Lütfen tekrar deneyin."
        );
      }

      const usage = data?.usageMetadata || {};
      // Bazı sürümlerde usageMetadata alanları: promptTokenCount, candidatesTokenCount, totalTokenCount
      const tokensUsed = Number(usage.totalTokenCount || 0);
      logger.info("Gemini call ok", { modelId, tokensUsed, uid: request.auth.uid.substring(0, 6) + "***" });

      // Günlük kullanım logu (maliyet görünürlüğü için) - NON-BLOCKING FIRE-AND-FORGET
      try {
        const day = dayKeyIstanbul();
        const usageRef = db.collection("ai_usage").doc(`${request.auth.uid}_${day}`);
        const modelKey = `models.${modelId}`; // Dinamik alan adı için

        // 'await' kullanma - arka planda çalışsın, fonksiyon hemen yanıt dönsün
        usageRef.set({
          uid: request.auth.uid,
          day,
          createdAt: admin.firestore.FieldValue.serverTimestamp(), // Sadece ilk oluşturmada set eder
          updatedAt: admin.firestore.FieldValue.serverTimestamp(), // Her zaman günceller
          calls: admin.firestore.FieldValue.increment(1),
          tokensUsedTotal: admin.firestore.FieldValue.increment(tokensUsed),
          [`${modelKey}.calls`]: admin.firestore.FieldValue.increment(1),
          [`${modelKey}.tokens`]: admin.firestore.FieldValue.increment(tokensUsed),
        }, { merge: true }).catch((logErr) => {
          // Başarısız olursa ana çağrıyı engelleme, sadece logla
          logger.warn("ai_usage log failed (non-blocking)", { error: String(logErr) });
        });
      } catch (logErr) {
        logger.warn("ai_usage log setup failed", { error: String(logErr) });
      }

      // Geriye dönük uyumlu alanlar: raw, tokensLimit, modelId
      return { raw: candidate, tokensLimit: effectiveMaxTokens, modelId, tokensUsed };
    } catch (e) {
      logger.error("Gemini çağrısı hata", { error: String(e), modelId });
      if (e instanceof HttpsError) throw e;

      // 429 Rate Limit hatası için özel mesaj
      const is429 = (e && typeof e === 'object' && 'status' in e && e.status === 429) ||
                     (e && e.message && e.message.includes('429'));
      if (is429) {
        throw new HttpsError(
          "resource-exhausted",
          "AI sistemi şu anda çok yoğun. Lütfen birkaç saniye bekleyip tekrar deneyin. ⏱️"
        );
      }

      // Abort durumunda kullanıcı dostu mesaj
      if ((e && typeof e === 'object' && 'name' in e && e.name === 'AbortError')) {
        throw new HttpsError("deadline-exceeded", "AI yanıtı çok uzun sürdü, lütfen tekrar deneyin.");
      }

      throw new HttpsError("internal", "AI sistemi geçici olarak ulaşılamıyor. Lütfen tekrar deneyin.");
    }
  },
);
