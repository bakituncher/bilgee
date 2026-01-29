const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const { db, admin, messaging } = require("./init");
const { dayKeyIstanbul } = require("./utils");
const { processAudienceInBatches } = require("./users");

// ---- 1. GENİŞLETİLMİŞ GENEL MOTİVASYON VE ETKİLEŞİM HAVUZU ----
// Samimi, özellik odaklı ve aksiyona yönlendiren mesajlar.
const GENERAL_MESSAGES = [
  // 📸 SORU ÇÖZÜCÜ - Direkt /ai-hub/question-solver'a yönlendir (En yüksek oran)
  { title: 'Bi soru mu takıldı kafana? 📸', body: 'Fotoğrafını çek, anında çözümünü al. Tıpkı yanında öğretmen varmış gibi!', route: '/ai-hub/question-solver' },
  { title: 'O soruyu çözemeyince sinir oluyorsun, biliyorum 😤', body: 'Fotoğrafla, saniyeler içinde adım adım çözümünü gör. Dene bi kere!', route: '/ai-hub/question-solver' },
  { title: 'Çözemediğin soru korkun olmasın! 💪', body: 'Kamerayı aç, soruyu çek. Gerisini Taktik Tavşan halleder, söz.', route: '/ai-hub/question-solver' },
  { title: 'Matematikte mi takıldın? Türkçe\'de mi? 🤔', body: 'Fark etmez! Soru Çözücü her dersten anlıyor. Hemen dene!', route: '/ai-hub/question-solver' },
  { title: 'Yardım lazım mı? 🐰', body: 'Çözemediğin soruyu fotoğrafla, sana öğretmenden dinlemiş gibi anlatalım!', route: '/ai-hub/question-solver' },

  // 📚 ETÜT ODASI - Direkt /ai-hub/weakness-workshop'a yönlendir (Yüksek oran)
  { title: 'Hangi konuda zorlanıyorsun? 📚', body: 'Söyle, sana özel konu anlatımı ve sorular hazırlayayım!', route: '/ai-hub/weakness-workshop' },
  { title: 'Eksik konuların canını mı sıkıyor? 😩', body: 'Etüt Odası\'na gel, zayıf konularını güçlü yap. Sana özel çalışma seti hazır!', route: '/ai-hub/weakness-workshop' },
  { title: 'Konu çalışmak sıkıcı gelebilir ama... ✨', body: 'Etüt Odası ile bambaşka! Sana özel anlatım, sana özel sorular. Gel dene!', route: '/ai-hub/weakness-workshop' },
  { title: 'Zayıf konun ne, söyle bakalım 🎯', body: 'O konuyu beraber çözeriz. Etüt Odası seni bekliyor, hadi!', route: '/ai-hub/weakness-workshop' },

  // 📅 HAFTALIK PLAN YAPICI - Direkt /ai-hub/strategic-planning'e yönlendir (Orta-yüksek oran)
  { title: 'Bu hafta ne çalışacağını biliyor musun? 📅', body: 'Bilmiyorsan sorun değil! Sana özel haftalık plan oluşturalım.', route: '/ai-hub/strategic-planning' },
  { title: 'Rastgele çalışmaya son! 🎯', body: 'Boş zamanlarına ve eksiklerine göre kişisel haftalık plan hazırlayalım.', route: '/ai-hub/strategic-planning' },
  { title: 'Plan yapmak zor geliyor mu? 🤯', body: 'Merak etme, ben yaparım! Müsait saatlerini söyle, programın hazır.', route: '/ai-hub/strategic-planning' },
  { title: 'Neyi, ne zaman çalışacağını ben söyleyeyim 📋', body: 'Haftalık Plan Yapıcı ile verimli çalış, boşa zaman harcama!', route: '/ai-hub/strategic-planning' },

  // 📊 VERİ GİRİŞİ TEŞVİKİ - Deneme Ekleme
  { title: 'Bugün deneme mi çözdün? 📝', body: 'Hemen kaydet! Analiz etmeden geçen deneme, boşa giden emek demek.', route: '/home/add-test' },
  { title: 'Son denemenin sonucunu girdin mi? 👀', body: 'Girmezsen gelişimini takip edemeyiz! Hadi, çok kolay.', route: '/home/add-test' },
  { title: 'Her deneme kaydı = Daha iyi analiz 📈', body: 'Çözdüğün son denemeyi sisteme ekle, zayıf noktaları bulalım!', route: '/home/add-test' },
  { title: 'Kayıt tutmak şampiyonların işi 🏆', body: 'Deneme sonucunu gir, eksiklerini beraber bulalım!', route: '/home/add-test' },

  // 📈 GELİŞİM GRAFİKLERİ - İstatistikler & Genel Bakış
  { title: 'Net grafiğine göz attın mı? 📊', body: 'Son 1 ayda ne kadar yol aldığını gör! Motivasyon garantili.', route: '/home/stats' },
  { title: 'Yükseliştesin, biliyor musun? 🚀', body: 'Grafiklerini incele, hangi derste patlama yaptığını gör!', route: '/home/stats' },
  { title: 'Nereden nereye geldiğini görmek ister misin? 📏', body: 'Deneme gelişim grafiğin hazır. Kendini motive et!', route: '/home/stats' },
  { title: 'Performansının röntgenini çekelim 🔍', body: 'Tüm istatistiklerini tek ekranda gör, stratejini belirle!', route: '/stats/overview' },
  { title: 'Hangi ders yükseliyor, hangisi düşüyor? 📉', body: 'Genel bakış ekranında trend analizini incele!', route: '/stats/overview' },

  // 🗂️ DENEME ARŞİVİ
  { title: 'Eski denemelerine bi göz at 🗂️', body: 'Aynı hataları tekrarlıyor musun? Deneme arşivinde cevap var!', route: '/library' },
  { title: 'Geçmiş denemelerin seni bekliyor 📂', body: 'Arşive dal, ilerleme yolculuğunu gör!', route: '/library' },

  // 📦 SORU KUTUSU
  { title: 'Zorlandığın soruları kaybetme! 📦', body: 'Soru kutusuna at, sonra toplu halde tekrar et. Çok işe yarıyor!', route: '/question-box' },
  { title: 'Soru kutun seni bekliyor 🎯', body: 'Çözemediğin soruları biriktir, sonra fethet!', route: '/question-box' },

  // 🍅 POMODORO - Odaklanma (Düşük oran - sadece 2 mesaj)
  { title: 'Sadece 25 dakika, söz! 🍅', body: 'Bir pomodoro aç, odaklan. Mola zamanı gelince haber veririm!', route: '/home/pomodoro' },
  { title: 'Telefonla savaşmak zor, biliyorum 📱', body: 'Pomodoro sayacını aç, 25 dakika sadece çalışmaya odaklan!', route: '/home/pomodoro' }
];

// ---- 2. YÜKSEK DÖNÜŞÜMLÜ PREMIUM SATIŞ MESAJLARI (Stratejik & Samimi) ----
// Pazar, Çarşamba, Cuma 22:00'de sadece Premium olmayanlara gidecek.
// AIHub özellikleri odaklı: Soru Çözücü, Etüt Odası, Haftalık Plan Yapıcı
const PREMIUM_SALES_MESSAGES = [
  // 📸 SORU ÇÖZÜCÜ - Fotoğraf çek, anında çözüm al
  {
    title: 'Takıldığın soru mu var? 📸',
    body: 'Fotoğrafını çek, saniyeler içinde adım adım çözümünü gör! Artık hiçbir soru çözümsüz kalmayacak.',
    route: '/ai-hub/question-solver'
  },
  {
    title: 'Özel öğretmenin artık cebinde! 👨‍🏫',
    body: 'Çözemediğin soruyu fotoğrafla, tıpkı öğretmen anlatır gibi adım adım çözümünü al.',
    route: '/ai-hub/question-solver'
  },
  {
    title: 'O zor soruyu bi çek bakalım 📷',
    body: 'Matematiğinden Türkçe\'sine, her sorunun çözümü saniyeler içinde elinde!',
    route: '/ai-hub/question-solver'
  },
  {
    title: 'Soru çözerken takıldın mı? 🤔',
    body: 'Fotoğrafla, yapay zeka sana adım adım anlatsın. Daha kolay öğrenmenin yolu bu!',
    route: '/ai-hub/question-solver'
  },

  // 📚 ETÜT ODASI - Zayıf konulara özel çalışma setleri
  {
    title: 'Eksik konuların için özel set hazırladım! 📚',
    body: 'Etüt Odası\'nda zayıf konularına özel konu anlatımı ve sorular seni bekliyor.',
    route: '/ai-hub/weakness-workshop'
  },
  {
    title: 'Zayıf konuları güçlü yap! 💪',
    body: 'Hangi konuda zorlanıyorsun? O konuyu kavrayana kadar sana özel içerik üretiyorum.',
    route: '/ai-hub/weakness-workshop'
  },
  {
    title: 'Konu çalışmak hiç bu kadar kolay olmadı ✨',
    body: 'Eksik konun ne? Söyle, sana özel anlatım ve pratik sorular hazırlayayım!',
    route: '/ai-hub/weakness-workshop'
  },
  {
    title: 'Konuyu anlamadıysan sorun değil 🎯',
    body: 'Etüt Odası\'na gel, sana farklı bir şekilde anlatayım. Bu sefer anlayacaksın!',
    route: '/ai-hub/weakness-workshop'
  },

  // 📅 HAFTALIK PLAN YAPICI - Kişiye özel program
  {
    title: 'Plan yapmakla uğraşma, ben yaparım! 📅',
    body: 'Boş zamanlarına ve eksik konularına göre sana özel haftalık program oluşturayım.',
    route: '/ai-hub/strategic-planning'
  },
  {
    title: 'Her hafta sana özel strateji 🎯',
    body: 'Ne zaman müsaitsin? Hangi konularda eksiksin? Söyle, en verimli planını çıkarayım!',
    route: '/ai-hub/strategic-planning'
  },
  {
    title: 'Rastgele değil, stratejik çalış! 🗓️',
    body: 'Taktik Tavşan senin için kişisel haftalık plan yapıyor. Verimsizliğe son!',
    route: '/ai-hub/strategic-planning'
  },

  // 🐰 TAKTİK PRO GENEL
  {
    title: 'Taktik Pro\'yu 7 gün bedava dene! 🐰',
    body: 'Soru Çözücü, Etüt Odası, Haftalık Plan... Hepsini dene, beğenmezsen iptal et!',
    route: '/premium'
  },
  {
    title: 'Akıllı çalışmanın sırrı burada 🔓',
    body: 'Yapay zeka destekli soru çözümü, konu analizi ve kişisel plan. Tüm araçlar emrinde!',
    route: '/premium'
  },
  {
    title: 'Bu yolda yalnız değilsin! 💪',
    body: 'Soru çözümünden haftalık plana, sınav koçun olarak hep yanındayım.',
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

// Tarihe göre sırayla bildirim seç (DB gerektirmez)
// Her gün + her slot farklı bildirim gönderir
function getRotatingItem(array, slotId = 0) {
  const today = new Date();
  const dayOfYear = Math.floor((today - new Date(today.getFullYear(), 0, 0)) / (1000 * 60 * 60 * 24));
  const index = (dayOfYear * 3 + slotId) % array.length;
  return array[index];
}

async function sendTopicNotification(topic = 'general', slotId = 0) {
  const payload = getRotatingItem(GENERAL_MESSAGES, slotId);
  logger.info('Sending topic push', { topic, title: payload.title, slot: slotId });

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
  await sendTopicNotification('general', 0); // Sabah slot
});

exports.dispatchInactivityAfternoon = onSchedule({schedule: "0 15 * * *", timeZone: 'Europe/Istanbul'}, async () => {
  await sendTopicNotification('general', 1); // Öğlen slot
});

exports.dispatchInactivityEvening = onSchedule({schedule: "30 20 * * *", timeZone: 'Europe/Istanbul'}, async () => {
  await sendTopicNotification('general', 2); // Akşam slot
});

// ====================================================================================
// 🔥 YENİ: PREMIUM SATIŞ ODAKLI BİLDİRİM SİSTEMİ (PAZAR, ÇARŞAMBA, CUMA 22:00) 🔥
// (Sadece Premium Olmayanlara, Görselsiz, Yüksek Dönüşümlü)
// ====================================================================================

exports.dispatchPremiumSalesPush = onSchedule({
  schedule: "0 22 * * 0,3,5",
  timeZone: "Europe/Istanbul",
  timeoutSeconds: 540,
  memory: "1GiB"
}, async (event) => {
  logger.info('💰 Premium Sales Push Started');

  // Basit rastgele seçim - premium için karmaşık sistem gereksiz
  const payload = PREMIUM_SALES_MESSAGES[Math.floor(Math.random() * PREMIUM_SALES_MESSAGES.length)];

  logger.info('Premium bildirim seçildi', { title: payload.title });

  const baseMessage = {
    notification: { title: payload.title, body: payload.body },
    data: { route: payload.route, type: 'premium_offer', click_action: 'FLUTTER_NOTIFICATION_CLICK' },
    android: { priority: 'high', notification: { channelId: 'bilge_general', clickAction: 'FLUTTER_NOTIFICATION_CLICK' } },
    apns: { payload: { aps: { sound: 'default', 'mutable-content': 1 } } }
  };

  let totalSent = 0;

  // 🔥 TEK DEĞİŞİKLİK BURADA: type: "non_premium" gönderiyoruz
  // users.js bizim için filtreliyor. Ekstra DB sorgusu yok!
  await processAudienceInBatches({ type: "non_premium" }, async (uidBatch) => {
    if (uidBatch.length === 0) return;

    // Doğrudan tokenları çek (Premium kontrolü zaten yapıldı)
    const tokenPromises = uidBatch.map(uid => getActiveTokensFiltered(uid, {}));
    const tokenResults = await Promise.all(tokenPromises);

    const allTokens = [];
    tokenResults.forEach(tokens => {
      if (tokens && tokens.length > 0) allTokens.push(...tokens);
    });

    const uniqueTokens = [...new Set(allTokens)];

    if (uniqueTokens.length > 0) {
      const result = await sendPushToTokens(uniqueTokens, baseMessage);
      totalSent += result.successCount;
    }
  });

  logger.info('💰 Premium Sales Push Completed', { totalSent, message: payload.title });
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

    // 🔥 DÜZELTME: onlyNonPremium bilgisini audience içine gömüyoruz.
    // users.js bunu görüp otomatik filtreleyecek.
    const effectiveAudience = { ...audience, onlyNonPremium: onlyNonPremium };

    await processAudienceInBatches(effectiveAudience, async (uidBatch) => {
      // Artık uidBatch bize zaten filtreli geliyor.
      const targetUids = uidBatch;
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

        // 🔥 DÜZELTME: onlyNonPremium'u audience'a ekle
        const effectiveAudience = { ...(audience || {}), onlyNonPremium: onlyNonPremium };

        const filters = { buildMin: audience?.buildMin, buildMax: audience?.buildMax, platforms: audience?.platforms };
        let totalSent = 0, totalFail = 0, totalUsers = 0, totalInApp = 0;

        await processAudienceInBatches(effectiveAudience, async (uidBatch) => {
          const targetUids = uidBatch;
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
