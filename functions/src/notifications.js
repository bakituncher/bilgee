const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const { db, admin, messaging } = require("./init");
const { dayKeyIstanbul } = require("./utils");
const { computeInactivityHours, selectAudienceUids } = require("./users");

// ---- FCM TOKEN KAYDI ----
exports.registerFcmToken = onCall({region: 'us-central1', enforceAppCheck: true}, async (request) => {
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
exports.unregisterFcmToken = onCall({region: 'us-central1', enforceAppCheck: true}, async (request) => {
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

  // Günlük limit kontrolü: sadece okuma, sayaç arttırmaz
  async function hasRemainingToday(uid, maxPerDay = 3) {
    try {
      const countersRef = db.collection('users').doc(uid).collection('state').doc('notification_counters');
      const snap = await countersRef.get();
      const today = dayKeyIstanbul();
      if (!snap.exists) return true;
      const d = snap.data() || {};
      const day = String(d.day || '');
      const sent = Number(d.sent || 0);
      if (day !== today) return true;
      return sent < maxPerDay;
    } catch (_) {
      return true;
    }
  }

  // Başarılı gönderim sonrası güvenli şekilde sayaç arttır (gün değişimini dikkate alır)
  async function incrementSentCount(uid, maxPerDay = 3) {
    const countersRef = db.collection('users').doc(uid).collection('state').doc('notification_counters');
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
      const prevDay = String(d.day || '');
      const prevSent = Number(d.sent || 0);
      const newDay = prevDay === today ? today : today;
      const base = prevDay === today ? prevSent : 0;
      if (base >= maxPerDay) { ok = false; return; }
      tx.set(countersRef, { day: newDay, sent: base + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      ok = true;
    });
    return ok;
  }

function _selectRandom(arr) {
  if (!arr || arr.length === 0) return '';
  return arr[Math.floor(Math.random() * arr.length)];
}

/**
 * Kullanıcı verilerine dayanarak akıllı ve kişiselleştirilmiş bir bildirim şablonu oluşturur.
 * Öncelik sırası:
 * 1. En zayıf dersi hedefleme (en yüksek öncelik).
 * 2. Aktif seriyi koruma motivasyonu.
 * 3. Premium olmayanlar için premium tanıtımı.
 * 4. Kaybedilmiş seriyi yeniden başlatma teşviki.
 * 5. Genel hareketsizlik hatırlatmaları (en düşük öncelik).
 * @param {{isPremium: boolean, selectedExam?: string}} userProfile Kullanıcı profili.
 * @param {{weakestSubject?: string}} userPerformance Kullanıcı performansı.
 * @param {{streak?: number, lostStreak?: boolean}} userStats Kullanıcı istatistikleri.
 * @param {number} inactivityHours Son aktiviteden bu yana geçen saat.
 * @returns {{title: string, body: string, route: string}|null} Bildirim objesi veya null.
 */
function buildPersonalizedTemplate(userProfile, userPerformance, userStats, inactivityHours) {
  const { isPremium = false, selectedExam } = userProfile || {};
  const { weakestSubject } = userPerformance || {};
  const { streak = 0, lostStreak = false } = userStats || {};

  const exam = selectedExam ? selectedExam.toUpperCase() : 'sınav';
  const safeWeakestSubject = weakestSubject || 'zayıf bir konunu';

  // --- Öncelik 1: En Zayıf Ders Üzerine Gitme ---
  // Kullanıcı aktifse (son 3 gün içinde) ve zayıf bir dersi varsa, bu en değerli bildirimdir.
  if (inactivityHours < 72 && weakestSubject) {
    const titles = [
      `Bu konuyu halletme zamanı: ${weakestSubject}! 💪`,
      `${weakestSubject} konusuna bir şans daha ver! 🚀`,
      `Zayıf halkanı güçlendir: ${weakestSubject} 🧠`,
    ];
    const bodies = [
      `Hadi, ${exam} öncesi ${safeWeakestSubject} güçlendirelim. Sadece 15 dakikalık bir testle fark yarat!`,
      `Bugün ${safeWeakestSubject} üzerine odaklanmaya ne dersin? Kısa bir tekrarla netlerini uçurabilirsin!`,
      `Potansiyelini keşfet! ${safeWeakestSubject} bir sonraki başarın olabilir. Ufak bir adımla başla.`,
    ];
    return {
      title: _selectRandom(titles),
      body: _selectRandom(bodies),
      route: '/home/add-test', // Kullanıcıyı direkt test çözmeye yönlendir
    };
  }

  // --- Öncelik 2: Aktif Seriyi Koruma ---
  // Serisi olan ve aktif olan kullanıcıları motive et
  if (inactivityHours < 48 && streak > 1) {
    const titles = [
      `Serin harika gidiyor: ${streak}. gün! 🔥`,
      `Alev alevsin! ${streak} günlük seri! ✨`,
      `${streak} gündür durdurulamazsın!  devam et! 🏆`,
    ];
    const bodies = [
      `Bugün de hedefine bir adım daha yaklaş. Serini bozma, ${exam} yolunda emin adımlarla ilerle!`,
      `Bu seri bozulmaz! Bugün de küçük bir görevle serini koru ve motive kal.`,
      `Disiplinin konuşuyor! Serini devam ettirerek ${exam} için ne kadar ciddi olduğunu göster.`,
    ];
    return {
      title: _selectRandom(titles),
      body: _selectRandom(bodies),
      route: '/home/quests',
    };
  }

  // --- Öncelik 3: Premium Olmayanlara Özel Teklifler ---
  // Premium değilse ve bir süredir aktif değilse (ama tamamen kaybolmadıysa)
  if (!isPremium && inactivityHours >= 24 && inactivityHours < 120) {
    const titles = [
      'Sınırsız potansiyelini keşfet! ✨',
      'Çalışmalarını bir üst seviyeye taşı! 🚀',
      'Daha akıllı çalış, daha hızlı ilerle! 🧠',
    ];
    const bodies = [
      'Premium ile kişiselleştirilmiş çalışma planları ve sınırsız test çözme imkanı seni bekliyor. Hedefine giden yolda sana özel bir koç gibi!',
      'Takıldığın konuları anında çözen yapay zeka koçuyla tanıştın mı? Premium ile tüm kilitleri aç.',
      `${exam} hazırlığında fark yaratmak için Premium özelliklerine göz at. İlk adımı at, potansiyelini serbest bırak!`,
    ];
    return {
      title: _selectRandom(titles),
      body: _selectRandom(bodies),
      route: '/premium', // Premium sayfasına yönlendir
    };
  }

  // --- Öncelik 4: Kaybedilmiş Seriyi Geri Kazanma ---
  if (lostStreak && inactivityHours < 72) {
      return {
          title: 'Hey, serin bozuldu ama sorun değil!  yeniden başla! 💪',
          body: `Herkes tökezleyebilir. Önemli olan yeniden başlamak! Bugün yeni bir seri başlatarak ${exam} hedefine bir adım daha at.`,
          route: '/home/quests',
      };
  }


  // --- Öncelik 5: Genel Hareketsizlik Hatırlatmaları (Fallback) ---
  if (inactivityHours >= 72) { // 3+ gün
    return {
      title: 'Gözlerimiz seni arıyor! 👀',
      body: `${exam} hedefin için küçük bir adım atmanın tam zamanı. 10 dakikalık bir görevle yeniden başla!`,
      route: '/home/quests',
    };
  }
  if (inactivityHours >= 24) { // 1+ gün
    return {
      title: 'Bir gündür yoksun, özlettin! 👋',
      body: `Bugün ${exam} için ne yapıyoruz? Kısa bir testle ısınmaya ne dersin? Hadi ama!`,
      route: '/home/add-test',
    };
  }
  if (inactivityHours >= 4) { // 4+ saat (daha sık)
    return {
      title: 'Enerjini topladıysan, devam edelim mi? ⚡️',
      body: 'Kısa bir mola harikalar yaratır. Şimdi 15 dakikalık bir pomodoro ile hedefine odaklan!',
      route: '/home/pomodoro',
    };
  }

  return null; // Eğer hiçbir koşul eşleşmezse bildirim gönderme
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
      tokens: uniq.slice(0, 500), // güvenlik: tek çağrıda max 500
    };
    try {
      const resp = await messaging.sendEachForMulticast(message);
      return {successCount: resp.successCount, failureCount: resp.failureCount};
    } catch (e) {
      logger.error('FCM send failed', { error: String(e) });
      return {successCount: 0, failureCount: uniq.length};
    }
  }

  // 500 limitini gözeterek büyük token listelerini parça parça gönder
  async function sendPushToTokensBatched(tokens, payload, batchSize = 500) {
    const uniq = Array.from(new Set((tokens || []).filter(Boolean)));
    let successCount = 0, failureCount = 0;
    for (let i = 0; i < uniq.length; i += batchSize) {
      const chunk = uniq.slice(i, i + batchSize);
      const r = await sendPushToTokens(chunk, payload);
      successCount += r.successCount;
      failureCount += r.failureCount;
      if (i > 0 && i % (batchSize * 10) === 0) await new Promise((r)=> setTimeout(r, 50));
    }
    return { successCount, failureCount };
  }

  async function dispatchInactivityPushBatch(limitUsers = 500) {
  const randomId = db.collection('users').doc().id;
  const usersSnap = await db.collection('users')
      .orderBy(admin.firestore.FieldPath.documentId())
      .startAt(randomId)
      .limit(limitUsers * 2) // Daha geniş bir aralıktan çek
      .get();

    let processed = 0, sent = 0;
  for (const userDoc of usersSnap.docs) {
      if (processed >= limitUsers) break;

      const uid = userDoc.id;
      const userRef = userDoc.ref;

      try {
          const inactivityHours = await computeInactivityHours(userRef);
          // 4 saatten daha az inaktif olanları rahatsız etme
          if (inactivityHours < 4) {
              processed++;
              continue;
          }

          // Gerekli tüm verileri paralel olarak çek
          const [performanceSnap, statsSnap, tokens] = await Promise.all([
              userRef.collection('performance').doc('summary').get(),
              userRef.collection('state').doc('stats').get(),
              getActiveTokens(uid),
          ]);

          if (tokens.length === 0) {
              processed++;
              continue;
          }

          const userProfile = userDoc.data() || {};
          const userPerformance = performanceSnap.exists ? performanceSnap.data() : {};
          const userStats = statsSnap.exists ? statsSnap.data() : {};

          const tpl = buildPersonalizedTemplate(userProfile, userPerformance, userStats, inactivityHours);

          if (!tpl) {
              processed++;
              continue;
          }

          const remain = await hasRemainingToday(uid, 3);
          if (!remain) {
              processed++;
              continue;
          }

          const r = await sendPushToTokens(tokens, { ...tpl, type: 'personalized_inactivity' });
          if (r.successCount > 0) {
              const inc = await incrementSentCount(uid, 3);
              if (inc) sent++;
          }
      } catch (error) {
          logger.error(`Kullanıcı için bildirim işlenemedi: ${uid}`, { error: String(error) });
      } finally {
          processed++;
      }
  }
  logger.info('dispatchInactivityPushBatch tamamlandı', { processed, sent });
  return { processed, sent };
}

  function scheduleSpecAt(hour, minute = 0) {
    return {schedule: `${minute} ${hour} * * *`, timeZone: 'Europe/Istanbul'};
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
  exports.adminEstimateAudience = onCall({region: 'us-central1', timeoutSeconds: 300, enforceAppCheck: true}, async (request) => {
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

  exports.adminSendPush = onCall({region: 'us-central1', timeoutSeconds: 540, enforceAppCheck: true}, async (request) => {
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
        const result = await sendPushToTokensBatched(uniqueTokens, pushPayload, 500);
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
