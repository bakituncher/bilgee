const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onMessagePublished } = require("firebase-functions/v2/pubsub");
const { PubSub } = require("@google-cloud/pubsub");
const { logger } = require("firebase-functions");
const { db, admin, messaging } = require("./init");
const { dayKeyIstanbul } = require("./utils");
const { getActiveTokens } = require("./tokenManager");
const { buildPersonalizedTemplate } = require("./templateBuilder");


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

// Günlük limit kontrolü: sadece okuma, sayaç arttırmaz
async function hasRemainingToday(uid, maxPerDay = 3) {
  try {
    const countersRef = db.collection("users").doc(uid).collection("state").doc("notification_counters");
    const snap = await countersRef.get();
    const today = dayKeyIstanbul();
    if (!snap.exists) return true;
    const d = snap.data() || {};
    const day = String(d.day || "");
    const sent = Number(d.sent || 0);
    if (day !== today) return true;
    return sent < maxPerDay;
  } catch (_) {
    return true;
  }
}

// Başarılı gönderim sonrası güvenli şekilde sayaç arttır (gün değişimini dikkate alır)
async function incrementSentCount(uid, maxPerDay = 3) {
  const countersRef = db.collection("users").doc(uid).collection("state").doc("notification_counters");
  let ok = false;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(countersRef);
    const today = dayKeyIstanbul();
    if (!snap.exists) {
      tx.set(countersRef, { day: today, sent: 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      ok = true;
      return;
    }
    const d = snap.data() || {};
    const prevDay = String(d.day || "");
    const prevSent = Number(d.sent || 0);
    const newDay = prevDay === today ? today : today;
    const base = prevDay === today ? prevSent : 0;
    if (base >= maxPerDay) {
      ok = false; return;
    }
    tx.set(countersRef, { day: newDay, sent: base + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    ok = true;
  });
  return ok;
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
    tokens: uniq.slice(0, 500), // güvenlik: tek çağrıda max 500
  };
  try {
    const resp = await messaging.sendEachForMulticast(message);
    return { successCount: resp.successCount, failureCount: resp.failureCount };
  } catch (e) {
    logger.error("FCM send failed", { error: String(e) });
    return { successCount: 0, failureCount: uniq.length };
  }
}

// 500 limitini gözeterek büyük token listelerini parça parça gönder
async function sendPushToTokensBatched(tokens, payload, batchSize = 500) {
  const uniq = Array.from(new Set((tokens || []).filter(Boolean)));
  let successCount = 0; let failureCount = 0;
  for (let i = 0; i < uniq.length; i += batchSize) {
    const chunk = uniq.slice(i, i + batchSize);
    const r = await sendPushToTokens(chunk, payload);
    successCount += r.successCount;
    failureCount += r.failureCount;
    if (i > 0 && i % (batchSize * 10) === 0) await new Promise((r)=> setTimeout(r, 50));
  }
  return { successCount, failureCount };
}

// ---- YENİ Pub/Sub Tabanlı Worker Fonksiyonu ----
const PERSONALIZED_NOTIFICATION_TOPIC = "send-personalized-notification";

exports.sendPersonalizedNotificationWorker = onMessagePublished(
  { topic: PERSONALIZED_NOTIFICATION_TOPIC, region: "europe-west1" },
  async (event) => {
    const uid = event.data.message.json?.uid;
    if (!uid) {
      logger.error("Pub/Sub message missing uid.", { message: event.data.message });
      return;
    }

    try {
      // 1. Optimize edilmiş context'i tek bir okuma ile al
      const contextRef = db.collection("users").doc(uid).collection("state").doc("notification_context");
      const contextSnap = await contextRef.get();
      if (!contextSnap.exists) {
        logger.warn(`Notification context not found for user ${uid}. Skipping.`);
        return;
      }
      const context = contextSnap.data() || {};

      const lastActiveTs = context.lastActiveTs || 0;
      const inactivityHours = lastActiveTs > 0 ? Math.floor((Date.now() - lastActiveTs) / (1000 * 60 * 60)) : 1e6;

      // 4 saatten daha az inaktif olanları rahatsız etme
      if (inactivityHours < 4) {
        return;
      }

      // 2. Kişiselleştirilmiş şablonu oluştur
      const tpl = buildPersonalizedTemplate(
        { isPremium: context.isPremium, selectedExam: context.selectedExam },
        { weakestSubject: context.weakestSubject },
        { streak: context.streak, lostStreak: context.lostStreak },
        inactivityHours,
      );

      if (!tpl) {
        return; // Gönderilecek uygun bildirim bulunamadı
      }

      // 3. Günlük gönderim limitini kontrol et
      const remain = await hasRemainingToday(uid, 3);
      if (!remain) {
        return; // Limit dolu
      }

      // 4. Aktif token'ları al
      const tokens = await getActiveTokens(uid);
      if (tokens.length === 0) {
        return; // Aktif cihaz yok
      }

      // 5. Bildirimi gönder ve sayacı artır
      const r = await sendPushToTokens(tokens, { ...tpl, type: "personalized_inactivity" });
      if (r.successCount > 0) {
        await incrementSentCount(uid, 3);
        logger.info(`Personalized notification sent to user ${uid}`, { successCount: r.successCount, failureCount: r.failureCount });
      }
    } catch (error) {
      logger.error(`Failed to process personalized notification for user ${uid}`, { error: String(error) });
    }
  },
);


// ---- YENİ Pub/Sub Tabanlı Scheduler Fonksiyonu ----
const pubsub = new PubSub();

exports.publishInactiveUserIds = onSchedule("every 1 hours", async () => {
  const now = Date.now();
  const fourHoursAgo = now - 4 * 60 * 60 * 1000;

  try {
    // Son 4 saatten daha uzun süredir aktif olmayan kullanıcıları verimli bir şekilde sorgula
    const inactiveUsersQuery = db.collectionGroup("notification_context")
      .where("lastActiveTs", "<", fourHoursAgo)
      .select(); // Sadece ID'leri almak için

    const snapshot = await inactiveUsersQuery.get();
    if (snapshot.empty) {
      logger.info("No inactive users to notify.");
      return;
    }

    const topic = pubsub.topic(PERSONALIZED_NOTIFICATION_TOPIC);
    const publishPromises = [];

    snapshot.forEach((doc) => {
      const uid = doc.ref.parent.parent.id;
      const data = Buffer.from(JSON.stringify({ uid }));
      publishPromises.push(topic.publishMessage({ data }));
    });

    await Promise.all(publishPromises);
    logger.info(`Published ${snapshot.size} inactive user IDs to Pub/Sub.`);
  } catch (error) {
    logger.error("Failed to publish inactive user IDs.", { error: String(error) });
  }
});


module.exports = {
  sendPersonalizedNotificationWorker: exports.sendPersonalizedNotificationWorker,
  publishInactiveUserIds: exports.publishInactiveUserIds,
  sendPushToTokens,
  sendPushToTokensBatched,
  canSendMoreToday,
  hasRemainingToday,
  incrementSentCount,
};
