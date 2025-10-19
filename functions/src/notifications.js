const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const { db, admin, messaging } = require("./init");
const { dayKeyIstanbul, nowIstanbul, enforceRateLimit, getClientIpFromRawRequest } = require("./utils");
const { computeInactivityHours, selectAudienceUids } = require("./users");
const fs = require("fs");
const path = require("path");

// ---- NOTIFICATION TEMPLATES ----
const NOTIFICATION_TEMPLATES = (() => {
  try {
    const p = path.join(__dirname, "../notification_templates.json");
    const raw = fs.readFileSync(p, "utf8");
    return JSON.parse(raw);
  } catch (error) {
    logger.error("notification_templates.json dosyası okunamadı!", error);
    return [];
  }
})();

// ---- FCM TOKEN KAYDI ----
exports.registerFcmToken = onCall({ region: "us-central1", enforceAppCheck: true, maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const uid = request.auth.uid;

  // Rate limit: kullanıcı ve IP bazlı (pencere: 60 sn)
  const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
  await Promise.all([
    enforceRateLimit(`fcm_register_uid_${uid}`, 60, 10),
    enforceRateLimit(`fcm_register_ip_${ip}`, 60, 50),
  ]);

  const token = String(request.data?.token || "");
  const platform = String(request.data?.platform || "unknown");
  const lang = String(request.data?.lang || "tr");
  if (!token || token.length < 10) throw new HttpsError("invalid-argument", "Geçerli token gerekli");
  const deviceId = token.replace(/[^a-zA-Z0-9_-]/g, "").slice(0, 140);
  const appVersion = request.data?.appVersion ? String(request.data.appVersion) : null;
  const appBuild = request.data?.appBuild != null ? Number(request.data.appBuild) : null;

  // Kullanıcı başına cihaz limiti (aktif kayıtlar)
  const devicesRef = db.collection("users").doc(uid).collection("devices");
  const existingActive = await devicesRef.where("disabled", "==", false).limit(50).get();
  const MAX_ACTIVE_DEVICES = 20;
  if (existingActive.size >= MAX_ACTIVE_DEVICES) {
    throw new HttpsError("resource-exhausted", `Cihaz limiti aşıldı (en fazla ${MAX_ACTIVE_DEVICES}). Eski cihazlarınızı kaldırın.`);
  }

  const ref = devicesRef.doc(deviceId);
  await ref.set({
    uid,
    token,
    platform,
    lang,
    disabled: false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(appVersion ? { appVersion } : {}),
    ...(Number.isFinite(appBuild) ? { appBuild } : {}),
  }, { merge: true });
  return { ok: true };
});

// ---- FCM TOKEN TEMİZLEME ----
exports.unregisterFcmToken = onCall({ region: "us-central1", enforceAppCheck: true, maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const uid = request.auth.uid;

  // Rate limit: kullanıcı ve IP bazlı (pencere: 60 sn)
  const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
  await Promise.all([
    enforceRateLimit(`fcm_unregister_uid_${uid}`, 60, 20),
    enforceRateLimit(`fcm_unregister_ip_${ip}`, 60, 100),
  ]);

  const token = String(request.data?.token || "");
  if (!token || token.length < 10) throw new HttpsError("invalid-argument", "Geçerli token gerekli");

  try {
    // Token'a sahip tüm cihaz kayıtlarını bul ve devre dışı bırak
    const devicesRef = db.collection("users").doc(uid).collection("devices");
    const snapshot = await devicesRef.where("token", "==", token).get();

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        disabled: true,
        unregisteredAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    if (!snapshot.empty) {
      await batch.commit();
      logger.info("FCM token unregistered", { uid, tokenLength: token.length, devicesUpdated: snapshot.size });
    }

    return { ok: true, devicesUpdated: snapshot.size };
  } catch (error) {
    logger.error("FCM token unregister failed", { uid, error: String(error) });
    throw new HttpsError("internal", "Token temizleme işlemi başarısız");
  }
});

async function getActiveTokens(uid) {
  const snap = await db.collection("users").doc(uid).collection("devices").where("disabled", "==", false).limit(50).get();
  if (snap.empty) return [];
  const list = snap.docs.map((d)=> (d.data()||{}).token).filter(Boolean);
  return Array.from(new Set(list));
}

async function getActiveTokensFiltered(uid, filters = {}) {
  try {
    const platforms = Array.isArray(filters.platforms) ? filters.platforms.filter((x)=> typeof x === "string" && x).map((s)=> s.toLowerCase()) : [];
    // Firestore'da sadece basit filtre: disabled ve (opsiyonel) platform in
    let q = db.collection("users").doc(uid).collection("devices").where("disabled", "==", false);
    if (platforms.length > 0 && platforms.length <= 10) q = q.where("platform", "in", platforms);

    // Limit makul bir değerde tutulur; kullanıcı başına çok az cihaz vardır.
    const snap = await q.limit(200).get();
    if (snap.empty) return [];

    const buildMin = Number.isFinite(filters.buildMin) ? Number(filters.buildMin) : null;
    const buildMax = Number.isFinite(filters.buildMax) ? Number(filters.buildMax) : null;

    const list = [];
    for (const d of snap.docs) {
      const it = d.data() || {};
      const build = typeof it.appBuild === "number" ? it.appBuild : (typeof it.appBuild === "string" ? Number(it.appBuild) : null);
      // Build filtrelerini bellek içinde uygula; alan yoksa 0 varsayalım
      const b = Number.isFinite(build) ? Number(build) : 0;
      if (buildMin !== null && !(b >= buildMin)) continue;
      if (buildMax !== null && !(b <= buildMax)) continue;
      if (it.token) list.push(it.token);
    }
    return Array.from(new Set(list));
  } catch (e) {
    // Aşırı durumlarda güvenli geri dönüş
    logger.error("getActiveTokensFiltered failed, fallback to unfiltered", { error: String(e) });
    const all = await db.collection("users").doc(uid).collection("devices").where("disabled", "==", false).limit(200).get();
    if (all.empty) return [];
    const buildMin = Number.isFinite(filters.buildMin) ? Number(filters.buildMin) : null;
    const buildMax = Number.isFinite(filters.buildMax) ? Number(filters.buildMax) : null;
    const platforms = Array.isArray(filters.platforms) ? filters.platforms.filter((x)=> typeof x === "string" && x).map((s)=> s.toLowerCase()) : [];
    const list = [];
    for (const d of all.docs) {
      const it = d.data() || {};
      if (platforms.length > 0 && !platforms.includes(String(it.platform || "").toLowerCase())) continue;
      const build = typeof it.appBuild === "number" ? it.appBuild : (typeof it.appBuild === "string" ? Number(it.appBuild) : null);
      const b = Number.isFinite(build) ? Number(build) : 0;
      if (buildMin !== null && !(b >= buildMin)) continue;
      if (buildMax !== null && !(b <= buildMax)) continue;
      if (it.token) list.push(it.token);
    }
    return Array.from(new Set(list));
  }
}

async function canSendMoreToday(uid, maxPerDay = 3) {
  const countersRef = db.collection("users").doc(uid).collection("state").doc("notification_counters");
  let allowed = false;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(countersRef);
    const today = dayKeyIstanbul();
    if (!snap.exists) {
      // İlk kez: bu çağrıda bir gönderim yapılacağından sent=1
      tx.set(countersRef, { day: today, sent: 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      allowed = true;
      return;
    }
    const d = snap.data() || {};
    let sent = Number(d.sent || 0);
    let day = String(d.day || "");
    if (day !== today) {
      day = today; sent = 0;
    }
    if (sent < maxPerDay) {
      tx.set(countersRef, { day, sent: sent + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      allowed = true;
    } else {
      allowed = false;
    }
  });
  return allowed;
}

async function getUserContextForNotifications(userRef) {
  const ctx = {
    user: null,
    stats: null,
    app: null,
    analysis: null,
    plan: null,
    quests: [],
    inactive_hours: 0,
    last_notification_ids: [],
  };

  try {
    const [userSnap, statsSnap, appSnap, analysisSnap, planSnap, questsSnap, notifSnap] = await Promise.all([
      userRef.get(),
      userRef.collection("state").doc("stats").get(),
      userRef.collection("state").doc("app_state").get(),
      userRef.collection("performance").doc("analysis_summary").get(),
      userRef.collection("plans").doc("current_plan").get(),
      userRef.collection("daily_quests").get(),
      userRef.collection("state").doc("notification_history").get(),
    ]);

    if (userSnap.exists) ctx.user = userSnap.data();
    if (statsSnap.exists) ctx.stats = statsSnap.data();
    if (appSnap.exists) ctx.app = appSnap.data();
    if (analysisSnap.exists) ctx.analysis = analysisSnap.data();
    if (planSnap.exists) ctx.plan = planSnap.data();
    if (notifSnap.exists) ctx.last_notification_ids = (notifSnap.data()?.recent_ids || []).slice(0, 10);
    if (!questsSnap.empty) {
      questsSnap.forEach((doc) => ctx.quests.push(doc.data()));
    }

    ctx.inactive_hours = await computeInactivityHours(userRef);
  } catch (error) {
    logger.error(`Failed to get user context for ${userRef.id}`, { error: String(error) });
  }

  return ctx;
}

function evaluateNotificationConditions(template, ctx) {
  const cond = template.conditions || {};
  if (!cond || Object.keys(cond).length === 0) return true; // No conditions, always true.

  // Inactivity
  if (cond.min_inactive_hours && !(ctx.inactive_hours >= cond.min_inactive_hours)) return false;
  if (cond.max_inactive_hours && !(ctx.inactive_hours < cond.max_inactive_hours)) return false;

  // Time-based
  const now = nowIstanbul();
  if (cond.time_of_day) {
    const h = now.getHours();
    const timeOfDay = h < 12 ? "morning" : h < 18 ? "afternoon" : "evening";
    if (timeOfDay !== cond.time_of_day) return false;
  }
  if (cond.day_of_week) {
    const map = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
    const today = map[now.getDay()];
    const wanted = Array.isArray(cond.day_of_week) ? cond.day_of_week : [cond.day_of_week];
    if (!wanted.includes(today)) return false;
  }

  // Weekly Plan
  if (cond.has_weekly_plan && !(ctx.plan && ctx.plan.weeklyPlan && Object.keys(ctx.plan.weeklyPlan).length > 0)) return false;
  if (cond.weekly_plan_progress_percent === 0) {
    const progress = ctx.plan?.completionRatio ?? 1; // Assume 1 if not available
    if (progress > 0) return false;
  }
  if (cond.min_weekly_plan_progress_percent && !(ctx.plan?.completionRatio * 100 >= cond.min_weekly_plan_progress_percent)) return false;
  if (cond.max_weekly_plan_progress_percent && !(ctx.plan?.completionRatio * 100 < cond.max_weekly_plan_progress_percent)) return false;
  if (cond.min_hours_since_plan_creation) {
    const createdAt = ctx.plan?.createdAt?.toMillis() ?? 0;
    const hoursSince = (Date.now() - createdAt) / (1000 * 60 * 60);
    if (hoursSince < cond.min_hours_since_plan_creation) return false;
  }

  // Streak
  if (cond.min_streak && !(ctx.stats?.streak >= cond.min_streak)) return false;
  if (cond.just_broke_streak_record && !(ctx.stats?.justBrokeStreakRecord === true)) return false; // This needs to be set elsewhere

  // Performance
  if (cond.has_weak_subject && !(ctx.analysis?.weakestSubjectByNet && ctx.analysis.weakestSubjectByNet !== "Belirlenemedi")) return false;
  if (cond.has_strong_subject && !(ctx.analysis?.strongestSubjectByNet && ctx.analysis.strongestSubjectByNet !== "Belirlenemedi")) return false;
  if (cond.last_test_high_score && !(ctx.stats?.lastTestWasHighScore === true)) return false; // Needs to be set
  if (cond.last_test_low_score && !(ctx.stats?.lastTestWasLowScore === true)) return false; // Needs to be set

  // Activity
  if (cond.days_since_last_test) {
    const lastTestDate = ctx.stats?.lastTestDate?.toMillis() ?? 0;
    const daysSince = (Date.now() - lastTestDate) / (1000 * 60 * 60 * 24);
    if (daysSince < cond.days_since_last_test) return false;
  }
  if (cond.is_first_test_of_week && !(ctx.stats?.isFirstTestOfWeek === true)) return false; // Needs to be set
  if (cond.all_daily_quests_completed) {
    if (ctx.quests.length === 0 || ctx.quests.some((q) => !q.isCompleted)) return false;
  }
  if (cond.min_study_time_today_minutes) {
    // This requires tracking study time, which is not in the current context.
    // For now, we'll assume this condition is not met.
    return false;
  }

  // Feature Usage
  if (cond.feature_not_used) {
    const feature = cond.feature_not_used;
    if (ctx.app && ctx.app[`feature_${feature}_used`] === true) return false;
  }

  // Exam
  if (cond.days_until_exam) {
    const examDate = ctx.user?.examDate?.toMillis() ?? 0;
    if (examDate === 0) return false;
    const daysUntil = (examDate - Date.now()) / (1000 * 60 * 60 * 24);
    if (daysUntil > cond.days_until_exam) return false;
  }

  return true;
}

function selectNotificationForUser(ctx) {
  const eligible = NOTIFICATION_TEMPLATES.filter((template) => {
    // Don't send the same notification twice in a row
    if (ctx.last_notification_ids.includes(template.id)) {
      return false;
    }
    return evaluateNotificationConditions(template, ctx);
  });

  if (eligible.length === 0) {
    return null;
  }

  // Simple random selection among eligible templates for now
  const selected = eligible[Math.floor(Math.random() * eligible.length)];

  // Personalize body
  let body = selected.body;
  if (ctx.analysis?.weakestSubjectByNet) {
    body = body.replace("{weakest_subject}", ctx.analysis.weakestSubjectByNet);
  }
  if (ctx.analysis?.strongestSubjectByNet) {
    body = body.replace("{strongest_subject}", ctx.analysis.strongestSubjectByNet);
  }

  return {
    id: selected.id,
    title: selected.title,
    body: body,
    route: selected.route,
  };
}

async function sendPushToTokens(tokens, payload) {
  if (!tokens || tokens.length === 0) return { successCount: 0, failureCount: 0 };
  const uniq = Array.from(new Set(tokens.filter(Boolean)));
  logger.info("sendPushToTokens", { tokenCount: uniq.length, hasImage: !!payload.imageUrl, type: payload.type || "unknown" });
  const collapseId = payload.campaignId || (payload.route || "bilge_general");
  const message = {
    notification: { title: payload.title, body: payload.body, ...(payload.imageUrl ? { imageUrl: payload.imageUrl } : {}) },
    data: { route: payload.route || "/home", campaignId: payload.campaignId || "", type: payload.type || "inactivity", ...(payload.imageUrl ? { imageUrl: payload.imageUrl } : {}) },
    android: {
      collapseKey: collapseId,
      notification: {
        channelId: "bilge_general",
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
        priority: "HIGH",
        ...(payload.imageUrl ? { imageUrl: payload.imageUrl } : {}),
      },
    },
    apns: {
      headers: { "apns-collapse-id": collapseId },
      payload: { aps: { "sound": "default", "mutable-content": 1 } },
      fcmOptions: payload.imageUrl ? { imageUrl: payload.imageUrl } : undefined,
    },
    tokens: uniq,
  };
  try {
    const resp = await messaging.sendEachForMulticast(message);
    return { successCount: resp.successCount, failureCount: resp.failureCount };
  } catch (e) {
    logger.error("FCM send failed", { error: String(e) });
    return { successCount: 0, failureCount: uniq.length };
  }
}

async function recordNotificationHistory(uid, notificationId) {
  const historyRef = db.collection("users").doc(uid).collection("state").doc("notification_history");
  try {
    await historyRef.set({
      recent_ids: admin.firestore.FieldValue.arrayUnion(notificationId),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  } catch (error) {
    logger.error(`Failed to record notification history for ${uid}`, { error: String(error) });
  }
}

async function dispatchInactivityPushBatch(limitUsers = 500) {
  const usersSnap = await db.collection("users").limit(5000).get();
  let processed = 0; let sent = 0; let eligible = 0;
  for (const doc of usersSnap.docs) {
    if (processed >= limitUsers) break;
    processed++;

    const uid = doc.id;
    const userRef = doc.ref;

    const allowed = await canSendMoreToday(uid, 3);
    if (!allowed) continue;

    const ctx = await getUserContextForNotifications(userRef);
    const template = selectNotificationForUser(ctx);

    if (!template) continue;

    eligible++;
    const tokens = await getActiveTokens(uid);
    if (tokens.length === 0) continue;

    await sendPushToTokens(tokens, { ...template, type: "contextual" });
    await recordNotificationHistory(uid, template.id);
    sent++;
  }
  logger.info("dispatchInactivityPushBatch done", { processed, eligible, sent });
  return { processed, eligible, sent };
}

function scheduleSpecAt(hour, minute = 0) {
  return { schedule: `${minute} ${hour} * * *`, timeZone: "Europe/Istanbul" };
}

exports.dispatchInactivityMorning = onSchedule(scheduleSpecAt(9, 0), async () => {
  await dispatchInactivityPushBatch(1500);
});
exports.dispatchInactivityAfternoon = onSchedule(scheduleSpecAt(15, 0), async () => {
  await dispatchInactivityPushBatch(1500);
});
exports.dispatchInactivityEvening = onSchedule(scheduleSpecAt(20, 30), async () => {
  await dispatchInactivityPushBatch(1500);
});

// ---- ADMIN KAMPANYA GÖNDERİMİ ----
exports.adminEstimateAudience = onCall({ region: "us-central1", timeoutSeconds: 300, enforceAppCheck: true, maxInstances: 10 }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const isAdmin = request.auth.token && request.auth.token.admin === true;
  if (!isAdmin) throw new HttpsError("permission-denied", "Admin gerekli");

  // Ek oran sınırlama (admin istismarına karşı)
  const uid = request.auth.uid;
  const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
  await Promise.all([
    enforceRateLimit(`admin_estimate_uid_${uid}`, 60, 20),
    enforceRateLimit(`admin_estimate_ip_${ip}`, 60, 60),
  ]);

  const audience = request.data?.audience || { type: "all" };
  let uids = await selectAudienceUids(audience);

  // İnaktif filtresi (opsiyonel)
  if (audience?.type === "inactive" && typeof audience.hours === "number") {
    const filtered = [];
    for (const uid of uids) {
      const ref = db.collection("users").doc(uid);
      const hrs = await computeInactivityHours(ref);
      if (hrs >= audience.hours) filtered.push(uid);
      if (filtered.length >= 20000) break;
    }
    uids = filtered;
  }

  const baseUsers = uids.length;
  const filters = { buildMin: audience.buildMin, buildMax: audience.buildMax, platforms: audience.platforms };

  // Token sahibi kullanıcı sayısı – batched paralel
  let tokenHolders = 0;
  const batchSize = 50;
  for (let i = 0; i < uids.length; i += batchSize) {
    const batch = uids.slice(i, i + batchSize);
    const results = await Promise.all(batch.map(async (uid) => {
      const tokens = await getActiveTokensFiltered(uid, filters);
      return tokens.length > 0 ? 1 : 0;
    }));
    tokenHolders += results.reduce((a, b)=> a+b, 0);
    // Güvenli sınır – çok büyük kitelerde gereksiz uzun sürmesin
    if (i > 0 && i % 5000 === 0) await new Promise((r)=> setTimeout(r, 50));
  }

  // Kullanıcı sayısı: platform/sürüm filtreleri varsa filtrelenmiş kullanıcı sayısı; aksi halde baz kitle
  const hasDeviceFilters = (Array.isArray(filters.platforms) && filters.platforms.length > 0) || Number.isFinite(filters.buildMin) || Number.isFinite(filters.buildMax);
  const users = hasDeviceFilters ? tokenHolders : baseUsers;

  return { users, baseUsers, tokenHolders };
});

exports.adminSendPush = onCall({ region: "us-central1", timeoutSeconds: 540, enforceAppCheck: true, maxInstances: 10 }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const isAdmin = request.auth.token && request.auth.token.admin === true;
  if (!isAdmin) throw new HttpsError("permission-denied", "Admin gerekli");

  // Ek oran sınırlama (admin istismarına karşı)
  const uid = request.auth.uid;
  const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
  await Promise.all([
    enforceRateLimit(`admin_sendpush_uid_${uid}`, 60, 10),
    enforceRateLimit(`admin_sendpush_ip_${ip}`, 60, 30),
  ]);

  const title = String(request.data?.title || "").trim();
  const body = String(request.data?.body || "").trim();
  const imageUrl = request.data?.imageUrl ? String(request.data.imageUrl) : "";
  const route = String(request.data?.route || "/home");
  const audience = request.data?.audience || { type: "all" };
  const scheduledAt = typeof request.data?.scheduledAt === "number" ? request.data.scheduledAt : null;
  const sendTypeRaw = String(request.data?.sendType || "push").toLowerCase();
  const sendType = ["push", "inapp", "both"].includes(sendTypeRaw) ? sendTypeRaw : "push";

  if (!title || !body) throw new HttpsError("invalid-argument", "title ve body zorunludur");

  const campaignRef = db.collection("push_campaigns").doc();
  const baseDoc = {
    title, body, imageUrl, route, audience,
    createdBy: request.auth.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    sendType,
  };

  if (scheduledAt && scheduledAt > Date.now() + 15000) {
    await campaignRef.set({ ...baseDoc, status: "scheduled", scheduledAt });
    return { ok: true, campaignId: campaignRef.id, scheduled: true };
  }

  await campaignRef.set({ ...baseDoc, status: "sending" });

  let targetUids = await selectAudienceUids(audience);
  logger.info("adminSendPush audience selected", { count: targetUids.length, type: audience?.type || "all" });
  if (audience?.type === "inactive" && typeof audience.hours === "number") {
    const filtered = [];
    for (const uid of targetUids) {
      const ref = db.collection("users").doc(uid);
      const hrs = await computeInactivityHours(ref);
      if (hrs >= audience.hours) filtered.push(uid);
    }
    targetUids = filtered;
  }

  const filters = { buildMin: audience.buildMin, buildMax: audience.buildMax, platforms: audience.platforms };
  const totalUsers = targetUids.length;
  let totalInApp = 0;
  let totalSent = 0;
  let totalFail = 0;

  // Handle in-app messages first
  if (sendType === "inapp" || sendType === "both") {
    const inAppPromises = targetUids.map((uid) =>
      createInAppForUser(uid, { title, body, imageUrl, route, type: "campaign", campaignId: campaignRef.id }),
    );
    const results = await Promise.all(inAppPromises);
    totalInApp = results.filter(Boolean).length;
  }

  // Handle push notifications
  if (sendType === "push" || sendType === "both") {
    const allTokens = [];
    const batchSize = 100;
    for (let i = 0; i < targetUids.length; i += batchSize) {
      const batchUids = targetUids.slice(i, i + batchSize);
      const tokenPromises = batchUids.map((uid) => getActiveTokensFiltered(uid, filters));
      const tokenBatches = await Promise.all(tokenPromises);
      tokenBatches.forEach((tokens) => allTokens.push(...tokens));
    }

    const uniqueTokens = [...new Set(allTokens)];

    if (uniqueTokens.length > 0) {
      const pushPayload = { title, body, imageUrl, route, type: "campaign", campaignId: campaignRef.id };
      const result = await sendPushToTokens(uniqueTokens, pushPayload);
      totalSent = result.successCount;
      totalFail = result.failureCount;
    }
  }

  await campaignRef.set({ status: "completed", totalUsers, totalSent, totalFail, totalInApp, completedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  return { ok: true, campaignId: campaignRef.id, totalUsers, totalSent, totalFail, totalInApp };
});

exports.processScheduledCampaigns = onSchedule({ schedule: "*/5 * * * *", timeZone: "Europe/Istanbul" }, async () => {
  const now = Date.now();
  const snap = await db.collection("push_campaigns").where("status", "==", "scheduled").where("scheduledAt", "<=", now).limit(10).get();
  if (snap.empty) return;
  for (const doc of snap.docs) {
    const d = doc.data() || {};
    try {
      await doc.ref.set({ status: "sending" }, { merge: true });
      const { title, body, imageUrl, route, audience } = d;
      const sendTypeRaw = String(d.sendType || "push").toLowerCase();
      const sendType = ["push", "inapp", "both"].includes(sendTypeRaw) ? sendTypeRaw : "push";

      let targetUids = await selectAudienceUids(audience);
      if (audience?.type === "inactive" && typeof audience.hours === "number") {
        const filtered = [];
        for (const uid of targetUids) {
          const ref = db.collection("users").doc(uid);
          const hrs = await computeInactivityHours(ref);
          if (hrs >= audience.hours) filtered.push(uid);
        }
        targetUids = filtered;
      }
      const filters = { buildMin: audience?.buildMin, buildMax: audience?.buildMax, platforms: audience?.platforms };
      let totalSent = 0; let totalFail = 0; let totalUsers = 0; let totalInApp = 0;
      for (const uid of targetUids) {
        totalUsers++;
        if (sendType === "inapp" || sendType === "both") {
          const ok = await createInAppForUser(uid, { title, body, imageUrl, route, type: "campaign", campaignId: doc.id });
          if (ok) totalInApp++;
        }
        if (sendType === "push" || sendType === "both") {
          const tokens = await getActiveTokensFiltered(uid, filters);
          if (tokens.length === 0) continue;
          const r = await sendPushToTokens(tokens, { title, body, imageUrl, route, type: "campaign", campaignId: doc.id });
          totalSent += r.successCount; totalFail += r.failureCount;
          await doc.ref.collection("logs").add({ uid, success: r.successCount, failed: r.failureCount, ts: admin.firestore.FieldValue.serverTimestamp() });
        }
      }
      await doc.ref.set({ status: "completed", totalUsers, totalSent, totalFail, totalInApp, completedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    } catch (e) {
      logger.error("Scheduled campaign failed", { id: doc.id, error: String(e) });
      await doc.ref.set({ status: "failed", error: String(e), failedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    }
  }
});

// Uygulama içi bildirim oluşturucu
async function createInAppForUser(uid, payload) {
  try {
    const ref = db.collection("users").doc(uid).collection("in_app_notifications");
    const doc = {
      title: payload.title || "",
      body: payload.body || "",
      route: payload.route || "/home",
      imageUrl: payload.imageUrl || "",
      type: payload.type || "campaign",
      campaignId: payload.campaignId || "",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      readAt: null,
    };
    await ref.add(doc);
    return true;
  } catch (e) {
    logger.error("createInAppForUser failed", { uid, error: String(e) });
    return false;
  }
}
