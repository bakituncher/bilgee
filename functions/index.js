// Gerekli Firebase v2 kütüphanelerini içe aktarıyoruz.
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, HttpsError, onRequest} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const {onDocumentDeleted, onDocumentCreated} = require("firebase-functions/v2/firestore");

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

function routeKeyFromPath(pathname) {
  switch (pathname) {
    case '/home': return 'home';
    case '/home/pomodoro': return 'pomodoro';
    case '/coach': return 'coach';
    case '/home/weekly-plan': return 'weeklyPlan';
    case '/home/stats': return 'stats';
    case '/home/add-test': return 'addTest';
    case '/home/quests': return 'quests';
    case '/ai-hub/strategic-planning': return 'strategy';
    case '/ai-hub/weakness-workshop': return 'workshop';
    case '/availability': return 'availability';
    case '/profile/avatar-selection': return 'avatar';
    case '/arena': return 'arena';
    case '/library': return 'library';
    case '/ai-hub/motivation-chat': return 'motivationChat';
    default: return 'home';
  }
}

function personalizeTemplate(q, userData, analysis) {
  let title = q.title || 'Görev';
  let description = q.description || '';
  const tags = Array.isArray(q.tags) ? [...q.tags] : [];

  let subject = null;
  const weakest = analysis?.weakestSubjectByNet;
  const strongest = analysis?.strongestSubjectByNet;

  const needsSubject = (typeof title === 'string' && title.includes('{subject}'))
                    || (typeof description === 'string' && description.includes('{subject}'))
                    || tags.some((t) => String(t).startsWith('subject:'));

  if (needsSubject) {
    if (tags.includes('weakness') && weakest && weakest !== 'Belirlenemedi') subject = weakest;
    else if (tags.includes('strength') && strongest && strongest !== 'Belirlenemedi') subject = strongest;
    else subject = userData?.selectedExamSection || 'Seçili Ders';

    title = title.replaceAll('{subject}', subject);
    description = description.replaceAll('{subject}', subject);
    if (!tags.some((t) => String(t).startsWith('subject:'))) tags.push(`subject:${subject}`);
  }

  return { title, description, tags };
}

/**
 * Kullanıcı verisine göre basit bir görev seçimi yapar (kişiselleştirme dahil).
 * @param {object} userData Kullanıcının Firestore'daki kök verisi.
 * @param {object|null} analysis Kullanıcının performans/analiz özeti (opsiyonel).
 * @return {Array<object>} Seçilen yeni görevler.
 */
function pickDailyQuestsForUser(userData, analysis) {
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
  return selected.map((q) => {
    const { title, description, tags } = personalizeTemplate(q, userData, analysis);
    const actionRoute = q.actionRoute || '/home';
    const routeKey = routeKeyFromPath(actionRoute);
    return {
      qid: q.id,
      title,
      description,
      type: q.type || 'daily',
      category: q.category,
      progressType: q.progressType || 'increment',
      reward: q.reward,
      goalValue: q.goalValue,
      currentProgress: 0,
      isCompleted: false,
      actionRoute,
      routeKey,
      tags,
      rewardClaimed: false,
      createdAt: now,
      schemaVersion: 2,
    };
  });
}

function nowIstanbul() {
  const now = new Date();
  try {
    return new Date(now.toLocaleString('en-US', {timeZone: 'Europe/Istanbul'}));
  } catch(_) {
    return now; // fallback
  }
}

async function getUserContext(userRef) {
  const ctx = { analysis: null, stats: null, app: null, user: null, yesterdayInactive: false, examType: null, usedFeatures: {}, notUsedFeatures: {} };
  const userSnap = await userRef.get();
  ctx.user = userSnap.exists ? userSnap.data() : {};
  ctx.examType = ctx.user?.selectedExam || null;
  try {
    const a = await userRef.collection('performance').doc('analysis_summary').get();
    ctx.analysis = a.exists ? a.data() : null;
  } catch(_) {}
  try {
    const s = await userRef.collection('state').doc('stats').get();
    ctx.stats = s.exists ? s.data() : null;
  } catch(_) {}
  try {
    const app = await userRef.collection('state').doc('app_state').get();
    ctx.app = app.exists ? app.data() : null;
  } catch(_) {}
  // Dün aktif miydi? user_activity günlükleri üzerinden bak
  try {
    const d = nowIstanbul();
    const y = new Date(d.getFullYear(), d.getMonth(), d.getDate() - 1);
    const id = `${y.getFullYear().toString().padStart(4,'0')}-${(y.getMonth()+1).toString().padStart(2,'0')}-${y.getDate().toString().padStart(2,'0')}`;
    const act = await userRef.collection('user_activity').doc(id).get();
    const data = act.data() || {};
    const visits = Array.isArray(data.visits) ? data.visits : [];
    ctx.yesterdayInactive = visits.length === 0;
  } catch(_) {}
  return ctx;
}

function timeOfDayLabel(d) {
  const h = d.getHours();
  if (h < 12) return 'morning';
  if (h < 18) return 'afternoon';
  return 'night';
}

function evaluateTriggerConditions(template, ctx) {
  const cond = template.triggerConditions || {};
  if (!cond || Object.keys(cond).length === 0) return true;
  const now = nowIstanbul();
  // Zaman dilimi
  if (cond.timeOfDay) {
    const wanted = Array.isArray(cond.timeOfDay) ? cond.timeOfDay : [cond.timeOfDay];
    if (!wanted.includes(timeOfDayLabel(now))) return false;
  }
  // Günler
  if (cond.dayOfWeek) {
    const map = ['sunday','monday','tuesday','wednesday','thursday','friday','saturday'];
    const today = map[now.getDay()];
    const wanted = Array.isArray(cond.dayOfWeek) ? cond.dayOfWeek : [cond.dayOfWeek];
    if (!wanted.includes(today)) return false;
  }
  // Dün pasif miydi?
  if (cond.wasInactiveYesterday === true && ctx.yesterdayInactive !== true) return false;
  // Zayıf/güçlü ders
  if (cond.hasWeakSubject === true) {
    const w = ctx.analysis?.weakestSubjectByNet;
    if (!w || w === 'Belirlenemedi') return false;
  }
  if (cond.hasStrongSubject === true) {
    const s = ctx.analysis?.strongestSubjectByNet;
    if (!s || s === 'Belirlenemedi') return false;
  }
  // Galaksi zayıf konu vb. (elde veri yoksa pasifle)
  if (cond.hasWeakTopicInGalaxy === true) {
    // Performans özeti yoksa tetikleme
    if (!ctx.analysis) return false;
  }
  if (cond.hasStaleSubject === true) {
    if (!ctx.analysis) return false;
  }
  // Sınav tipi
  if (cond.examType) {
    const wanted = Array.isArray(cond.examType) ? cond.examType : [cond.examType];
    if (!ctx.examType || !wanted.includes(ctx.examType)) return false;
  }
  // Özellik kullanımına göre (basit sezgisel)
  if (cond.notUsedFeature) {
    // app_state üzerindeki bayraklardan basit okuma; bilinmiyorsa eliyoruz
    const f = String(cond.notUsedFeature);
    const used = ctx.app?.[`feature_${f}_used`];
    if (used === true) return false;
  }
  if (cond.usedFeatureRecently) {
    const f = String(cond.usedFeatureRecently);
    const used = ctx.app?.[`feature_${f}_used`];
    if (used !== true) return false;
  }
  if (cond.lowYesterdayPlanRatio === true) {
    const r = ctx.user?.lastScheduleCompletionRatio;
    if (!(typeof r === 'number' && r < 0.5)) return false;
  }
  if (cond.highYesterdayPlanRatio === true) {
    const r = ctx.user?.lastScheduleCompletionRatio;
    if (!(typeof r === 'number' && r >= 0.85)) return false;
  }
  return true;
}

function scoreTemplateForUser(t, ctx) {
  let score = (t.reward || 0);
  const tags = t.tags || [];
  if (tags.includes('high_value')) score += 40;
  if (tags.includes('weakness') && ctx.analysis?.weakestSubjectByNet && ctx.analysis.weakestSubjectByNet !== 'Belirlenemedi') score += 25;
  if (tags.includes('strength') && ctx.analysis?.strongestSubjectByNet && ctx.analysis.strongestSubjectByNet !== 'Belirlenemedi') score += 15;
  if (tags.includes('quick_win')) score += 5;
  if (t.category === 'focus' && ctx.stats?.streak && ctx.stats.streak < 3) score += 8;
  if (t.category === 'practice' && (ctx.user?.recentPracticeVolumes ? Object.keys(ctx.user.recentPracticeVolumes).length < 3 : true)) score += 6;
  return score;
}

function pickTemplatesForType(type, ctx, desiredCount) {
  const pool = QUEST_TEMPLATES.filter((q) => (q.type || 'daily') === type).filter((q) => evaluateTriggerConditions(q, ctx));
  // Skorla ve çeşitlendir
  const scored = pool.map((q) => ({q, s: scoreTemplateForUser(q, ctx)})).sort((a,b)=> b.s - a.s);
  const selected = [];
  const usedCategories = new Set();
  for (const it of scored) {
    if (selected.length >= desiredCount) break;
    const q = it.q;
    // kategori çeşitliliği
    if (usedCategories.has(q.category) && Math.random() < 0.45) continue;
    selected.push(q);
    usedCategories.add(q.category);
  }
  return selected;
}

function materializeTemplates(templates, userData, analysis) {
  const now = admin.firestore.Timestamp.now();
  return templates.map((q) => {
    const { title, description, tags } = personalizeTemplate(q, userData, analysis);
    const actionRoute = q.actionRoute || '/home';
    const routeKey = routeKeyFromPath(actionRoute);
    return {
      qid: q.id,
      title,
      description,
      type: q.type || 'daily',
      category: q.category,
      progressType: q.progressType || 'increment',
      reward: q.reward,
      goalValue: q.goalValue,
      currentProgress: 0,
      isCompleted: false,
      actionRoute,
      routeKey,
      tags,
      rewardClaimed: false,
      createdAt: now,
      schemaVersion: 2,
    };
  });
}

async function upsertSet(ref, list) {
  const existing = await ref.get();
  const batch = db.batch();
  const seen = new Set();
  list.forEach((q) => { seen.add(q.qid); batch.set(ref.doc(q.qid), q, {merge: true}); });
  // Sil: sadece aynı tip koleksiyonda olup yeni listede olmayanlar ve daily için (haftalık/aylıkta koru)
  existing.docs.forEach((d) => {
    const data = d.data() || {};
    const type = data.type || 'daily';
    if (type === 'daily' && !seen.has(d.id)) batch.delete(d.ref);
  });
  await batch.commit();
}

async function ensureWeeklyAndMonthly(userRef, userData, analysis, force = false) {
  const ctx = await getUserContext(userRef);
  // Haftalık: bu haftanın başlangıcına bak
  const now = nowIstanbul();
  const weekStart = new Date(now);
  weekStart.setDate(now.getDate() - (now.getDay() === 0 ? 6 : (now.getDay()-1))); // Pazartesi başlangıç
  weekStart.setHours(0,0,0,0);
  const weekKey = `${weekStart.getFullYear()}-${(weekStart.getMonth()+1).toString().padStart(2,'0')}-${weekStart.getDate().toString().padStart(2,'0')}`;

  const weeklyCol = userRef.collection('weekly_quests');
  const weeklySnap = await weeklyCol.where('weekKey', '==', weekKey).limit(1).get();
  if (weeklySnap.empty || force) {
    if (force) {
      const toDel = await weeklyCol.where('weekKey', '==', weekKey).get();
      const delBatch = db.batch();
      toDel.docs.forEach((d)=> delBatch.delete(d.ref));
      if (!toDel.empty) await delBatch.commit();
    }
    const tpls = pickTemplatesForType('weekly', ctx, 6);
    const list = materializeTemplates(tpls, userData, analysis).map((x)=> ({...x, weekKey}));
    const batch = db.batch();
    list.forEach((q)=> batch.set(weeklyCol.doc(q.qid), q, {merge:true}));
    await batch.commit();
  }

  // Aylık: ay başlangıcı
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const monthKey = `${monthStart.getFullYear()}-${(monthStart.getMonth()+1).toString().padStart(2,'0')}`;
  const monthlyCol = userRef.collection('monthly_quests');
  const monthlySnap = await monthlyCol.where('monthKey', '==', monthKey).limit(1).get();
  if (monthlySnap.empty || force) {
    if (force) {
      const toDel = await monthlyCol.where('monthKey', '==', monthKey).get();
      const delBatch = db.batch();
      toDel.docs.forEach((d)=> delBatch.delete(d.ref));
      if (!toDel.empty) await delBatch.commit();
    }
    const tpls = pickTemplatesForType('monthly', ctx, 6);
    const list = materializeTemplates(tpls, userData, analysis).map((x)=> ({...x, monthKey}));
    const batch = db.batch();
    list.forEach((q)=> batch.set(monthlyCol.doc(q.qid), q, {merge:true}));
    await batch.commit();
  }
}

function pickDailyQuestsForUser(userData, analysis, ctx) {
  const tpls = pickTemplatesForType('daily', ctx, 7);
  return materializeTemplates(tpls, userData, analysis);
}

/**
 * Tüm kullanıcılar için günlük/haftalık/aylık görevleri güncelle.
 */
async function generateQuestsForAllUsers() {
  const usersSnap = await db.collection("users").get();
  const batchPromises = [];
  let batch = db.batch();
  let opCount = 0;

  for (const doc of usersSnap.docs) {
    const userRef = doc.ref;
    let analysis = null; let ctx = null;
    try {
      const a = await userRef.collection('performance').doc('analysis_summary').get();
      analysis = a.exists ? a.data() : null;
    } catch (_) { analysis = null; }
    ctx = await getUserContext(userRef);

    // DAILY
    const dailyRef = userRef.collection("daily_quests");
    const daily = pickDailyQuestsForUser(doc.data(), analysis, ctx);
    const existing = await dailyRef.get();
    existing.docs.forEach((d) => { batch.delete(d.ref); opCount++; });
    daily.forEach((q) => { batch.set(dailyRef.doc(q.qid), q, {merge:true}); opCount++; });
    batch.update(userRef, { lastQuestRefreshDate: admin.firestore.FieldValue.serverTimestamp() });

    // WEEKLY / MONTHLY ensure
    await ensureWeeklyAndMonthly(userRef, doc.data(), analysis, false);

    if (opCount > 400) { batchPromises.push(batch.commit()); batch = db.batch(); opCount = 0; }
  }

  if (opCount > 0) batchPromises.push(batch.commit());
  await Promise.all(batchPromises);
}

// Her gün gece yarısı tüm kullanıcılar için görevleri yenileyen zamanlanmış fonksiyon.
exports.generateDailyQuests = onSchedule(
    {schedule: "0 0 * * *", timeZone: "Europe/Istanbul"},
    async () => {
      await generateQuestsForAllUsers();
      logger.info("Günlük/Haftalık/Aylık görevler güncellendi.");
    },
);

// Tek bir kullanıcı için GÜNLÜK görevleri yeniden oluşturan callable (weekly/monthly korunur)
exports.regenerateDailyQuests = onCall(
  {region: 'us-central1'},
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
    const uid = request.auth.uid;
    const userRef = db.collection('users').doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) throw new HttpsError('not-found', 'Kullanıcı yok');
    let analysis = null; let ctx = null;
    try {
      const a = await userRef.collection('performance').doc('analysis_summary').get();
      analysis = a.exists ? a.data() : null;
    } catch (_) { analysis = null; }
    ctx = await getUserContext(userRef);

    const daily = pickDailyQuestsForUser(userSnap.data(), analysis, ctx);
    const dailyRef = userRef.collection('daily_quests');
    const existing = await dailyRef.get();
    const batch = db.batch();
    existing.docs.forEach((d) => batch.delete(d.ref));
    daily.forEach((q) => batch.set(dailyRef.doc(q.qid), q, {merge: true}));
    batch.update(userRef, { lastQuestRefreshDate: admin.firestore.FieldValue.serverTimestamp() });
    await batch.commit();

    // Weekly/Aylık görevler: force parametresine göre yenile
    const forceWM = request.data && request.data.forceWeeklyMonthly === true;
    await ensureWeeklyAndMonthly(userRef, userSnap.data(), analysis, forceWM);

    return {quests: daily};
  },
);

function questCollections(userId) {
  const base = db.collection('users').doc(userId);
  return [base.collection('daily_quests'), base.collection('weekly_quests'), base.collection('monthly_quests')];
}

async function findQuestDoc(userId, questId) {
  const cols = questCollections(userId);
  for (const c of cols) {
    const d = await c.doc(questId).get();
    if (d.exists) return d;
  }
  return null;
}

// Bir görevi tamamlandı olarak işaretleyen fonksiyon. (server tarafa doğrulama basit)
exports.completeQuest = onCall({region: "us-central1"}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const questId = request.data?.questId;
  if (!questId) throw new HttpsError("invalid-argument", "questId gerekli");
  const uid = request.auth.uid;
  const snap = await findQuestDoc(uid, questId);
  if (!snap) throw new HttpsError("not-found", "Görev bulunamadı");
  const qData = snap.data() || {};
  if (qData.isCompleted) return {alreadyCompleted: true};

  // Basit anti-fake: increment tipi için minimum mevcut ilerleme kontrolü
  const currentProgress = Number(qData.currentProgress || 0);
  const goalValue = Number(qData.goalValue || 0);
  if ((qData.progressType || 'increment') === 'increment' && currentProgress < Math.max(1, Math.floor(goalValue*0.7))) {
    // Çok düşük ilerlemede doğrudan tamamlamayı engelle (istemci yanlışı/hileyi kes)
    throw new HttpsError('failed-precondition', 'Görev ilerlemesi yetersiz');
  }

  await snap.ref.update({
    isCompleted: true,
    currentProgress: goalValue,
    completionDate: admin.firestore.Timestamp.now(),
  });
  return {success: true};
});

// Gemini API'sine güvenli bir şekilde istek atan proxy fonksiyonu.
const GEMINI_KEY = process.env.GEMINI_API_KEY;

// Güvenlik ve kötüye kullanım önleme ayarları
const GEMINI_PROMPT_MAX_CHARS = parseInt(process.env.GEMINI_PROMPT_MAX_CHARS || '10000', 10);
const GEMINI_MAX_OUTPUT_TOKENS = parseInt(process.env.GEMINI_MAX_OUTPUT_TOKENS || '10000', 10);
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
    // Yeni: sıcaklık isteğe bağlı
    let temperature = 0.8;
    if (typeof request.data?.temperature === 'number' && isFinite(request.data.temperature)) {
      // Güvenli aralık [0.1, 1.0]
      temperature = Math.min(1.0, Math.max(0.1, request.data.temperature));
    }

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
          temperature,
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

// Yeni: Soru bildirimi oluşturulunca indeks güncelle
exports.onQuestionReportCreated = onDocumentCreated("questionReports/{reportId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const d = snap.data();
  if (!d) return;
  const qhash = d.qhash;
  if (!qhash) return;

  const idxRef = db.collection('question_report_index').doc(qhash);
  await db.runTransaction(async (tx) => {
    const idx = await tx.get(idxRef);
    if (!idx.exists) {
      tx.set(idxRef, {
        qhash,
        question: d.question || '',
        options: d.options || [],
        correctIndex: d.correctIndex ?? -1,
        subjects: d.subject ? [d.subject] : [],
        topics: d.topic ? [d.topic] : [],
        reportCount: 1,
        sampleReasons: d.reason ? [d.reason] : [],
        lastReportedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      const updates = {
        reportCount: admin.firestore.FieldValue.increment(1),
        lastReportedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (d.subject) updates.subjects = admin.firestore.FieldValue.arrayUnion(d.subject);
      if (d.topic) updates.topics = admin.firestore.FieldValue.arrayUnion(d.topic);
      if (d.reason) updates.sampleReasons = admin.firestore.FieldValue.arrayUnion(d.reason);
      tx.update(idxRef, updates);
    }
  });
});

// Yardımcı: qhash için indeks dokümanını yeniden hesapla
async function recomputeQuestionReportIndex(qhash) {
  if (!qhash) return;
  const idxRef = db.collection('question_report_index').doc(qhash);
  // Kalan raporları çek
  const snap = await db.collection('questionReports').where('qhash', '==', qhash).limit(1000).get();
  if (snap.empty) {
    // Hiç rapor yoksa indeks dokümanını kaldır
    await idxRef.delete().catch(() => {});
    return {reportCount: 0};
  }
  let reportCount = 0;
  const subjects = new Set();
  const topics = new Set();
  const reasons = new Set();
  let question = '';
  let options = [];
  let correctIndex = -1;

  snap.docs.forEach((d) => {
    const data = d.data() || {};
    reportCount++;
    if (!question && data.question) {
      question = data.question;
      options = Array.isArray(data.options) ? data.options : [];
      correctIndex = typeof data.correctIndex === 'number' ? data.correctIndex : -1;
    }
    if (data.subject) subjects.add(String(data.subject));
    if (data.topic) topics.add(String(data.topic));
    if (data.reason) {
      if (reasons.size < 12) reasons.add(String(data.reason));
    }
  });

  const updates = {
    qhash,
    question,
    options,
    correctIndex,
    subjects: Array.from(subjects),
    topics: Array.from(topics),
    sampleReasons: Array.from(reasons),
    reportCount,
    lastReportedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await idxRef.set(updates, {merge: true});
  return updates;
}

// Silme tetikleyicisi: bir rapor silindiğinde indeksi güncel tut
exports.onQuestionReportDeleted = onDocumentDeleted("questionReports/{reportId}", async (event) => {
  const snap = event.data; // DocumentSnapshot
  const d = snap && snap.data();
  const qhash = d && d.qhash;
  if (!qhash) return;
  try {
    await recomputeQuestionReportIndex(qhash);
  } catch (e) {
    logger.warn('Index recompute failed on delete', {qhash, error: String(e)});
  }
});

// Admin: bildirimi silmek için callable (tekil veya toplu)
exports.adminDeleteQuestionReports = onCall({region: 'us-central1', timeoutSeconds: 300}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
  const isAdmin = request.auth.token && request.auth.token.admin === true;
  if (!isAdmin) throw new HttpsError('permission-denied', 'Admin gerekli');

  const mode = String(request.data?.mode || 'single');

  if (mode === 'single') {
    const reportId = String(request.data?.reportId || '');
    if (!reportId) throw new HttpsError('invalid-argument', 'reportId gerekli');
    const ref = db.collection('questionReports').doc(reportId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError('not-found', 'Rapor bulunamadı');
    const qhash = (snap.data() || {}).qhash;
    await ref.delete();
    await recomputeQuestionReportIndex(qhash);
    return {ok: true, qhash, deleted: 1};
  }

  if (mode === 'byQhash') {
    const qhash = String(request.data?.qhash || '');
    if (!qhash) throw new HttpsError('invalid-argument', 'qhash gerekli');
    let total = 0;
    // Parti parti sil
    while (true) {
      const qs = await db.collection('questionReports').where('qhash', '==', qhash).limit(300).get();
      if (qs.empty) break;
      const batch = db.batch();
      qs.docs.forEach((d) => { batch.delete(d.ref); total++; });
      await batch.commit();
      if (qs.size < 300) break;
    }
    // İndeksi kaldır (rapor kalmadı)
    await db.collection('question_report_index').doc(qhash).delete().catch(() => {});
    return {ok: true, qhash, deleted: total};
  }

  if (mode === 'indexOnly') {
    const qhash = String(request.data?.qhash || '');
    if (!qhash) throw new HttpsError('invalid-argument', 'qhash gerekli');
    await db.collection('question_report_index').doc(qhash).delete();
    return {ok: true, qhash, deleted: 0};
  }

  throw new HttpsError('invalid-argument', 'Geçersiz mode');
});
