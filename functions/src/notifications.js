const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const { db, admin, messaging } = require("./init");
const { dayKeyIstanbul } = require("./utils");
const { computeInactivityHours, selectAudienceUids } = require("./users");

// ---- FCM TOKEN KAYDI ----
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
      uid,
      token,
      platform,
      lang,
      disabled: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(appVersion ? { appVersion } : {}),
      ...(Number.isFinite(appBuild) ? { appBuild } : {}),
    }, {merge: true});
    return {ok: true};
  });

// ---- FCM TOKEN TEMİZLEME ----
exports.unregisterFcmToken = onCall({region: 'us-central1'}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
  const uid = request.auth.uid;
  const token = String(request.data?.token || '');
  if (!token || token.length < 10) throw new HttpsError('invalid-argument', 'Geçerli token gerekli');

  try {
    // Token'a sahip tüm cihaz kayıtlarını bul ve devre dışı bırak
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
      logger.info('FCM token unregistered', { uid, tokenLength: token.length, devicesUpdated: snapshot.size });
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
      // Firestore'da sadece basit filtre: disabled ve (opsiyonel) platform in
      let q = db.collection('users').doc(uid).collection('devices').where('disabled','==', false);
      if (platforms.length > 0 && platforms.length <= 10) q = q.where('platform','in', platforms);

      // Limit makul bir değerde tutulur; kullanıcı başına çok az cihaz vardır.
      const snap = await q.limit(200).get();
      if (snap.empty) return [];

      const buildMin = Number.isFinite(filters.buildMin) ? Number(filters.buildMin) : null;
      const buildMax = Number.isFinite(filters.buildMax) ? Number(filters.buildMax) : null;

      const list = [];
      for (const d of snap.docs) {
        const it = d.data() || {};
        const build = typeof it.appBuild === 'number' ? it.appBuild : (typeof it.appBuild === 'string' ? Number(it.appBuild) : null);
        // Build filtrelerini bellek içinde uygula; alan yoksa 0 varsayalım
        const b = Number.isFinite(build) ? Number(build) : 0;
        if (buildMin !== null && !(b >= buildMin)) continue;
        if (buildMax !== null && !(b <= buildMax)) continue;
        if (it.token) list.push(it.token);
      }
      return Array.from(new Set(list));
    } catch (e) {
      // Aşırı durumlarda güvenli geri dönüş
      logger.error('getActiveTokensFiltered failed, fallback to unfiltered', { error: String(e) });
      const all = await db.collection('users').doc(uid).collection('devices').where('disabled','==', false).limit(200).get();
      if (all.empty) return [];
      const buildMin = Number.isFinite(filters.buildMin) ? Number(filters.buildMin) : null;
      const buildMax = Number.isFinite(filters.buildMax) ? Number(filters.buildMax) : null;
      const platforms = Array.isArray(filters.platforms) ? filters.platforms.filter((x)=> typeof x === 'string' && x).map((s)=> s.toLowerCase()) : [];
      const list = [];
      for (const d of all.docs) {
        const it = d.data() || {};
        if (platforms.length > 0 && !platforms.includes(String(it.platform || '').toLowerCase())) continue;
        const build = typeof it.appBuild === 'number' ? it.appBuild : (typeof it.appBuild === 'string' ? Number(it.appBuild) : null);
        const b = Number.isFinite(build) ? Number(build) : 0;
        if (buildMin !== null && !(b >= buildMin)) continue;
        if (buildMax !== null && !(b <= buildMax)) continue;
        if (it.token) list.push(it.token);
      }
      return Array.from(new Set(list));
    }
  }

  async function canSendMoreToday(uid, maxPerDay = 3) {
    const countersRef = db.collection('users').doc(uid).collection('state').doc('notification_counters');
    let allowed = false;
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(countersRef);
      const today = dayKeyIstanbul();
      if (!snap.exists) {
        // İlk kez: bu çağrıda bir gönderim yapılacağından sent=1
        tx.set(countersRef, {day: today, sent: 1, updatedAt: admin.firestore.FieldValue.serverTimestamp()});
        allowed = true;
        return;
      }
      const d = snap.data() || {};
      let sent = Number(d.sent || 0);
      let day = String(d.day || '');
      if (day !== today) { day = today; sent = 0; }
      if (sent < maxPerDay) {
        tx.set(countersRef, {day, sent: sent + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
        allowed = true;
      } else {
        allowed = false;
      }
    });
    return allowed;
  }

  // Sınav adını formatla (büyük harf)
  function formatExamName(examType) {
    if (!examType) return null;
    return String(examType).toUpperCase();
  }

  // Çeşitli bildirim şablonları - samimi ve gençlere hitap eden
  function buildInactivityTemplate(inactHours, examType) {
    const exam = formatExamName(examType);

    // 72+ saat (3+ gün) - Uzun süre inaktif
    if (inactHours >= 72) {
      const templates = [
        {
          title: 'Özledin mi? Biz seni çok özledik! 💙',
          body: exam ? `${exam} yolculuğunda 3 gün ara verdin. Küçük bir adımla geri dön, momentum kaybetme!` : 'Uzun bir mola verdin. Bugün sadece 10 dakika ayır, rutin yeniden gelsin! 🔥',
          route: '/home/quests',
        },
        {
          title: 'Hadi dostum, bu kadar ara fazla! 😅',
          body: exam ? `${exam} hedefin için her gün değerli. Kaldığın yerden devam et, 1 küçük görevle başla!` : 'Uzun süredir görüşemedik. Bugün bir deneme gir veya mini bir görev tamamla! 💪',
          route: '/home/add-test',
        },
        {
          title: 'Streak\'in tehlikede! ⚠️',
          body: exam ? `${exam} için çalışma serisini kaybetme. Şimdi geri dön, bir günlük görevini tamamla!` : 'Günlük çalışma alışkanlığın kopmak üzere. Hemen 15 dakikalık bir Pomodoro ile başla! ⏱️',
          route: '/home/pomodoro',
        },
        {
          title: 'Geri gelme zamanı! 🚀',
          body: exam ? `${exam} rotanda 3 gün duraksadın. Bugün yeniden gaza bas, TaktikAI koçun seni bekliyor!` : 'Uzun aradan sonra en iyi açılış: kısa bir görevle başla, ritmi yakala! 🎯',
          route: '/ai-hub',
        },
        {
          title: 'Hedefinden uzaklaşma! 🎯',
          body: exam ? `${exam} için her gün önemli. 3 günlük aradan sonra bugün küçük bir zaferle dön!` : 'Başarı düzenli çalışmadan gelir. Bugün sadece 1 görevle ritme geri dön! 💫',
          route: '/home/quests',
        },
      ];
      return templates[Math.floor(Math.random() * templates.length)];
    }

    // 24-72 saat arası (1-3 gün)
    if (inactHours >= 24) {
      const templates = [
        {
          title: 'Bir gün ara verdin, şimdi gaza gel! ⚡',
          body: exam ? `${exam} planında bugün yeni bir sayfa aç. Kısa bir deneme veya görevle hızlan!` : 'Dünü geride bırak, bugün en az 1 görev tamamla. Momentum sende! 🔥',
          route: '/home/quests',
        },
        {
          title: 'Bugün senin günün! 🌟',
          body: exam ? `${exam} yolculuğunda 1 gün boşluk oluştu. Şimdi test gir veya zayıf konunu çalış!` : 'Dün yok, yarın yok. Sadece bugün var. 15 dakikalık odakla başla! 💪',
          route: '/home/add-test',
        },
        {
          title: 'Koçun seni çağırıyor! 🎓',
          body: exam ? `${exam} için TaktikAI koçunla stratejini güncelle. 1 günlük ara yeter, devam et!` : 'Yeni bir strateji mi lazım? Koçunla konuş, planını tazele! 🗣️',
          route: '/ai-hub',
        },
        {
          title: 'Streak kırılmasın! 🔥',
          body: exam ? `${exam} serini korumak için bugün küçük bir görev yeter. Hadi başla!` : 'Günlük çalışma alışkanlığını kaybetme. Şimdi 1 Pomodoro seansı yap! ⏱️',
          route: '/home/pomodoro',
        },
        {
          title: 'Motivasyon düştü mü? 💬',
          body: exam ? `${exam} yolunda bazen mola gerekir ama çok uzatma. Koçunla konuş, moralini topla!` : 'Sıkıldın mı? AI koçunla sohbet et, yeni bir bakış açısı kazan! 🌈',
          route: '/ai-hub/motivation',
        },
        {
          title: 'Rakiplerin çalışıyor! 👀',
          body: exam ? `${exam} için Arena'da liderlik yarışı kızışıyor. Sen de bugün katıl, sıralamaya gir!` : 'Zafer Panteonu\'nda yeni rekorlar kırılıyor. Sen neredesin? 🏆',
          route: '/arena',
        },
      ];
      return templates[Math.floor(Math.random() * templates.length)];
    }

    // 3-24 saat arası - Hafif hatırlatma
    if (inactHours >= 3) {
      const templates = [
        {
          title: 'Kısa bir mola verdik, devam edelim! 😊',
          body: exam ? `${exam} için bugün ne yapmıştık? Hadi küçük bir görevle devam et!` : 'Birkaç saattir görüşemedik. 15 dakikalık mini bir çalışma ile açılış yap! ☕',
          route: '/home/quests',
        },
        {
          title: 'Pomodoro zamanı! 🍅',
          body: exam ? `${exam} planında bugün 1 Pomodoro seansı kaldı. Sadece 25 dakika, hadi başla!` : 'Odaklanma vakti! 25 dakikalık bir Pomodoro ile zihnini açacaksın. 🧠',
          route: '/home/pomodoro',
        },
        {
          title: 'Günlük görevlerin bekliyor! 📋',
          body: exam ? `${exam} için bugünkü görevlerini kontrol ettin mi? Hepsini tamamla, XP kazan!` : 'Görev listene bak, kolaylardan başla. Her tamamlanan görev bir adım! 🎯',
          route: '/home/quests',
        },
        {
          title: 'Zayıf konunu yok et! 💎',
          body: exam ? `${exam} konularında Cevher Atölyesi seni bekliyor. En zor konuyu seç, öğren!` : 'Bugün hangi konuyu ustalık seviyesine çıkaracaksın? Atölyeye gel! ⚒️',
          route: '/ai-hub/weakness-workshop',
        },
        {
          title: 'Haftalık planını kontrol et! 📅',
          body: exam ? `${exam} için bu haftaki stratejine baktın mı? Bugün ne çalışmalısın?` : 'Haftalık planında bugün hangi konular var? Planını takip et, başarı gelsin! 🗓️',
          route: '/home/weekly-plan',
        },
        {
          title: 'Test gir, netlerini yükselt! 📊',
          body: exam ? `${exam} için bugün deneme girdin mi? Test sonuçlarını takip et, eksiklerini gör!` : 'Yeni bir deneme sonucunu kaydet, istatistiklerini incele, ilerlemeyi gör! 📈',
          route: '/home/add-test',
        },
        {
          title: 'Koçunla sohbet et! 💭',
          body: exam ? `${exam} stratejini koçunla konuş. Yeni bir bakış açısı edinmek ister misin?` : 'Takıldığın bir konu mu var? AI koçuna sor, anında cevap al! 🤖',
          route: '/ai-hub',
        },
        {
          title: 'Mini motivasyon dozu! ✨',
          body: exam ? `${exam} yolculuğunda her küçük adım sayılır. Bugün ne yapacaksın?` : 'Bugün kendine bir görev ver ve onu tamamla. Küçük zaferler büyük başarı getirir! 🌟',
          route: '/home',
        },
      ];
      return templates[Math.floor(Math.random() * templates.length)];
    }

    return null;
  }

  async function sendPushToTokens(tokens, payload) {
    if (!tokens || tokens.length === 0) return {successCount: 0, failureCount: 0};
    const uniq = Array.from(new Set(tokens.filter(Boolean)));
    logger.info('sendPushToTokens', { tokenCount: uniq.length, hasImage: !!payload.imageUrl, type: payload.type || 'unknown' });
    const collapseId = payload.campaignId || (payload.route || 'bilge_general');
    const message = {
      notification: { title: payload.title, body: payload.body, ...(payload.imageUrl ? { imageUrl: payload.imageUrl } : {}) },
      data: { route: payload.route || '/home', campaignId: payload.campaignId || '', type: payload.type || 'inactivity', ...(payload.imageUrl ? { imageUrl: payload.imageUrl } : {}) },
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

  async function dispatchInactivityPushBatch(limitUsers = 500) {
    const usersSnap = await db.collection('users').limit(5000).get();
    let processed = 0, sent = 0;
    for (const doc of usersSnap.docs) {
      if (processed >= limitUsers) break;
      const uid = doc.id;
      const userRef = doc.ref;
      const inact = await computeInactivityHours(userRef);
      const examType = (doc.data()||{}).selectedExam || null;
      const tpl = buildInactivityTemplate(inact, examType);
      if (!tpl) { processed++; continue; }
      const allowed = await canSendMoreToday(uid, 3);
      if (!allowed) { processed++; continue; }
      const tokens = await getActiveTokens(uid);
      if (tokens.length === 0) { processed++; continue; }
      await sendPushToTokens(tokens, { ...tpl, type: 'inactivity' });
      sent++;
      processed++;
    }
    logger.info('dispatchInactivityPushBatch done', {processed, sent});
    return {processed, sent};
  }

  function scheduleSpecAt(hour, minute = 0) {
    return {schedule: `${minute} ${hour} * * *`, timeZone: 'Europe/Istanbul'};
  }

  // ---- ZAMANLANMIŞ BİLDİRİM FONKSİYONLARI ----
  exports.dispatchInactivityMorning = onSchedule(scheduleSpecAt(9, 0), async () => {
    logger.info('🌅 Morning inactivity push started');
    await dispatchInactivityPushBatch(1500);
  });

  exports.dispatchInactivityAfternoon = onSchedule(scheduleSpecAt(15, 0), async () => {
    logger.info('☀️ Afternoon inactivity push started');
    await dispatchInactivityPushBatch(1500);
  });

  exports.dispatchInactivityEvening = onSchedule(scheduleSpecAt(20, 30), async () => {
    logger.info('🌙 Evening inactivity push started');
    await dispatchInactivityPushBatch(1500);
  });

  // ---- ADMIN KAMPANYA SİSTEMİ ----
  exports.adminEstimateAudience = onCall({region: 'us-central1', timeoutSeconds: 300}, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
    const isAdmin = request.auth.token && request.auth.token.admin === true;
    if (!isAdmin) throw new HttpsError('permission-denied', 'Admin gerekli');
    const audience = request.data?.audience || {type: 'all'};
    let uids = await selectAudienceUids(audience);

    // İnaktif filtresi (opsiyonel)
    if (audience?.type === 'inactive' && typeof audience.hours === 'number') {
      const filtered = [];
      for (const uid of uids) {
        const ref = db.collection('users').doc(uid);
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
      tokenHolders += results.reduce((a,b)=> a+b, 0);
      // Güvenli sınır – çok büyük kitelerde gereksiz uzun sürmesin
      if (i > 0 && i % 5000 === 0) await new Promise((r)=> setTimeout(r, 50));
    }

    // Kullanıcı sayısı: platform/sürüm filtreleri varsa filtrelenmiş kullanıcı sayısı; aksi halde baz kitle
    const hasDeviceFilters = (Array.isArray(filters.platforms) && filters.platforms.length > 0) || Number.isFinite(filters.buildMin) || Number.isFinite(filters.buildMax);
    const users = hasDeviceFilters ? tokenHolders : baseUsers;

    return {users, baseUsers, tokenHolders};
  });

  exports.adminSendPush = onCall({region: 'us-central1', timeoutSeconds: 540}, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
    const isAdmin = request.auth.token && request.auth.token.admin === true;
    if (!isAdmin) throw new HttpsError('permission-denied', 'Admin gerekli');

    const title = String(request.data?.title || '').trim();
    const body = String(request.data?.body || '').trim();
    const imageUrl = request.data?.imageUrl ? String(request.data.imageUrl) : '';
    const route = String(request.data?.route || '/home');
    const audience = request.data?.audience || {type: 'all'};
    const scheduledAt = typeof request.data?.scheduledAt === 'number' ? request.data.scheduledAt : null;
    const sendTypeRaw = String(request.data?.sendType || 'push').toLowerCase();
    const sendType = ['push','inapp','both'].includes(sendTypeRaw) ? sendTypeRaw : 'push';

    if (!title || !body) throw new HttpsError('invalid-argument', 'title ve body zorunludur');

    const campaignRef = db.collection('push_campaigns').doc();
    const baseDoc = {
      title, body, imageUrl, route, audience,
      createdBy: request.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      sendType,
    };

    if (scheduledAt && scheduledAt > Date.now() + 15000) {
      await campaignRef.set({ ...baseDoc, status: 'scheduled', scheduledAt });
      return {ok: true, campaignId: campaignRef.id, scheduled: true};
    }

    await campaignRef.set({ ...baseDoc, status: 'sending' });

    let targetUids = await selectAudienceUids(audience);
    logger.info('adminSendPush audience selected', { count: targetUids.length, type: audience?.type || 'all' });
    if (audience?.type === 'inactive' && typeof audience.hours === 'number') {
      const filtered = [];
      for (const uid of targetUids) {
        const ref = db.collection('users').doc(uid);
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
    if (sendType === 'inapp' || sendType === 'both') {
      const inAppPromises = targetUids.map(uid =>
        createInAppForUser(uid, { title, body, imageUrl, route, type: 'campaign', campaignId: campaignRef.id })
      );
      const results = await Promise.all(inAppPromises);
      totalInApp = results.filter(Boolean).length;
    }

    // Handle push notifications
    if (sendType === 'push' || sendType === 'both') {
      const allTokens = [];
      const batchSize = 100;
      for (let i = 0; i < targetUids.length; i += batchSize) {
        const batchUids = targetUids.slice(i, i + batchSize);
        const tokenPromises = batchUids.map(uid => getActiveTokensFiltered(uid, filters));
        const tokenBatches = await Promise.all(tokenPromises);
        tokenBatches.forEach(tokens => allTokens.push(...tokens));
      }

      const uniqueTokens = [...new Set(allTokens)];

      if (uniqueTokens.length > 0) {
        const pushPayload = { title, body, imageUrl, route, type: 'campaign', campaignId: campaignRef.id };
        const result = await sendPushToTokens(uniqueTokens, pushPayload);
        totalSent = result.successCount;
        totalFail = result.failureCount;
      }
    }

    await campaignRef.set({ status: 'completed', totalUsers, totalSent, totalFail, totalInApp, completedAt: admin.firestore.FieldValue.serverTimestamp() }, {merge: true});
    return {ok: true, campaignId: campaignRef.id, totalUsers, totalSent, totalFail, totalInApp};
  });

  exports.processScheduledCampaigns = onSchedule({schedule: '*/5 * * * *', timeZone: 'Europe/Istanbul'}, async () => {
    const now = Date.now();
    const snap = await db.collection('push_campaigns').where('status','==','scheduled').where('scheduledAt','<=', now).limit(10).get();
    if (snap.empty) return;
    for (const doc of snap.docs) {
      const d = doc.data() || {};
      try {
        await doc.ref.set({ status: 'sending' }, {merge: true});
        const { title, body, imageUrl, route, audience } = d;
        const sendTypeRaw = String(d.sendType || 'push').toLowerCase();
        const sendType = ['push','inapp','both'].includes(sendTypeRaw) ? sendTypeRaw : 'push';

        let targetUids = await selectAudienceUids(audience);
        if (audience?.type === 'inactive' && typeof audience.hours === 'number') {
          const filtered = [];
          for (const uid of targetUids) {
            const ref = db.collection('users').doc(uid);
            const hrs = await computeInactivityHours(ref);
            if (hrs >= audience.hours) filtered.push(uid);
          }
          targetUids = filtered;
        }
        const filters = { buildMin: audience?.buildMin, buildMax: audience?.buildMax, platforms: audience?.platforms };
        let totalSent = 0, totalFail = 0, totalUsers = 0, totalInApp = 0;
        for (const uid of targetUids) {
          totalUsers++;
          if (sendType === 'inapp' || sendType === 'both') {
            const ok = await createInAppForUser(uid, { title, body, imageUrl, route, type: 'campaign', campaignId: doc.id });
            if (ok) totalInApp++;
          }
          if (sendType === 'push' || sendType === 'both') {
            const tokens = await getActiveTokensFiltered(uid, filters);
            if (tokens.length === 0) continue;
            const r = await sendPushToTokens(tokens, { title, body, imageUrl, route, type: 'campaign', campaignId: doc.id });
            totalSent += r.successCount; totalFail += r.failureCount;
            await doc.ref.collection('logs').add({uid, success: r.successCount, failed: r.failureCount, ts: admin.firestore.FieldValue.serverTimestamp()});
          }
        }
        await doc.ref.set({ status: 'completed', totalUsers, totalSent, totalFail, totalInApp, completedAt: admin.firestore.FieldValue.serverTimestamp() }, {merge: true});
      } catch (e) {
        logger.error('Scheduled campaign failed', {id: doc.id, error: String(e)});
        await doc.ref.set({ status: 'failed', error: String(e), failedAt: admin.firestore.FieldValue.serverTimestamp() }, {merge: true});
      }
    }
  });

  // Uygulama içi bildirim oluşturucu
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

