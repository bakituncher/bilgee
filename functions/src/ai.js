const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { db } = require("./init");
const { defineSecret } = require("firebase-functions/params");
const { enforceRateLimit, getClientIpFromRawRequest, dayKeyIstanbul } = require("./utils");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// Güvenlik ve kötüye kullanım önleme ayarları
const GEMINI_PROMPT_MAX_CHARS = parseInt(process.env.GEMINI_PROMPT_MAX_CHARS || "50000", 10);
const GEMINI_MAX_OUTPUT_TOKENS = parseInt(process.env.GEMINI_MAX_OUTPUT_TOKENS || "50000", 10);
const GEMINI_RATE_LIMIT_WINDOW_SEC = parseInt(process.env.GEMINI_RATE_LIMIT_WINDOW_SEC || "60", 10);
const GEMINI_RATE_LIMIT_MAX = parseInt(process.env.GEMINI_RATE_LIMIT_MAX || "5", 10);
const GEMINI_RATE_LIMIT_IP_MAX = parseInt(process.env.GEMINI_RATE_LIMIT_IP_MAX || "20", 10);

exports.generateGemini = onCall(
  { region: "us-central1", timeoutSeconds: 60, memory: "512MiB", secrets: [GEMINI_API_KEY], enforceAppCheck: true, maxInstances: 20, concurrency: 10 },
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

    // Sıcaklık aralığını güvenli tut
    let temperature = 0.8;
    if (typeof request.data?.temperature === "number" && isFinite(request.data.temperature)) {
      temperature = Math.min(1.0, Math.max(0.1, request.data.temperature));
    }

    // Model seçimi (whitelist)
    let modelId = "gemini-2.0-flash-lite-001";
    const reqModel = typeof request.data?.model === "string" ? String(request.data.model).toLowerCase().trim() : "";
    if (reqModel) {
      if (reqModel.includes("pro")) {
        modelId = "gemini-2.0-flash-001";
      } else if (reqModel.includes("flash")) {
        modelId = "gemini-2.0-flash-lite-001";
      } else if (/^gemini-2\.0-flash(?:-lite)?-001$/.test(reqModel)) {
        modelId = reqModel;
      }
    }

    if (typeof prompt !== "string" || !prompt.trim()) {
      throw new HttpsError("invalid-argument", "Geçerli bir prompt gerekli");
    }
    if (prompt.length > GEMINI_PROMPT_MAX_CHARS) {
      throw new HttpsError("invalid-argument", `Prompt çok uzun (>${GEMINI_PROMPT_MAX_CHARS}).`);
    }

    const normalizedPrompt = prompt.replace(/\s+/g, " ").trim();

    // Oran sınırlama: kullanıcı ve IP bazlı
    const uidKey = `gemini_uid_${request.auth.uid}`;
    const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
    const ipKey = `gemini_ip_${ip}`;
    await Promise.all([
      enforceRateLimit(uidKey, GEMINI_RATE_LIMIT_WINDOW_SEC, GEMINI_RATE_LIMIT_MAX),
      enforceRateLimit(ipKey, GEMINI_RATE_LIMIT_WINDOW_SEC, GEMINI_RATE_LIMIT_IP_MAX),
    ]);

    // Günlük "yıldız" kotası
    const today = dayKeyIstanbul();
    const starRef = db.collection("users").doc(request.auth.uid).collection("stars").doc(today);
    await db.runTransaction(async (tx) => {
      const starDoc = await tx.get(starRef);
      if (!starDoc.exists) {
        // Belge yoksa, varsayılan 100 yıldızla oluştur
        tx.set(starRef, { balance: 99 }); // 100 - 1
        logger.info(`Star quota initialized for user ${request.auth.uid}`, { day: today, balance: 99 });
      } else {
        const currentBalance = starDoc.data().balance || 0;
        if (currentBalance <= 0) {
          throw new HttpsError("resource-exhausted", "Günlük AI kullanım limitine ulaştınız.");
        }
        tx.update(starRef, { balance: currentBalance - 1 });
        logger.info(`Star deducted for user ${request.auth.uid}`, { day: today, newBalance: currentBalance - 1 });
      }
    });

    try {
      const body = {
        contents: [{ parts: [{ text: normalizedPrompt }] }],
        generationConfig: {
          temperature,
          maxOutputTokens: GEMINI_MAX_OUTPUT_TOKENS,
          ...(expectJson ? { responseMimeType: "application/json" } : {}),
        },
      };
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelId}:generateContent?key=${GEMINI_API_KEY.value()}`;
      const resp = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

      if (!resp.ok) {
        logger.warn("Gemini response not ok", { status: resp.status, modelId });
        throw new HttpsError("internal", `Gemini isteği başarısız (${resp.status}).`);
      }
      const data = await resp.json();
      const candidate = data?.candidates?.[0]?.content?.parts?.[0]?.text || "";
      return { raw: candidate, tokensLimit: GEMINI_MAX_OUTPUT_TOKENS, modelId };
    } catch (e) {
      logger.error("Gemini çağrısı hata", { error: String(e), modelId });
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", "Gemini isteği sırasında hata oluştu");
    }
  },
);
