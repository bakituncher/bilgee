const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { db } = require("./init");
const { defineSecret } = require("firebase-functions/params");
const { enforceRateLimit, getClientIpFromRawRequest, dayKeyIstanbul } = require("./utils");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// Güvenlik ve kötüye kullanım önleme ayarları
// Varsayılanlar maliyeti düşürecek şekilde daraltıldı; env ile aşılabilir.
const GEMINI_PROMPT_MAX_CHARS = parseInt(process.env.GEMINI_PROMPT_MAX_CHARS || "30000", 10);
const DEFAULT_JSON_TOKENS = parseInt(process.env.GEMINI_MAX_OUTPUT_TOKENS_JSON || "6144", 10);
const DEFAULT_TEXT_TOKENS = parseInt(process.env.GEMINI_MAX_OUTPUT_TOKENS_TEXT || "1024", 10);
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
    if (requestedModel && requestedModel.toLowerCase() !== "gemini-2.0-flash-lite-001") {
      logger.info("Model override enforced", { requestedModel, enforced: "gemini-2.0-flash-lite-001" });
    }
    const modelId = "gemini-2.0-flash-lite-001";

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

    // Günlük "yıldız" kotası (ilk çağrıda düşülür)
    const today = dayKeyIstanbul();
    const starRef = db.collection("users").doc(request.auth.uid).collection("stars").doc(today);
    await db.runTransaction(async (tx) => {
      const starDoc = await tx.get(starRef);
      if (!starDoc.exists) {
        // Belge yoksa, varsayılan 100 yıldızla oluştur ve bu çağrı için 1 düş
        tx.set(starRef, { balance: 99 });
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

      // Zaman aşımı kontrolü (55s):
      const ac = new AbortController();
      const t = setTimeout(() => ac.abort(), 55_000);

      const resp = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: ac.signal,
      }).finally(() => clearTimeout(t));

      if (!resp.ok) {
        logger.warn("Gemini response not ok", { status: resp.status, modelId });
        throw new HttpsError("internal", `Gemini isteği başarısız (${resp.status}).`);
      }
      const data = await resp.json();
      const candidate = data?.candidates?.[0]?.content?.parts?.[0]?.text || "";
      const usage = data?.usageMetadata || {};
      // Bazı sürümlerde usageMetadata alanları: promptTokenCount, candidatesTokenCount, totalTokenCount
      const tokensUsed = Number(usage.totalTokenCount || 0);
      logger.info("Gemini call ok", { modelId, tokensUsed, uid: request.auth.uid.substring(0, 6) + "***" });

      // Günlük kullanım logu (maliyet görünürlüğü için). Başarısız olursa çağrıyı etkilemez.
      try {
        const day = dayKeyIstanbul();
        const usageRef = db.collection("ai_usage").doc(`${request.auth.uid}_${day}`);
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(usageRef);
          if (!snap.exists) {
            tx.set(usageRef, {
              uid: request.auth.uid,
              day,
              calls: 1,
              tokensUsedTotal: tokensUsed,
              models: { [modelId]: { calls: 1, tokens: tokensUsed } },
              createdAt: new Date(),
              updatedAt: new Date(),
            });
          } else {
            const d = snap.data() || {};
            const calls = Number(d.calls || 0) + 1;
            const tokensTotal = Number(d.tokensUsedTotal || 0) + tokensUsed;
            const models = d.models || {};
            const m = models[modelId] || { calls: 0, tokens: 0 };
            models[modelId] = { calls: Number(m.calls || 0) + 1, tokens: Number(m.tokens || 0) + tokensUsed };
            tx.update(usageRef, { calls, tokensUsedTotal: tokensTotal, models, updatedAt: new Date() });
          }
        });
      } catch (logErr) {
        logger.warn("ai_usage log failed", { error: String(logErr) });
      }

      // Geriye dönük uyumlu alanlar: raw, tokensLimit, modelId
      return { raw: candidate, tokensLimit: effectiveMaxTokens, modelId, tokensUsed };
    } catch (e) {
      logger.error("Gemini çağrısı hata", { error: String(e), modelId });
      if (e instanceof HttpsError) throw e;
      // Abort durumunda kullanıcı dostu mesaj
      if ((e && typeof e === 'object' && 'name' in e && e.name === 'AbortError')) {
        throw new HttpsError("deadline-exceeded", "Gemini isteği zaman aşımına uğradı");
      }
      throw new HttpsError("internal", "Gemini isteği sırasında hata oluştu");
    }
  },
);
