// Gerekli Firebase v2 kütüphanelerini içe aktarıyoruz.
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, HttpsError, onRequest} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const {onDocumentDeleted} = require("firebase-functions/v2/firestore");

// Firebase projesini başlatıyoruz.
admin.initializeApp();
const db = admin.firestore();

async function deletePostAssetsBySlug(slug) {
  if (!slug) return;
  try {
    const bucket = admin.storage().bucket();
    const prefix = `blog_covers/${slug}/`;
    await bucket.deleteFiles({prefix});
    logger.info(`Storage temizlendi: ${prefix}`);
  } catch (e) {
    logger.warn("Storage dosyaları temizlenemedi", {slug, error: String(e)});
  }
}

// quests.json dosyasını okuyup bir değişkende tutuyoruz.
const QUEST_TEMPLATES = (() => {
  try {
    const p = path.join(__dirname, "quests.json");
    const raw = fs.readFileSync(p, "utf8");
    return JSON.parse(raw);
  } catch (error) {
    logger.error("quests.json dosyası okunamadı!", error);
    return []; // Hata durumunda boş bir dizi döndür
  }
})();


/**
 * Kullanıcı verisine göre basit bir görev seçimi yapar.
 * @param {object} userData Kullanıcının Firestore'daki verisi.
 * @return {Array<object>} Seçilen yeni görevler.
 */
function pickDailyQuestsForUser(userData) {
  const shuffled = [...QUEST_TEMPLATES].sort(() => Math.random() - 0.5);
  const selected = [];
  const usedCategories = new Set();
  for (const q of shuffled) {
    if (selected.length >= 5) break;
    if (usedCategories.has(q.category) && Math.random() < 0.5) continue;
    selected.push(q);
    usedCategories.add(q.category);
  }
  const now = admin.firestore.Timestamp.now();
  return selected.map((q) => ({
    qid: q.id,
    title: q.title,
    description: q.description,
    type: "daily",
    category: q.category,
    progressType: q.progressType || "increment",
    reward: q.reward,
    goalValue: q.goalValue,
    currentProgress: 0,
    isCompleted: false,
    actionRoute: q.actionRoute,
    routeKey: "home", // Bu alanlar modelinize göre ayarlanmalı
    tags: [],
    rewardClaimed: false,
    createdAt: now,
    schemaVersion: 2,
  }));
}

/**
 * Tüm kullanıcılar için günlük görevleri oluşturan yardımcı fonksiyon.
 */
async function generateDailyQuestsForAllUsers() {
  const usersSnap = await db.collection("users").get();
  const batchPromises = [];
  let batch = db.batch();
  let opCount = 0;

  for (const doc of usersSnap.docs) {
    const userRef = doc.ref;
    const questsRef = userRef.collection("daily_quests");
    const quests = pickDailyQuestsForUser(doc.data());

    const existing = await questsRef.get();
    existing.docs.forEach((d) => {
      batch.delete(d.ref);
      opCount++;
    });

    quests.forEach((q) => {
      batch.set(questsRef.doc(q.qid), q, {merge: true});
      opCount++;
    });

    batch.update(userRef, {
      lastQuestRefreshDate: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (opCount > 400) {
      batchPromises.push(batch.commit());
      batch = db.batch();
      opCount = 0;
    }
  }

  if (opCount > 0) {
    batchPromises.push(batch.commit());
  }

  await Promise.all(batchPromises);
}

// Her gün gece yarısı tüm kullanıcılar için görevleri yenileyen zamanlanmış fonksiyon.
exports.generateDailyQuests = onSchedule(
    {schedule: "0 0 * * *", timeZone: "Europe/Istanbul"},
    async (event) => {
      await generateDailyQuestsForAllUsers();
      logger.info("Günlük görevler tüm kullanıcılar için üretildi.");
    },
);

// Tek bir kullanıcı için görevleri yeniden oluşturan, istemciden çağrılabilir fonksiyon. (BEKLEME SÜRESİ KALDIRILDI)
exports.regenerateDailyQuests = onCall(
  {region: 'us-central1'},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Oturum gerekli');
    }
    const uid = request.auth.uid;
    const userRef = db.collection('users').doc(uid);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      throw new HttpsError('not-found', 'Kullanıcı yok');
    }

    const quests = pickDailyQuestsForUser(userSnap.data());
    const questsRef = userRef.collection('daily_quests');
    const existing = await questsRef.get();
    const batch = db.batch();

    existing.docs.forEach((d) => batch.delete(d.ref));
    quests.forEach((q) => batch.set(questsRef.doc(q.qid), q, {merge: true}));

    batch.update(userRef, {
      lastQuestRefreshDate: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return {quests};
  },
);

// Bir görevi tamamlandı olarak işaretleyen fonksiyon.
exports.completeQuest = onCall({region: "us-central1"}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Oturum gerekli");
  }
  const questId = request.data?.questId;
  if (!questId) {
    throw new HttpsError("invalid-argument", "questId gerekli");
  }
  const uid = request.auth.uid;
  const questRef = db.collection("users").doc(uid).collection("daily_quests").doc(questId);
  const snap = await questRef.get();

  if (!snap.exists) throw new HttpsError("not-found", "Görev bulunamadı");

  const qData = snap.data();
  if (qData.isCompleted) return {alreadyCompleted: true};

  await questRef.update({
    isCompleted: true,
    currentProgress: qData.goalValue,
    completionDate: admin.firestore.Timestamp.now(),
  });
  return {success: true};
});

// Gemini API'sine güvenli bir şekilde istek atan proxy fonksiyonu.
const GEMINI_KEY = process.env.GEMINI_API_KEY;

// Güvenlik ve kötüye kullanım önleme ayarları
const GEMINI_PROMPT_MAX_CHARS = parseInt(process.env.GEMINI_PROMPT_MAX_CHARS || '5000', 10);
const GEMINI_MAX_OUTPUT_TOKENS = parseInt(process.env.GEMINI_MAX_OUTPUT_TOKENS || '3000', 10);
const GEMINI_RATE_LIMIT_WINDOW_SEC = parseInt(process.env.GEMINI_RATE_LIMIT_WINDOW_SEC || '60', 10);
const GEMINI_RATE_LIMIT_MAX = parseInt(process.env.GEMINI_RATE_LIMIT_MAX || '5', 10);

async function enforceRateLimit(key, windowSeconds, maxCount) {
  const ref = db.collection('rate_limits').doc(key);
  const now = Date.now();
  const windowMs = windowSeconds * 1000;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      tx.set(ref, {count: 1, windowStart: now});
      return;
    }
    const data = snap.data();
    let {count, windowStart} = data;
    if (typeof windowStart !== 'number') windowStart = now;
    if (now - windowStart > windowMs) {
      tx.set(ref, {count: 1, windowStart: now});
      return;
    }
    if (count >= maxCount) {
      throw new HttpsError('resource-exhausted', 'Oran sınırı aşıldı. Lütfen sonra tekrar deneyin.');
    }
    tx.update(ref, {count: count + 1});
  });
}

exports.generateGemini = onCall(
  {region: 'us-central1', timeoutSeconds: 60, memory: '512MiB'},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Oturum gerekli');
    }
    if (!GEMINI_KEY) {
      throw new HttpsError('failed-precondition', 'Sunucu Gemini anahtarı tanımlı değil.');
    }
    const prompt = request.data?.prompt;
    const expectJson = !!request.data?.expectJson;

    if (typeof prompt !== 'string' || !prompt.trim()) {
      throw new HttpsError('invalid-argument', 'Geçerli bir prompt gerekli');
    }
    if (prompt.length > GEMINI_PROMPT_MAX_CHARS) {
      throw new HttpsError('invalid-argument', `Prompt çok uzun (>${GEMINI_PROMPT_MAX_CHARS}).`);
    }

    const normalizedPrompt = prompt.replace(/\s+/g, ' ').trim();

    await enforceRateLimit(`gemini_${request.auth.uid}`, GEMINI_RATE_LIMIT_WINDOW_SEC, GEMINI_RATE_LIMIT_MAX);

    try {
      const body = {
        contents: [{parts: [{text: normalizedPrompt}]}],
        generationConfig: {
          temperature: 0.8,
          maxOutputTokens: GEMINI_MAX_OUTPUT_TOKENS,
          ...(expectJson ? {responseMimeType: 'application/json'} : {}),
        },
      };
      const url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=' + GEMINI_KEY;
      const resp = await fetch(url, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(body),
      });

      if (!resp.ok) {
        logger.warn('Gemini response not ok', {status: resp.status});
        throw new HttpsError('internal', `Gemini isteği başarısız (${resp.status}).`);
      }
      const data = await resp.json();
      const candidate = data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
      return {raw: candidate, tokensLimit: GEMINI_MAX_OUTPUT_TOKENS};
    } catch (e) {
      logger.error('Gemini çağrısı hata', e);
      if (e instanceof HttpsError) throw e;
      throw new HttpsError('internal', 'Gemini isteği sırasında hata oluştu');
    }
  },
);

// Basit test fonksiyonu
exports.helloWorld = onRequest((request, response) => {
  logger.info("Hello logs!", {structuredData: true});
  response.send("Hello from BilgeAI!");
});

// ---- ADMIN CLAIM YÖNETİMİ ----
const DEFAULT_SUPER_ADMINS = ['baki@gmail.com'];
const SUPER_ADMINS = (process.env.SUPER_ADMINS || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);

async function getSuperAdmins() {
  try {
    const snap = await db.collection('config').doc('super_admins').get();
    const data = snap.exists ? (snap.data() || {}) : {};
    const emails = Array.isArray(data.emails) ? data.emails : [];
    const list = [
      ...DEFAULT_SUPER_ADMINS,
      ...SUPER_ADMINS,
      ...emails.map((e) => String(e).trim().toLowerCase()),
    ];
    // benzersizleştir
    return Array.from(new Set(list.filter(Boolean)));
  } catch (_) {
    // fallback sadece default + env
    return Array.from(new Set([...DEFAULT_SUPER_ADMINS, ...SUPER_ADMINS]));
  }
}

async function isSuperAdmin(uid) {
  try {
    const user = await admin.auth().getUser(uid);
    const email = (user.email || '').toLowerCase();
    if (!email) return false;
    const allow = await getSuperAdmins();
    return allow.includes(email);
  } catch (_) {
    return false;
  }
}

exports.setAdminClaim = onCall({region: 'us-central1'}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
  const allowed = await isSuperAdmin(request.auth.uid);
  if (!allowed) throw new HttpsError('permission-denied', 'Yetki yok');

  const uid = request.data?.uid;
  const makeAdmin = !!request.data?.makeAdmin;
  if (typeof uid !== 'string' || uid.length < 6) {
    throw new HttpsError('invalid-argument', 'Geçerli uid gerekli');
  }
  const target = await admin.auth().getUser(uid);
  const existing = target.customClaims || {};
  const newClaims = {...existing, admin: makeAdmin};
  await admin.auth().setCustomUserClaims(uid, newClaims);
  return {ok: true, uid, admin: makeAdmin};
});

exports.setSelfAdmin = onCall({region: 'us-central1'}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
  const allowed = await isSuperAdmin(request.auth.uid);
  if (!allowed) throw new HttpsError('permission-denied', 'Yetki yok');
  const uid = request.auth.uid;
  const me = await admin.auth().getUser(uid);
  const existing = me.customClaims || {};
  await admin.auth().setCustomUserClaims(uid, {...existing, admin: true});
  return {ok: true, uid, admin: true};
});

// Süresi dolan yazıları periyodik olarak temizle
exports.cleanupExpiredPosts = onSchedule(
  {schedule: "0 * * * *", timeZone: "Europe/Istanbul"},
  async () => {
    const nowTs = admin.firestore.Timestamp.now();
    let totalDeleted = 0;
    for (let i = 0; i < 10; i++) { // güvenli döngü, her seferinde en fazla ~1000 kayıt
      const snap = await db
        .collection('posts')
        .where('expireAt', '<=', nowTs)
        .limit(100)
        .get();
      if (snap.empty) break;

      const batch = db.batch();
      const jobs = [];
      snap.docs.forEach((doc) => {
        const data = doc.data() || {};
        const slug = data.slug || doc.id;
        // Yalnızca gerçekten yayında olup süresi dolmuşları sil
        const status = (data.status || 'draft');
        if (status === 'published') {
          batch.delete(doc.ref);
          jobs.push(deletePostAssetsBySlug(slug));
          totalDeleted++;
        }
      });
      await Promise.all([batch.commit(), Promise.all(jobs)]);
      if (snap.size < 100) break; // bitti
    }
    logger.info(`cleanupExpiredPosts tamamlandı. Silinen yazı: ${totalDeleted}`);
  }
);

// Bir yazı silindiğinde kapak görsellerini de temizle
exports.onPostDeletedCleanup = onDocumentDeleted("posts/{postId}", async (event) => {
  const snap = event.data; // DocumentSnapshot
  const slug = (snap && snap.data()?.slug) || event.params.postId;
  await deletePostAssetsBySlug(slug);
});
