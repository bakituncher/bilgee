const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const { db, admin, messaging } = require("./init");
const { dayKeyIstanbul } = require("./utils");
const { processAudienceInBatches } = require("./users");

// ---- 1. GENİŞLETİLMİŞ GENEL MOTİVASYON VE ETKİLEŞİM HAVUZU ----
// Görsel yok, sadece vurucu metinler.
const GENERAL_MESSAGES = [
  // 🟢 Motivasyon & Başlangıç
  { title: 'Bugün senin günün! 🌟', body: 'Dünü geride bırak. Bugün atacağın tek bir adım bile seni zirveye yaklaştırır.', route: '/home' },
  { title: 'Hayallerin beklemez 🚀', body: 'Şu an masaya oturanlar kazanıyor. Sen neredesin?', route: '/home' },
  { title: 'Yüzde 1 Kuralı 📈', body: 'Her gün sadece %1 daha iyi olsan, yıl sonunda 37 kat daha iyi olursun. Hadi başla!', route: '/home' },
  { title: 'Mazeret yok! 💪', body: 'Zorlandığın an, geliştiğin andır. Pes etme, devam et.', route: '/home' },
  { title: 'Gelecekteki Sen Mesaj Attı 📩', body: '"Bugün çalıştığın için teşekkür ederim." demek istiyor. Onu mahcup etme.', route: '/home' },
  { title: 'Sadece 15 Dakika ⏱️', body: 'Gözünde büyütme. Sadece 15 dakika odaklan, gerisi kendiliğinden gelecek.', route: '/home' },

  // 🔵 Rekabet & Arena
  { title: 'Rakiplerin çalışıyor 👀', body: 'Sen dinlenirken sıralamada birileri seni geçiyor olabilir. Arena\'ya dön!', route: '/arena' },
  { title: 'Meydan okuma zamanı ⚔️', body: 'Bugün kimseyi yendin mi? Liderlik tablosunda yükselmek için şimdi tam zamanı.', route: '/arena' },
  { title: 'Sıralama değişti! 📉', body: 'Yerini korumak istiyorsan harekete geçmelisin. Sıralamaya göz at.', route: '/arena' },
  { title: 'Kürsüde yerin boş 🏆', body: 'İlk 3\'e girmek senin elinde. Bir test çöz ve puanları topla.', route: '/arena' },

  // 🟠 Taktik & Eksik Kapama
  { title: 'Zayıf halkanı bul 💎', body: 'Seni en çok zorlayan konu aslında en çok net getirecek konudur. Cevher Atölyesi\'ne bak.', route: '/ai-hub' },
  { title: 'Netlerin neden artmıyor? 🤔', body: 'Belki de yanlış yere odaklanıyorsun. Yapay zeka analizine göz at.', route: '/home/stats' },
  { title: 'Taktik Tavşan fısıldıyor... 🐰', body: '"Çok çalışmak yetmez, akıllı çalışmalısın." Stratejini kontrol et.', route: '/ai-hub' },
  { title: 'Deneme Analizi Yaptın mı? 📊', body: 'Çözdüğün denemeyi sisteme gir, eksiklerini nokta atışı belirleyelim.', route: '/home/add-test' },

  // 🟣 Odaklanma & Planlama
  { title: 'Domates tekniği? 🍅', body: '25 dakika odaklan, 5 dakika dinlen. Pomodoro sayacını senin için hazırladık.', route: '/home/pomodoro' },
  { title: 'Haftalık hedefin tehlikede ⚠️', body: 'Programının gerisinde kalma. Toparlamak için harika bir akşam.', route: '/ai-hub' },
  { title: 'Yatmadan önce son bir tekrar 🌙', body: 'Uyumadan önce çözülen 10 soru, sabah akılda kalan 10 bilgidir.', route: '/home/add-test' },
  { title: 'Telefonu bırak, teste başla 📵', body: 'Bu bildirimden sonra yapacağın en iyi şey uygulamaya girmek.', route: '/home' }
];

// ---- 2. YÜKSEK DÖNÜŞÜMLÜ PREMIUM SATIŞ MESAJLARI (Stratejik & Zeki Tüccar) ----
// Pazar, Çarşamba, Cuma 22:00'de sadece Premium olmayanlara gidecek.
// DÜZELTME: route: '/premium' olarak güncellendi.
const PREMIUM_SALES_MESSAGES = [
  // 💎 Kanca: CEVHER ATÖLYESİ & DEĞER (Uygulamanın kalbi burası)
  {
    title: 'Taktik Tavşan ile tanış, planını kap, istersen iptal et 🏃',
    body: '7 Günlük Bedava Taktik Pro hakkınla tüm eksiklerini analiz ettir, haftalık planını hazırlat. Beğenmezsen iptal et.',
    route: '/premium'
  },
  {
    title: 'Sırrımız bu analizlerde saklı 🤫',
    body: 'Herkes körü körüne çalışırken, biz senin "gizli desenini" çözdük. Taktik Tavşan koçluğunu aç, hangi konuya yüklenmen gerektiğini şıp diye söyleyeyim. 🐰',
    route: '/premium'
  },

  // 🌸 Kanca: PLANLAMA & KONFOR (Bestie desteği: "Sen yorulma ben yaparım")
  {
    title: 'Plan yapmakla yorulma dostum 📅',
    body: 'Sen kahveni iç, dersine odaklan; en verimli haftalık planını ben saniyeler içinde hazırlayayım. Enerjini sadece başarmaya sakla, gerisi bende! ☕',
    route: '/premium'
  },
  {
    title: 'Bırak yükünü hafifleteyim ✨',
    body: 'Sınav maratonu zaten zor, bir de planlama ile uğraşma. Pro\'a geç, kişisel koçun olarak rotanı ben çizeyim. Sen sadece gaza bas! 🚀',
    route: '/premium'
  },

  // 🚀 Kanca: POTANSİYEL & İNANÇ (Saygılı ve Motive Edici Baskı)
  {
    title: 'Sende o ışığı görüyorum! 🌟',
    body: 'Potansiyelin o kadar yüksek ki, harcanmasına gönlüm razı değil. Gel şu işi profesyonelce yapalım, hak ettiğin o yere ismini yazdıralım. Hadi!',
    route: '/premium'
  },
  {
    title: 'Kendine bu iyiliği yapmalısın 💖',
    body: 'Geleceğin için attığın her adım kıymetli. Küçük bir yatırımla sınırsız Taktik Tavşan desteğini yanına al. Beraber çok daha güçlü olacağız.',
    route: '/premium'
  },

  // 🐰 Kanca: TAKTİK TAVŞAN & AİDİYET (Marka Yüzüyle Bağ Kurma)
  {
    title: 'Taktik Tavşan yanında! 🐰',
    body: 'Sadece bir uygulama değil, sınav yolculuğundaki en sadık yol arkadaşınım. Premium ile tüm güçlerimi senin için açıyorum. Bu takımı bozmayalım! 💪',
    route: '/premium'
  },
  {
    title: 'Zirve sana çok yakışacak 👑',
    body: 'Arena\'da rakiplerin hızlanırken biz de vites artıralım. Gelişmiş analiz raporlarını aç, farkını ortaya koy. Şampiyonlar ligine hoş geldin!',
    route: '/premium'
  }
];

// ---- FCM TOKEN KAYDI (Aynen Korundu) ----
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

    const ref = db.collection('users').doc(uid).collection('devices').doc(deviceId);
    await ref.set({
      uid, token, platform, lang, disabled: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(appVersion ? { appVersion } : {}),
      ...(Number.isFinite(appBuild) ? { appBuild } : {}),
    }, {merge: true});

    try { await messaging.subscribeToTopic(token, 'general'); } catch (e) { logger.warn('Topic sub failed', {e}); }
    return {ok: true};
});

// ---- FCM TOKEN SİLME (Aynen Korundu) ----
exports.unregisterFcmToken = onCall({region: 'us-central1'}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
  const uid = request.auth.uid;
  const token = String(request.data?.token || '');
  if (!token) throw new HttpsError('invalid-argument', 'Token gerekli');
  try {
    const devicesRef = db.collection('users').doc(uid).collection('devices');
    const snapshot = await devicesRef.where('token', '==', token).get();
    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.update(doc.ref, { disabled: true, unregisteredAt: admin.firestore.FieldValue.serverTimestamp() }));
    if (!snapshot.empty) await batch.commit();
    try { await messaging.unsubscribeFromTopic(token, 'general'); } catch (e) {}
    return { ok: true };
  } catch (error) { throw new HttpsError('internal', 'Hata'); }
});

// ---- YARDIMCI FONKSİYONLAR ----

function getRandomItem(array) {
  return array[Math.floor(Math.random() * array.length)];
}

async function sendTopicNotification(topic = 'general') {
  const payload = getRandomItem(GENERAL_MESSAGES);
  logger.info('Sending generic topic push', { topic, title: payload.title });

  const message = {
    topic: topic,
    notification: { title: payload.title, body: payload.body },
    data: { route: payload.route || '/home', type: 'daily_motivation', click_action: 'FLUTTER_NOTIFICATION_CLICK' },
    android: { priority: 'high', notification: { channelId: 'bilge_general' } },
    apns: { payload: { aps: { sound: 'default', 'mutable-content': 1 } } }
  };

  try {
    await messaging.send(message);
    return { success: true };
  } catch (error) {
    logger.error('Topic send error', { error });
    return { success: false };
  }
}

// ---- ZAMANLANMIŞ GENEL BİLDİRİMLER (SIFIR MALİYET - HERKESE) ----

exports.dispatchInactivityMorning = onSchedule({schedule: "0 9 * * *", timeZone: 'Europe/Istanbul'}, async () => {
  await sendTopicNotification('general');
});

exports.dispatchInactivityAfternoon = onSchedule({schedule: "0 15 * * *", timeZone: 'Europe/Istanbul'}, async () => {
  await sendTopicNotification('general');
});

exports.dispatchInactivityEvening = onSchedule({schedule: "30 20 * * *", timeZone: 'Europe/Istanbul'}, async () => {
  await sendTopicNotification('general');
});

// ====================================================================================
// 🔥 YENİ: PREMIUM SATIŞ ODAKLI BİLDİRİM SİSTEMİ (PAZAR, ÇARŞAMBA, CUMA 22:00) 🔥
// (Sadece Premium Olmayanlara, Görselsiz, Yüksek Dönüşümlü)
// ====================================================================================

exports.dispatchPremiumSalesPush = onSchedule({
  schedule: "0 22 * * 0,3,5", // 0:Pazar, 3:Çarşamba, 5:Cuma | Saat 22:00
  timeZone: "Europe/Istanbul",
  timeoutSeconds: 540,
  memory: "1GiB"
}, async (event) => {
  logger.info('💰 Premium Sales Push Started');

  // 1. Rastgele agresif bir satış mesajı seç
  const payload = getRandomItem(PREMIUM_SALES_MESSAGES);

  // 2. Mesajı hazırla (Görsel yok, text only)
  const baseMessage = {
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: {
      route: payload.route,
      type: 'premium_offer',
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      priority: 'high',
      notification: { channelId: 'bilge_general', clickAction: 'FLUTTER_NOTIFICATION_CLICK' }
    },
    apns: {
      payload: { aps: { sound: 'default', 'mutable-content': 1 } }
    }
  };

  // 3. Premium OLMAYAN kullanıcıları bul ve gönder
  let totalSent = 0;
  let totalChecked = 0;

  // processAudienceInBatches: Büyük kitleleri 500'lü gruplar halinde işler
  await processAudienceInBatches({ type: "all" }, async (uidBatch) => {
    if (uidBatch.length === 0) return;

    // Batch'teki kullanıcı verilerini çek (isPremium kontrolü için)
    // Firestore'dan verimli okuma (getAll)
    const refs = uidBatch.map(uid => db.collection('users').doc(uid));
    const snapshots = await db.getAll(...refs);

    // Sadece Premium OLMAYANLARI filtrele
    const nonPremiumUids = snapshots
      .filter(doc => {
        const d = doc.data() || {};
        // Premium değilse listeye al
        return d.isPremium !== true;
      })
      .map(doc => doc.id);

    totalChecked += snapshots.length;
    if (nonPremiumUids.length === 0) return;

    // Bu kullanıcıların tokenlarını al
    const allTokens = [];
    // Promise.all ile paralel çekim
    const tokenPromises = nonPremiumUids.map(uid => getActiveTokensFiltered(uid, {}));
    const tokenResults = await Promise.all(tokenPromises);

    tokenResults.forEach(tokens => {
      if(tokens && tokens.length > 0) allTokens.push(...tokens);
    });

    // Tekrar eden tokenları temizle
    const uniqueTokens = [...new Set(allTokens)];

    // Gönderim yap
    if (uniqueTokens.length > 0) {
      const result = await sendPushToTokens(uniqueTokens, baseMessage);
      totalSent += result.successCount;
    }
  });

  logger.info('💰 Premium Sales Push Completed', { totalChecked, totalSent, message: payload.title });
});


// ---- YARDIMCI GÖNDERİM FONKSİYONLARI ----

async function getActiveTokensFiltered(uid, filters = {}) {
  try {
    const platforms = Array.isArray(filters.platforms) ? filters.platforms.map(s => s.toLowerCase()) : [];
    let q = db.collection('users').doc(uid).collection('devices').where('disabled','==', false);
    if (platforms.length > 0) q = q.where('platform','in', platforms);
    // Limit performans için 5'e çekildi
    const snap = await q.limit(5).get();
    if (snap.empty) return [];
    return snap.docs.map(d => d.data().token).filter(Boolean);
  } catch (e) { return []; }
}

async function sendPushToTokens(tokens, payload) {
  if (!tokens || tokens.length === 0) return {successCount: 0, failureCount: 0};
  const uniq = Array.from(new Set(tokens.filter(Boolean)));
  const BATCH_LIMIT = 500;
  let totalSuccess = 0;
  let totalFailure = 0;

  for (let i = 0; i < uniq.length; i += BATCH_LIMIT) {
    const batchTokens = uniq.slice(i, i + BATCH_LIMIT);

    // Payload zaten hazırsa (otomatik sistemden geliyorsa)
    let message = {
      ...payload,
      tokens: batchTokens,
    };

    // Admin panelinden veya eski sistemden geliyorsa (Notification objesi yoksa oluştur)
    if(!message.notification) {
       message.notification = { title: payload.title, body: payload.body };
       message.data = { route: payload.route || '/home', click_action: 'FLUTTER_NOTIFICATION_CLICK' };

       // SADECE Admin panelinden görsel gönderilirse ekle (Otomatikte yok)
       if(payload.imageUrl) {
         message.notification.imageUrl = payload.imageUrl;
         message.data.imageUrl = payload.imageUrl;

         // Android/iOS özel alanlarına da ekle
         if(!message.android) message.android = { notification: {} };
         message.android.notification.imageUrl = payload.imageUrl;

         if(!message.apns) message.apns = { fcmOptions: {} };
         message.apns.fcmOptions = { imageUrl: payload.imageUrl };
       }
    }

    try {
      const resp = await messaging.sendEachForMulticast(message);
      totalSuccess += resp.successCount;
      totalFailure += resp.failureCount;
    } catch (e) {
      totalFailure += batchTokens.length;
    }
  }
  return {successCount: totalSuccess, failureCount: totalFailure};
}

// ---- ADMIN FONKSİYONLARI (Aynen Korundu - Geriye Dönük Uyumluluk) ----

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
        return;
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
    const onlyNonPremium = request.data?.onlyNonPremium === true;

    if (!title || !body) throw new HttpsError("invalid-argument", "title ve body zorunludur");

    const hasFilters = (Array.isArray(audience.platforms) && audience.platforms.length > 0) ||
                       Number.isFinite(audience.buildMin) ||
                       Number.isFinite(audience.buildMax) ||
                       onlyNonPremium;

    // GLOBAL KAMPANYA (Pull Modeli)
    if (audience.type === 'all' && !hasFilters) {
        let globalCampaignRef = null;
        let pushResult = { successCount: 0, failureCount: 0 };
        if (sendType === 'inapp' || sendType === 'both') {
            const expiryDays = request.data?.expiryDays || 7;
            const expiresAt = admin.firestore.Timestamp.fromDate(
              new Date(Date.now() + expiryDays * 24 * 60 * 60 * 1000)
            );
            globalCampaignRef = db.collection('global_campaigns').doc();
            await globalCampaignRef.set({
                title, body, imageUrl, route,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                createdBy: request.auth.uid,
                isActive: true,
                expiresAt,
                type: 'global_announcement',
                priority: request.data?.priority || 'normal',
            });
        }
        if (sendType === 'push' || sendType === 'both') {
            const message = {
                topic: 'general',
                notification: { title, body, ...(imageUrl ? { imageUrl } : {}) },
                data: {
                    route, campaignId: globalCampaignRef?.id || 'topic_only',
                    type: 'global_campaign', click_action: 'FLUTTER_NOTIFICATION_CLICK'
                },
                android: {
                  priority: 'high',
                  notification: { channelId: 'bilge_general', clickAction: 'FLUTTER_NOTIFICATION_CLICK', ...(imageUrl ? { imageUrl } : {}) }
                },
                apns: {
                  payload: { aps: { sound: 'default', 'mutable-content': 1 } },
                  ...(imageUrl ? { fcmOptions: { imageUrl } } : {})
                }
            };
            try {
              const response = await messaging.send(message);
              pushResult.successCount = 1;
            } catch(e) { pushResult.failureCount = 1; }
        }
        if (globalCampaignRef) {
            await globalCampaignRef.update({
              status: 'active',
              pushSent: sendType === 'push' || sendType === 'both',
              pushSuccess: pushResult.successCount > 0,
              method: 'global_broadcast'
            });
        }
        return { ok: true, method: 'topic_broadcast' };
    }

    // FİLTRELİ KAMPANYA (Eski Sistem)
    const campaignRef = db.collection("push_campaigns").doc();
    const baseDoc = {
      title, body, imageUrl, route, audience, onlyNonPremium,
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
      let targetUids = uidBatch;
      if (onlyNonPremium) {
        const refs = uidBatch.map(uid => db.collection('users').doc(uid));
        const snapshots = await db.getAll(...refs);
        targetUids = snapshots.filter(doc => (doc.data() || {}).isPremium !== true).map(doc => doc.id);
      }
      if (targetUids.length === 0) return;
      totalUsers += targetUids.length;

      if (sendType === "inapp" || sendType === "both") {
        const inAppPromises = targetUids.map((uid) =>
          createInAppForUser(uid, { title, body, imageUrl, route, type: "campaign", campaignId: campaignRef.id })
        );
        const results = await Promise.all(inAppPromises);
        totalInApp += results.filter(Boolean).length;
      }

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
          totalSent += result.successCount;
          totalFail += result.failureCount;
        }
      }
    });

    await campaignRef.set({
        status: "completed", totalUsers, totalSent, totalFail, totalInApp,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    return { ok: true, campaignId: campaignRef.id, totalUsers, totalSent, totalFail, totalInApp, method: 'filtered_batch' };
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
        const sendType = ["push", "inapp", "both"].includes(d.sendType) ? d.sendType : "push";
        const onlyNonPremium = d.onlyNonPremium === true;
        const filters = { buildMin: audience?.buildMin, buildMax: audience?.buildMax, platforms: audience?.platforms };
        let totalSent = 0, totalFail = 0, totalUsers = 0, totalInApp = 0;

        await processAudienceInBatches(audience, async (uidBatch) => {
          let targetUids = uidBatch;
          if (onlyNonPremium) {
            const refs = uidBatch.map(uid => db.collection('users').doc(uid));
            const snapshots = await db.getAll(...refs);
            targetUids = snapshots.filter(doc => (doc.data() || {}).isPremium !== true).map(doc => doc.id);
          }
          if (targetUids.length === 0) return;
          totalUsers += targetUids.length;

          for (const uid of targetUids) {
            if (sendType === "inapp" || sendType === "both") {
              const ok = await createInAppForUser(uid, { title, body, imageUrl, route, type: "campaign", campaignId: doc.id });
              if (ok) totalInApp++;
            }
            if (sendType === "push" || sendType === "both") {
              const tokens = await getActiveTokensFiltered(uid, filters);
              if (tokens.length === 0) continue;
              const r = await sendPushToTokens(tokens, { title, body, imageUrl, route, type: "campaign", campaignId: doc.id });
              totalSent += r.successCount;
              totalFail += r.failureCount;
            }
          }
        });

        await doc.ref.set({ status: "completed", totalUsers, totalSent, totalFail, totalInApp, completedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      } catch (e) {
        await doc.ref.set({ status: "failed", error: String(e), failedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
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
    } catch (e) { return false; }
  }

  exports.cleanupExpiredGlobalCampaigns = onSchedule({
    schedule: "0 3 * * *",
    timeZone: "Europe/Istanbul"
  }, async () => {
    const now = admin.firestore.Timestamp.now();
    const expiredSnap = await db.collection('global_campaigns').where('isActive', '==', true).where('expiresAt', '<=', now).limit(50).get();
    if (expiredSnap.empty) return;
    const batch = db.batch();
    expiredSnap.docs.forEach(doc => {
      batch.update(doc.ref, { isActive: false, deactivatedAt: admin.firestore.FieldValue.serverTimestamp(), deactivationReason: 'expired' });
    });
    await batch.commit();
  });