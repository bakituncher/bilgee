const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const { db, admin } = require("./init");
const { selectAudienceUids, computeInactivityHours } = require("./users");
const { getActiveTokensFiltered } = require("./tokenManager");
const { sendPushToTokens, sendPushToTokensBatched } = require("./dispatcher");


// ---- ADMIN KAMPANYA GÖNDERİMİ ----
exports.adminEstimateAudience = onCall({ region: "us-central1", timeoutSeconds: 300, enforceAppCheck: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const isAdmin = request.auth.token && request.auth.token.admin === true;
  if (!isAdmin) throw new HttpsError("permission-denied", "Admin gerekli");
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

exports.adminSendPush = onCall({ region: "us-central1", timeoutSeconds: 540, enforceAppCheck: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const isAdmin = request.auth.token && request.auth.token.admin === true;
  if (!isAdmin) throw new HttpsError("permission-denied", "Admin gerekli");

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
      const result = await sendPushToTokensBatched(uniqueTokens, pushPayload, 500);
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

module.exports = {
  adminEstimateAudience: exports.adminEstimateAudience,
  adminSendPush: exports.adminSendPush,
  processScheduledCampaigns: exports.processScheduledCampaigns,
};
