const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const { db, admin } = require("./init");
const { nowIstanbul, routeKeyFromPath } = require("./utils");
const fs = require("fs");
const path = require("path");

// Görev şablonları
const QUEST_TEMPLATES = (() => {
  try {
    const p = path.join(__dirname, "../quests.json");
    const raw = fs.readFileSync(p, "utf8");
    return JSON.parse(raw);
  } catch (error) {
    logger.error("quests.json dosyası okunamadı!", error);
    return [];
  }
})();

function personalizeTemplate(q, userData, analysis) {
  let title = q.title || "Görev";
  let description = q.description || "";
  const tags = Array.isArray(q.tags) ? [...q.tags] : [];

  let subject = null;
  const weakest = analysis && analysis.weakestSubjectByNet;
  const strongest = analysis && analysis.strongestSubjectByNet;

  const needsSubject = (typeof title === "string" && title.includes("{subject}")) ||
    (typeof description === "string" && description.includes("{subject}")) ||
    tags.some((t) => String(t).startsWith("subject:"));

  if (needsSubject) {
    if (tags.includes("weakness") && weakest && weakest !== "Belirlenemedi") {
      subject = weakest;
    } else if (tags.includes("strength") && strongest && strongest !== "Belirlenemedi") {
      subject = strongest;
    } else {
      subject = (userData && userData.selectedExamSection) || "Seçili Ders";
    }

    title = title.replaceAll("{subject}", subject);
    description = description.replaceAll("{subject}", subject);
    if (!tags.some((t) => String(t).startsWith("subject:"))) {
      tags.push(`subject:${subject}`);
    }
  }

  return { title, description, tags };
}

async function getUserContext(userRef) {
  const ctx = { analysis: null, stats: null, app: null, user: null, yesterdayInactive: false, examType: null };
  const userSnap = await userRef.get();
  ctx.user = userSnap.exists ? userSnap.data() : {};
  ctx.examType = (ctx.user && ctx.user.selectedExam) || null;
  try {
    const a = await userRef.collection("performance").doc("analysis_summary").get();
    ctx.analysis = a.exists ? a.data() : null;
  } catch (_) { }
  try {
    const s = await userRef.collection("state").doc("stats").get();
    ctx.stats = s.exists ? s.data() : null;
  } catch (_) { }
  try {
    const app = await userRef.collection("state").doc("app_state").get();
    ctx.app = app.exists ? app.data() : null;
  } catch (_) { }
  try {
    const d = nowIstanbul();
    const y = new Date(d.getFullYear(), d.getMonth(), d.getDate() - 1);
    const id = `${y.getFullYear().toString().padStart(4, "0")}-${(y.getMonth() + 1).toString().padStart(2, "0")}-${y.getDate().toString().padStart(2, "0")}`;
    const act = await userRef.collection("user_activity").doc(id).get();
    const data = act.data() || {};
    const visits = Array.isArray(data.visits) ? data.visits : [];
    ctx.yesterdayInactive = visits.length === 0;
  } catch (_) { }
  return ctx;
}

function timeOfDayLabel(d) {
  const h = d.getHours();
  if (h < 12) return "morning";
  if (h < 18) return "afternoon";
  return "night";
}

function evaluateTriggerConditions(template, ctx) {
  const cond = template.triggerConditions || {};
  if (!cond || Object.keys(cond).length === 0) return true;
  const now = nowIstanbul();
  if (cond.timeOfDay) {
    const wanted = Array.isArray(cond.timeOfDay) ? cond.timeOfDay : [cond.timeOfDay];
    if (!wanted.includes(timeOfDayLabel(now))) return false;
  }
  if (cond.dayOfWeek) {
    const map = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
    const today = map[now.getDay()];
    const wanted = Array.isArray(cond.dayOfWeek) ? cond.dayOfWeek : [cond.dayOfWeek];
    if (!wanted.includes(today)) return false;
  }
  if (cond.wasInactiveYesterday === true && ctx.yesterdayInactive !== true) return false;
  if (cond.hasWeakSubject === true) {
    const w = ctx.analysis && ctx.analysis.weakestSubjectByNet;
    if (!w || w === "Belirlenemedi") return false;
  }
  if (cond.hasStrongSubject === true) {
    const s = ctx.analysis && ctx.analysis.strongestSubjectByNet;
    if (!s || s === "Belirlenemedi") return false;
  }
  if (cond.examType) {
    const wanted = Array.isArray(cond.examType) ? cond.examType : [cond.examType];
    if (!ctx.examType || !wanted.includes(ctx.examType)) return false;
  }
  if (cond.notUsedFeature) {
    const f = String(cond.notUsedFeature);
    const used = ctx.app && ctx.app[`feature_${f}_used`];
    if (used === true) return false;
  }
  if (cond.usedFeatureRecently) {
    const f = String(cond.usedFeatureRecently);
    const used = ctx.app && ctx.app[`feature_${f}_used`];
    if (used !== true) return false;
  }
  if (cond.lowYesterdayPlanRatio === true) {
    const r = ctx.user && ctx.user.lastScheduleCompletionRatio;
    if (!(typeof r === "number" && r < 0.5)) return false;
  }
  if (cond.highYesterdayPlanRatio === true) {
    const r = ctx.user && ctx.user.lastScheduleCompletionRatio;
    if (!(typeof r === "number" && r >= 0.85)) return false;
  }
  return true;
}

function scoreTemplateForUser(t, ctx) {
  let score = t.reward || 0;
  const tags = t.tags || [];
  if (tags.includes("high_value")) score += 40;
  if (tags.includes("weakness") && ctx.analysis && ctx.analysis.weakestSubjectByNet && ctx.analysis.weakestSubjectByNet !== "Belirlenemedi") score += 25;
  if (tags.includes("strength") && ctx.analysis && ctx.analysis.strongestSubjectByNet && ctx.analysis.strongestSubjectByNet !== "Belirlenemedi") score += 15;
  if (tags.includes("quick_win")) score += 5;
  if (t.category === "focus" && ctx.stats && ctx.stats.streak && ctx.stats.streak < 3) score += 8;
  if (t.category === "practice" && ((ctx.user && ctx.user.recentPracticeVolumes) ? Object.keys(ctx.user.recentPracticeVolumes).length < 3 : true)) score += 6;
  return score;
}

function evaluateExcludeConditions(template, ctx) {
  const cond = template.excludeConditions || {};
  if (!cond || Object.keys(cond).length === 0) return false; // No conditions, don't exclude.

  if (cond.hasCreatedStrategicPlan === true && ctx.user && ctx.user.hasCreatedStrategicPlan === true) return true;
  if (cond.hasCustomAvatar === true && (ctx.user && (ctx.user.avatarStyle || ctx.user.avatarSeed))) return true;
  if (cond["usedFeatures.workshop"] === true && ctx.user && ctx.user.usedFeatures && ctx.user.usedFeatures.workshop === true) return true;
  if (cond["usedFeatures.pomodoro"] === true && ctx.user && ctx.user.usedFeatures && ctx.user.usedFeatures.pomodoro === true) return true;

  return false;
}

function pickTemplatesForType(type, ctx, desiredCount) {
  const pool = QUEST_TEMPLATES.filter((q) => {
    if ((q.type || "daily") !== type) return false;
    if (evaluateExcludeConditions(q, ctx)) return false;
    return evaluateTriggerConditions(q, ctx);
  });

  // 1. Skora göre sırala
  const scored = pool.map((q) => ({ q, s: scoreTemplateForUser(q, ctx) })).sort((a, b) => b.s - a.s);

  // 2. En iyi 10 görevi al ve karıştır (daha fazla çeşitlilik için)
  const topPool = scored.slice(0, 10);
  for (let i = topPool.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [topPool[i], topPool[j]] = [topPool[j], topPool[i]]; // Karıştırma
  }

  // 3. Karıştırılmış havuzdan istenen sayıda görev seç, kategori çeşitliliğini koru
  const selected = [];
  const categoryCounts = new Map();
  for (const it of topPool) {
    if (selected.length >= desiredCount) break;
    const q = it.q;
    const currentCategoryCount = categoryCounts.get(q.category) || 0;

    // Bir kategoriden en fazla 2 görev al
    if (currentCategoryCount < 2) {
      selected.push(q);
      categoryCounts.set(q.category, currentCategoryCount + 1);
    }
  }
  return selected;
}

function materializeTemplates(templates, userData, analysis) {
  const nowTs = admin.firestore.Timestamp.now();
  return templates.map((q) => {
    const { title, description, tags } = personalizeTemplate(q, userData, analysis);
    const actionRoute = q.actionRoute || "/home";
    const routeKey = routeKeyFromPath(actionRoute);
    return { qid: q.id, title, description, type: q.type || "daily", category: q.category, progressType: q.progressType || "increment", reward: q.reward, goalValue: q.goalValue, currentProgress: 0, isCompleted: false, actionRoute, routeKey, tags, rewardClaimed: false, createdAt: nowTs, schemaVersion: 2 };
  });
}

function pickDailyQuestsForUser(userData, analysis, ctx) {
  const tpls = pickTemplatesForType("daily", ctx, 4);
  return materializeTemplates(tpls, userData, analysis);
}

async function generateQuestsForAllUsers() {
  const usersSnap = await db.collection("users").get();
  const batchPromises = [];
  let batch = db.batch();
  let opCount = 0;
  for (const doc of usersSnap.docs) {
    const userRef = doc.ref;
    let analysis = null;
    let ctx = null;
    try {
      const a = await userRef.collection("performance").doc("analysis_summary").get();
      analysis = a.exists ? a.data() : null;
    } catch (_) {
      analysis = null;
    }
    ctx = await getUserContext(userRef);
    const dailyRef = userRef.collection("daily_quests");
    const daily = pickDailyQuestsForUser(doc.data(), analysis, ctx);
    const existing = await dailyRef.get();
    existing.docs.forEach((d) => {
      batch.delete(d.ref);
      opCount++;
    });
    daily.forEach((q) => {
      batch.set(dailyRef.doc(q.qid), q, { merge: true });
      opCount++;
    });
    batch.update(userRef, { lastQuestRefreshDate: admin.firestore.FieldValue.serverTimestamp() });
    if (opCount > 400) {
      batchPromises.push(batch.commit());
      batch = db.batch();
      opCount = 0;
    }
  }
  if (opCount > 0) batchPromises.push(batch.commit());
  await Promise.all(batchPromises);
}

// İSTEMCİDEN GÜNLÜK GÖREV YENİLEME (CALLABLE)
exports.regenerateDailyQuests = onCall({ region: "us-central1", timeoutSeconds: 60 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Oturum gerekli");
  }
  const uid = request.auth.uid;
  try {
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw new HttpsError("failed-precondition", "Kullanıcı bulunamadı");
    }
    const userData = userSnap.data() || {};

    // Analiz özeti (kişiselleştirme için opsiyonel)
    let analysis = null;
    try {
      const a = await userRef.collection("performance").doc("analysis_summary").get();
      analysis = a.exists ? a.data() : null;
    } catch (_) {
      analysis = null;
    }

    // Kullanıcı bağlamını hazırla ve şablonlardan günlük görevleri seç
    const ctx = await getUserContext(userRef);
    const dailyList = pickDailyQuestsForUser(userData, analysis, ctx);

    // Mevcut günlük görevleri temizle ve yenilerini yaz
    const dailyCol = userRef.collection("daily_quests");
    const existing = await dailyCol.get();
    const batch = db.batch();
    existing.docs.forEach((d) => batch.delete(d.ref));
    dailyList.forEach((q) => batch.set(dailyCol.doc(q.qid), q, { merge: true }));
    batch.update(userRef, { lastQuestRefreshDate: admin.firestore.FieldValue.serverTimestamp() });
    await batch.commit();

    return { ok: true, dailyCount: dailyList.length };
  } catch (e) {
    // Hata durumunda anlamlı bir dönüş
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("internal", `Görev üretimi başarısız: ${String(e)}`);
  }
});

// İstemciden görevi TAMAMLAMA (CALLABLE) — isCompleted sadece sunucuda set edilir
exports.completeQuest = onCall({ region: "us-central1", timeoutSeconds: 30 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Oturum gerekli");
  }
  const uid = request.auth.uid;
  const questId = String((request.data && request.data.questId) || "").trim();
  if (!questId) throw new HttpsError("invalid-argument", "questId zorunlu");

  try {
    const userRef = db.collection("users").doc(uid);
    const docRef = userRef.collection("daily_quests").doc(questId);
    const snap = await docRef.get();
    if (!snap.exists) throw new HttpsError("not-found", "Görev bulunamadı");

    const data = snap.data() || {};
    if (data.isCompleted === true) {
      // idempotent: zaten tamamlandı
      return { ok: true, alreadyCompleted: true };
    }

    const goal = Number(data.goalValue || 0);
    const cur = Number(data.currentProgress || 0);

    // Görevin gerçekten tamamlanması için hedefe ulaşıp ulaşmadığını kontrol et
    if (goal > 0 && cur < goal) {
      throw new HttpsError("failed-precondition", `Görev henüz tamamlanmadı. İlerleme: ${cur}/${goal}`);
    }

    const clamped = Math.min(Math.max(cur, 0), goal);

    // Güvenli güncelleme - race condition'ları önle
    await docRef.update({
      currentProgress: goal > 0 ? Math.max(clamped, goal) : clamped,
      isCompleted: true,
      completionDate: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Ödül ve puan güncellemesi artık istemci tarafında (claimQuestReward veya _handleQuestCompletion)
    // 'stats' dokümanındaki 'engagementScore' alanı üzerinden merkezi olarak yapılıyor.
    // Bu nedenle buradaki 'bilgePoints' güncellemesi kaldırılmıştır.

    return { ok: true };
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("internal", `Tamamlama başarısız: ${String(e)}`);
  }
});

// Otomatik Görev Tamamlama: İlerleme hedefe ulaştığında backend işaretler
async function autoCompleteQuestIfNeeded(afterSnap) {
  try {
    if (!afterSnap.exists) return;
    const data = afterSnap.data() || {};
    if (data.isCompleted === true) return; // zaten tamamlandı
    const goal = Number(data.goalValue || 0);
    const cur = Number(data.currentProgress || 0);
    if (goal > 0 && cur >= goal) {
      await afterSnap.ref.set({
        currentProgress: Math.max(cur, goal),
        isCompleted: true,
        completionDate: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  } catch (e) {
    logger.warn("autoCompleteQuestIfNeeded failed", { path: (afterSnap && afterSnap.ref && afterSnap.ref.path) || "", error: String(e) });
  }
}

exports.onDailyQuestProgress = onDocumentWritten({
  document: "users/{userId}/daily_quests/{questId}",
  region: "us-central1"
}, async (event) => {
  if (!(event && event.data && event.data.after)) return;
  await autoCompleteQuestIfNeeded(event.data.after);
});
