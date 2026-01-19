const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { admin, db } = require("./init");
const { defineSecret } = require("firebase-functions/params");
const { enforceRateLimit, getClientIpFromRawRequest, dayKeyIstanbul } = require("./utils");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

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
const GEMINI_PROMPT_MAX_CHARS = parseInt(process.env.GEMINI_PROMPT_MAX_CHARS || "120000", 10);
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

// YENİ: Kategori bazlı aylık limitler
const MONTHLY_LIMITS = {
  workshop: 350,    // Etüt Odası
  weekly_plan: 60,  // Haftalık Plan
  chat: 2000,        // Sohbet / Motivasyon
  question_solver: 1000 // Soru Çözücü
};

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
  { region: "us-central1", timeoutSeconds: 300, memory: "256MiB", secrets: [GEMINI_API_KEY], enforceAppCheck: true, maxInstances: 20, concurrency: 10 },
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

    // YENİ: İstemciden gelen işlem türünü al, varsayılan 'chat'
    const requestType = request.data?.requestType || 'chat';

    // YENİ: Soru çözücü görseli (base64, data uri değil)
    const imageBase64 = typeof request.data?.imageBase64 === 'string' ? request.data.imageBase64.trim() : null;
    const imageMimeType = typeof request.data?.imageMimeType === 'string' ? request.data.imageMimeType.trim() : 'image/jpeg';

    // Geçersiz tür kontrolü
    if (!Object.keys(MONTHLY_LIMITS).includes(requestType)) {
      throw new HttpsError("invalid-argument", "Geçersiz işlem türü.");
    }

    // Sıcaklık aralığını güvenli tut; JSON isteklerinde daha deterministik
    let temperature = 0.5;
    if (typeof request.data?.temperature === "number" && isFinite(request.data.temperature)) {
      temperature = Math.min(1.0, Math.max(0.1, request.data.temperature));
    }
    if (expectJson) {
      // JSON çıktılarda halüsinasyonu azaltmak için üst sınırı düşür
      temperature = Math.min(temperature, 0.3);
    }

    // MODEL SEÇİMİ GÜNCELLEMESİ
    // Soru çözücü ve Etüt Odası: gemini-3-flash-preview (en son güçlü model)
    // Diğer tüm chat/planlama işleri: gemini-2.5-flash (Lite yerine tam sürüm)
    const requestedModel = typeof request.data?.model === "string" ? String(request.data.model).trim() : null;

    // BURASI GÜNCELLENDİ: workshop için de güçlü model kullanılıyor
    const modelId = (requestType === 'question_solver' || requestType === 'workshop')
      ? "gemini-3-flash-preview"
      : "gemini-2.5-flash";

    if (requestedModel && requestedModel.toLowerCase() !== modelId) {
      logger.info("Model override enforced", { requestedModel, enforced: modelId, requestType });
    }

    if (typeof prompt !== "string" || !prompt.trim()) {
      throw new HttpsError("invalid-argument", "Geçerli bir prompt gerekli");
    }

    // Soru çözücüde görsel bekleniyorsa doğrula
    if (requestType === 'question_solver') {
      if (!imageBase64) {
        throw new HttpsError("invalid-argument", "Soru çözücü için görsel gerekli.");
      }
      // Çok kaba boyut koruması: base64 ~ 4/3 => 6MB base64 ~ 4.5MB binary
      // (Callable + bellek için güvenli tarafta tutuyoruz)
      const maxBase64Chars = parseInt(process.env.QUESTION_SOLVER_IMAGE_MAX_BASE64_CHARS || "6000000", 10);
      if (imageBase64.length > maxBase64Chars) {
        throw new HttpsError("invalid-argument", "Görsel çok büyük. Lütfen daha net ama daha yakın/az kırpılmış bir fotoğraf deneyin.");
      }
    }

    if (prompt.length > GEMINI_PROMPT_MAX_CHARS) {
      logger.warn("Prompt length exceeded", { length: prompt.length, limit: GEMINI_PROMPT_MAX_CHARS, uid: request.auth.uid, requestType });
      throw new HttpsError("invalid-argument", `Prompt çok uzun (${prompt.length} > ${GEMINI_PROMPT_MAX_CHARS}).`);
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

    // --- YENİ AYLIK KOTA SİSTEMİ ---
    const currentMonth = new Date().toLocaleString('sv-SE', { timeZone: 'Europe/Istanbul' }).substring(0, 7); // 'YYYY-MM'
    const usageRef = db.collection("users").doc(request.auth.uid).collection("monthly_usage").doc(currentMonth);

    await db.runTransaction(async (tx) => {
      const usageDoc = await tx.get(usageRef);
      const usageData = usageDoc.exists ? usageDoc.data() : {};

      const currentUsage = usageData[requestType] || 0;
      const limit = MONTHLY_LIMITS[requestType];

      if (currentUsage >= limit) {
        let featureName = "";
        switch(requestType) {
          case 'workshop': featureName = "Etüt Odası"; break;
          case 'weekly_plan': featureName = "Haftalık Plan"; break;
          case 'question_solver': featureName = "Soru Çözücü"; break;
          default: featureName = "Sohbet"; break;
        }
        throw new HttpsError("resource-exhausted", `Bu ayki ${featureName} limitinize (${limit}) ulaştınız. Limitler her ayın başında yenilenir.`);
      }

      // Kullanımı artır
      tx.set(usageRef, {
        [requestType]: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    });
    // ----------------------------------

    try {
      // İsteğe bağlı maxOutputTokens (güvenli aralıkta kırpılır)
      const reqMaxTokensRaw = request.data?.maxOutputTokens;
      let effectiveMaxTokens = expectJson ? DEFAULT_JSON_TOKENS : DEFAULT_TEXT_TOKENS;

      // ÖZEL TOKEN LİMİTLERİ (Yanıt kesilme sorunlarının çözümü)
      if (requestType === 'weekly_plan') {
        effectiveMaxTokens = 50000; // Haftalık planlar için yüksek limit
      } else if (requestType === 'workshop') {
        effectiveMaxTokens = 10000; // 30k çok fazla, latency yaratıyor. 10k fazlasıyla yeterli.
      }

      if (typeof reqMaxTokensRaw === 'number' && isFinite(reqMaxTokensRaw)) {
        const clamped = Math.max(256, Math.min(reqMaxTokensRaw, 65536));
        effectiveMaxTokens = clamped;
      }

      const body = {
        contents: [
          {
            parts: [
              { text: normalizedPrompt },
              ...(requestType === 'question_solver' && imageBase64
                ? [{ inlineData: { mimeType: imageMimeType || 'image/jpeg', data: imageBase64 } }]
                : []),
            ],
          },
        ],
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
        // Zaman aşımı kontrolü (280s):
        const ac = new AbortController();
        const t = setTimeout(() => ac.abort(), 280_000);

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

      const usage = data?.usageMetadata || {};
      // Bazı sürümlerde usageMetadata alanları: promptTokenCount, candidatesTokenCount, totalTokenCount
      const tokensUsed = Number(usage.totalTokenCount || 0);
      logger.info("Gemini call ok", { modelId, tokensUsed, uid: request.auth.uid.substring(0, 6) + "***", requestType });

      // İstatistik loglama (Maliyet takibi için)
      try {
        const day = dayKeyIstanbul();
        const usageStatsRef = db.collection("ai_usage").doc(`${request.auth.uid}_${day}`);
        const modelKey = `models.${modelId}`;
        const typeKey = `types.${requestType}`;

        usageStatsRef.set({
          uid: request.auth.uid,
          day,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          calls: admin.firestore.FieldValue.increment(1),
          tokensUsedTotal: admin.firestore.FieldValue.increment(tokensUsed),
          [`${modelKey}.calls`]: admin.firestore.FieldValue.increment(1),
          [`${typeKey}.calls`]: admin.firestore.FieldValue.increment(1),
        }, { merge: true }).catch(() => {});
      } catch (e) {}

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