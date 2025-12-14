const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const { db, admin, messaging } = require("./init");
const { dayKeyIstanbul } = require("./utils");
const { processAudienceInBatches } = require("./users");

// ---- GENEL MOTİVASYON MESAJLARI HAVUZU ----
const GENERAL_MESSAGES = [
  {
    title: 'Bugün senin günün! 🌟',
    body: 'Dünü geride bırak, bugün hedeflerine odaklan. Küçük bir adım bile seni ileri taşır! 💪',
    route: '/home',
  },
  {
    title: 'Hadi biraz hızlanalım! 🚀',
    body: 'Başarı düzenli çalışmadan gelir. Bugün kendin için 15 dakika ayır ve fark yarat! ⏱️',
    route: '/home/quests',
  },
  {
    title: 'Rakipler durmuyor! 🏃',
    body: 'Arena\'da rekabet kızışıyor. Sıralamadaki yerini korumak için bugün sahaya çık! 🏆',
    route: '/arena',
  },
  {
    title: 'Zayıf noktalarını güçlendir! 💎',
    body: 'Seni zorlayan konuları erteleme. Cevher Atölyesi\'nde eksiklerini tamamla! ⚒️',
    route: '/ai-hub/weakness-workshop',
  },
  {
    title: 'Pomodoro zamanı! 🍅',
    body: 'Odaklanma sorunu mu yaşıyorsun? 25 dakikalık bir Pomodoro seansı ile zihnini aç! 🧠',
    route: '/home/pomodoro',
  },
  {
    title: 'Planlı çalış, kazan! 📅',
    body: 'Haftalık hedeflerinde ne durumdasın? Planını kontrol et ve rotanı belirle! 📊',
    route: '/home/weekly-plan',
  },
  {
    title: 'Kendine bir iyilik yap ✨',
    body: 'Gelecekteki sen, bugün çalıştığın için sana teşekkür edecek. Hadi başla! 🌈',
    route: '/home/add-test',
  },
  {
    title: 'Taktik Tavşan seni bekliyor 🤖',
    body: 'Stratejini gözden geçirmek ister misin? AI Koçunla konuş ve planını güncelle! 💡',
    route: '/ai-hub',
  },
  {
    title: 'Bir test çözmeye ne dersin? 📝',
    body: 'Bilgilerini taze tutmak için kısa bir deneme veya test çöz. İlerlemeni gör! 📈',
    route: '/home/add-test',
  },
  {
    title: 'Motivasyonun mu düştü? 🔋',
    body: 'Yalnız değilsin! Motivasyon köşesinde enerjini topla ve yola devam et. 💪',
    route: '/ai-hub/motivation-chat',
  },
  {
    title: 'Görevler seni bekliyor! 📋',
    body: 'Günlük görevlerini tamamlayarak TP kazan ve seviye atla! 🎯',
    route: '/home/quests',
  },
  {
    title: 'Başarı detaylarda gizli 🔍',
    body: 'Konu analizlerine göz at. Hangi derste daha iyisin, hangisine yüklenmelisin? 📉',
    route: '/home/stats',
  }
];

// ---- FCM TOKEN KAYDI VE TOPIC ABONELİĞİ ----
exports.registerFcmToken = onCall({region: 'us-central1'}, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
    const uid = request.auth.uid;
    const token = String(request.data?.token || '');
    const platform = String(request.data?.platform || 'unknown');
    const lang = String(request.data?.lang || 'tr');
    if (!token || token.length < 10) throw new HttpsError('invalid-argument', 'Geçerli token gerekli');

    const deviceId = token.replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 140);
    const appVersion = request.data?.appVersion ? String(request.data.appVersion) : null;
    const appBuild = request.data?.appBuild != null ? Number(request.data.appBuild) : null;

    // 1. Token'ı veritabanına kaydet (Cihaz takibi ve filtreli gönderimler için hala gerekli)
    const ref = db.collection('users').doc(uid).collection('devices').doc(deviceId);
    await ref.set({
      uid,
      token,
      platform,
      lang,
      disabled: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(appVersion ? { appVersion } : {}),
      ...(Number.isFinite(appBuild) ? { appBuild } : {}),
    }, {merge: true});

    // 2. Token'ı genel bildirim konusuna abone yap (Toplu gönderim için - 0 OKUMA)
    try {
      await messaging.subscribeToTopic(token, 'general');
    } catch (e) {
      logger.warn('Topic subscription failed', { error: String(e), uid });
      // Kritik hata değil, devam et
    }

    return {ok: true};
  });

// ---- FCM TOKEN TEMİZLEME ----
exports.unregisterFcmToken = onCall({region: 'us-central1'}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
  const uid = request.auth.uid;
  const token = String(request.data?.token || '');
  if (!token || token.length < 10) throw new HttpsError('invalid-argument', 'Geçerli token gerekli');

  try {
    // 1. Veritabanında devre dışı bırak
    const devicesRef = db.collection('users').doc(uid).collection('devices');
    const snapshot = await devicesRef.where('token', '==', token).get();

    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.update(doc.ref, {
        disabled: true,
        unregisteredAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    if (!snapshot.empty) {
      await batch.commit();
    }

    // 2. Konu aboneliğinden çıkar
    try {
      await messaging.unsubscribeFromTopic(token, 'general');
    } catch (e) {
      logger.warn('Topic unsubscription failed', { error: String(e) });
    }

    return { ok: true, devicesUpdated: snapshot.size };
  } catch (error) {
    logger.error('FCM token unregister failed', { uid, error: String(error) });
    throw new HttpsError('internal', 'Token temizleme işlemi başarısız');
  }
});

  async function getActiveTokens(uid) {
    const snap = await db.collection('users').doc(uid).collection('devices').where('disabled','==', false).limit(50).get();
    if (snap.empty) return [];
    const list = snap.docs.map((d)=> (d.data()||{}).token).filter(Boolean);
    return Array.from(new Set(list));
  }

  async function getActiveTokensFiltered(uid, filters = {}) {
    try {
      const platforms = Array.isArray(filters.platforms) ? filters.platforms.filter((x)=> typeof x === 'string' && x).map((s)=> s.toLowerCase()) : [];
      let q = db.collection('users').doc(uid).collection('devices').where('disabled','==', false);
      if (platforms.length > 0 && platforms.length <= 10) q = q.where('platform','in', platforms);

      const snap = await q.limit(200).get();
      if (snap.empty) return [];

      const buildMin = Number.isFinite(filters.buildMin) ? Number(filters.buildMin) : null;
      const buildMax = Number.isFinite(filters.buildMax) ? Number(filters.buildMax) : null;

      const list = [];
      for (const d of snap.docs) {
        const it = d.data() || {};
        const build = typeof it.appBuild === 'number' ? it.appBuild : (typeof it.appBuild === 'string' ? Number(it.appBuild) : null);
        const b = Number.isFinite(build) ? Number(build) : 0;
        if (buildMin !== null && !(b >= buildMin)) continue;
        if (buildMax !== null && !(b <= buildMax)) continue;
        if (it.token) list.push(it.token);
      }
      return Array.from(new Set(list));
    } catch (e) {
      logger.error('getActiveTokensFiltered failed', { error: String(e) });
      return [];
    }
  }

  // ---- YARDIMCI FONKSİYONLAR ----

  // Rastgele bir mesaj seç
  function getRandomMessage() {
    const index = Math.floor(Math.random() * GENERAL_MESSAGES.length);
    return GENERAL_MESSAGES[index];
  }

  // Konu (Topic) tabanlı gönderim - 0 OKUMA MALİYETİ
  async function sendTopicNotification(topic = 'general') {
    const payload = getRandomMessage();
    logger.info('Sending random topic notification', { topic, title: payload.title });

    const message = {
      topic: topic,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: {
        route: payload.route || '/home',
        type: 'daily_motivation',
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'bilge_general',
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            'mutable-content': 1
          }
        }
      }
    };

    try {
      const response = await messaging.send(message);
      logger.info('Topic message sent successfully', { messageId: response });
      return { success: true, messageId: response };
    } catch (error) {
      logger.error('Error sending topic message', { error: String(error) });
      return { success: false, error };
    }
  }

  // Zamanlayıcı yardımcı fonksiyonu
  function scheduleSpecAt(hour, minute = 0) {
    return {
      schedule: `${minute} ${hour} * * *`,
      timeZone: 'Europe/Istanbul',
      timeoutSeconds: 60 // Kısa timeout yeterli çünkü işlem çok hafif
    };
  }

  // ---- ZAMANLANMIŞ BİLDİRİM FONKSİYONLARI (SIFIR OKUMA) ----

  exports.dispatchInactivityMorning = onSchedule(scheduleSpecAt(9, 0), async () => {
    logger.info('🌅 Morning random push started (Zero-Read)');
    await sendTopicNotification('general');
  });

  exports.dispatchInactivityAfternoon = onSchedule(scheduleSpecAt(15, 0), async () => {
    logger.info('☀️ Afternoon random push started (Zero-Read)');
    await sendTopicNotification('general');
  });

  exports.dispatchInactivityEvening = onSchedule(scheduleSpecAt(20, 30), async () => {
    logger.info('🌙 Evening random push started (Zero-Read)');
    await sendTopicNotification('general');
  });

  // Admin gönderimleri için yardımcı (tekil token gönderimi)
  async function sendPushToTokens(tokens, payload) {
    if (!tokens || tokens.length === 0) return {successCount: 0, failureCount: 0};
    const uniq = Array.from(new Set(tokens.filter(Boolean)));
    const collapseId = payload.campaignId || (payload.route || 'bilge_general');
    const message = {
      notification: { title: payload.title, body: payload.body, ...(payload.imageUrl ? { imageUrl: payload.imageUrl } : {}) },
      data: { route: payload.route || '/home', campaignId: payload.campaignId || '', type: payload.type || 'admin_push', ...(payload.imageUrl ? { imageUrl: payload.imageUrl } : {}) },
      android: {
        collapseKey: collapseId,
        notification: {
          channelId: 'bilge_general',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          priority: 'HIGH',
          ...(payload.imageUrl ? { imageUrl: payload.imageUrl } : {}),
        },
      },
      apns: {
        headers: { 'apns-collapse-id': collapseId },
        payload: { aps: { sound: 'default', 'mutable-content': 1 } },
        fcmOptions: payload.imageUrl ? { imageUrl: payload.imageUrl } : undefined,
      },
      tokens: uniq,
    };
    try {
      const resp = await messaging.sendEachForMulticast(message);
      return {successCount: resp.successCount, failureCount: resp.failureCount};
    } catch (e) {
      logger.error('FCM send failed', { error: String(e) });
      return {successCount: 0, failureCount: uniq.length};
    }
  }

  // ---- ADMIN KAMPANYA SİSTEMİ (Mevcut haliyle korunuyor) ----
  // Bu kısımlar admin panelinden özel gönderimler için gereklidir ve okuma yapması doğaldır.
  exports.adminEstimateAudience = onCall({ region: "us-central1", timeoutSeconds: 300 }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
    const isAdmin = request.auth.token && request.auth.token.admin === true;
    if (!isAdmin) throw new HttpsError("permission-denied", "Admin gerekli");
    const audience = request.data?.audience || { type: "all" };

    let baseUsers = 0;
    let tokenHolders = 0;
    const filters = { buildMin: audience.buildMin, buildMax: audience.buildMax, platforms: audience.platforms };
    const hasDeviceFilters = (Array.isArray(filters.platforms) && filters.platforms.length > 0) ||
      Number.isFinite(filters.buildMin) ||
      Number.isFinite(filters.buildMax);

    await processAudienceInBatches(audience, async (uidBatch) => {
      baseUsers += uidBatch.length;
      if (!hasDeviceFilters) {
        return; // Cihaz filtresi yoksa sadece kullanıcı saymak yeterli
      }
      const batchSize = 50;
      for (let i = 0; i < uidBatch.length; i += batchSize) {
        const batch = uidBatch.slice(i, i + batchSize);
        const results = await Promise.all(
          batch.map(async (uid) => {
            const tokens = await getActiveTokensFiltered(uid, filters);
            return tokens.length > 0 ? 1 : 0;
          })
        );
        tokenHolders += results.reduce((a, b) => a + b, 0);
        if (i > 0 && i % 5000 === 0) await new Promise((r) => setTimeout(r, 50));
      }
    });

    const users = hasDeviceFilters ? tokenHolders : baseUsers;
    return { users, baseUsers, tokenHolders };
  });

  exports.adminSendPush = onCall({ region: "us-central1", timeoutSeconds: 540 }, async (request) => {
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
      title,
      body,
      imageUrl,
      route,
      audience,
      createdBy: request.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      sendType,
    };

    if (scheduledAt && scheduledAt > Date.now() + 15000) {
      await campaignRef.set({ ...baseDoc, status: "scheduled", scheduledAt });
      return { ok: true, campaignId: campaignRef.id, scheduled: true };
    }

    await campaignRef.set({ ...baseDoc, status: "sending" });

    const filters = { buildMin: audience.buildMin, buildMax: audience.buildMax, platforms: audience.platforms };
    let totalUsers = 0;
    let totalInApp = 0;
    let totalSent = 0;
    let totalFail = 0;

    await processAudienceInBatches(audience, async (uidBatch) => {
      totalUsers += uidBatch.length;

      // In-app bildirimler
      if (sendType === "inapp" || sendType === "both") {
        const inAppPromises = uidBatch.map((uid) =>
          createInAppForUser(uid, { title, body, imageUrl, route, type: "campaign", campaignId: campaignRef.id })
        );
        const results = await Promise.all(inAppPromises);
        totalInApp += results.filter(Boolean).length;
      }

      // Push bildirimler
      if (sendType === "push" || sendType === "both") {
        const allTokens = [];
        const batchSize = 100;
        for (let i = 0; i < uidBatch.length; i += batchSize) {
          const batchUids = uidBatch.slice(i, i + batchSize);
          const tokenPromises = batchUids.map((uid) => getActiveTokensFiltered(uid, filters));
          const tokenBatches = await Promise.all(tokenPromises);
          tokenBatches.forEach((tokens) => allTokens.push(...tokens));
        }

        const uniqueTokens = [...new Set(allTokens)];

        if (uniqueTokens.length > 0) {
          const pushPayload = {
            title,
            body,
            imageUrl,
            route,
            type: "campaign",
            campaignId: campaignRef.id,
          };
          const result = await sendPushToTokens(uniqueTokens, pushPayload);
          totalSent += result.successCount;
          totalFail += result.failureCount;
        }
      }
    });

    await campaignRef.set(
      {
        status: "completed",
        totalUsers,
        totalSent,
        totalFail,
        totalInApp,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return { ok: true, campaignId: campaignRef.id, totalUsers, totalSent, totalFail, totalInApp };
  });

  exports.processScheduledCampaigns = onSchedule({ schedule: "*/5 * * * *", timeZone: "Europe/Istanbul" }, async () => {
    const now = Date.now();
    const snap = await db
      .collection("push_campaigns")
      .where("status", "==", "scheduled")
      .where("scheduledAt", "<=", now)
      .limit(10)
      .get();
    if (snap.empty) return;
    for (const doc of snap.docs) {
      const d = doc.data() || {};
      try {
        await doc.ref.set({ status: "sending" }, { merge: true });
        const { title, body, imageUrl, route, audience } = d;
        const sendTypeRaw = String(d.sendType || "push").toLowerCase();
        const sendType = ["push", "inapp", "both"].includes(sendTypeRaw) ? sendTypeRaw : "push";

        const filters = {
          buildMin: audience?.buildMin,
          buildMax: audience?.buildMax,
          platforms: audience?.platforms,
        };
        let totalSent = 0,
          totalFail = 0,
          totalUsers = 0,
          totalInApp = 0;

        await processAudienceInBatches(audience, async (uidBatch) => {
          totalUsers += uidBatch.length;
          for (const uid of uidBatch) {
            if (sendType === "inapp" || sendType === "both") {
              const ok = await createInAppForUser(uid, {
                title,
                body,
                imageUrl,
                route,
                type: "campaign",
                campaignId: doc.id,
              });
              if (ok) totalInApp++;
            }
            if (sendType === "push" || sendType === "both") {
              const tokens = await getActiveTokensFiltered(uid, filters);
              if (tokens.length === 0) continue;
              const r = await sendPushToTokens(tokens, {
                title,
                body,
                imageUrl,
                route,
                type: "campaign",
                campaignId: doc.id,
              });
              totalSent += r.successCount;
              totalFail += r.failureCount;
              await doc.ref.collection("logs").add({
                uid,
                success: r.successCount,
                failed: r.failureCount,
                ts: admin.firestore.FieldValue.serverTimestamp(),
              });
            }
          }
        });

        await doc.ref.set(
          {
            status: "completed",
            totalUsers,
            totalSent,
            totalFail,
            totalInApp,
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      } catch (e) {
        logger.error("Scheduled campaign failed", { id: doc.id, error: String(e) });
        await doc.ref.set(
          { status: "failed", error: String(e), failedAt: admin.firestore.FieldValue.serverTimestamp() },
          { merge: true }
        );
      }
    }
  });

  async function createInAppForUser(uid, payload) {
    try {
      const ref = db.collection('users').doc(uid).collection('in_app_notifications');
      const doc = {
        title: payload.title || '',
        body: payload.body || '',
        route: payload.route || '/home',
        imageUrl: payload.imageUrl || '',
        type: payload.type || 'campaign',
        campaignId: payload.campaignId || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
        readAt: null,
      };
      await ref.add(doc);
      return true;
    } catch (e) {
      logger.error('createInAppForUser failed', { uid, error: String(e) });
      return false;
    }
  }
