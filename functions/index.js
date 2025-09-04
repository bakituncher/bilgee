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

function dayKeyIstanbul(d = nowIstanbul()) {
  return `${d.getFullYear()}-${(d.getMonth()+1).toString().padStart(2,'0')}-${d.getDate().toString().padStart(2,'0')}`;
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

async function computeInactivityHours(userRef) {
  // user_activity bugun ve dunden kontrol edilir; yoksa app_state.lastActiveTs kullan
  try {
    const now = nowIstanbul();
    const ids = [];
    const today = dayKeyIstanbul(now);
    const y = new Date(now); y.setDate(now.getDate()-1);
    const yesterday = dayKeyIstanbul(y);
    ids.push(today, yesterday);
    let lastTs = 0;
    for (const id of ids) {
      const snap = await userRef.collection('user_activity').doc(id).get();
      if (snap.exists) {
        const data = snap.data() || {};
        const visits = Array.isArray(data.visits) ? data.visits : [];
        for (const v of visits) {
          const t = typeof v === 'number' ? v : (v?.ts || v?.t || 0);
          if (typeof t === 'number' && t > lastTs) lastTs = t;
        }
      }
    }
    if (lastTs === 0) {
      const app = await userRef.collection('state').doc('app_state').get();
      const t = app.exists ? (app.data()||{}).lastActiveTs : 0;
      if (typeof t === 'number') lastTs = t;
    }
    if (lastTs === 0) return 1e6; // bilinmiyorsa çok uzun kabul et
    const diffMs = now.getTime() - lastTs;
    return Math.max(0, Math.floor(diffMs / (1000*60*60)));
  } catch(_) {
    return 1e6;
  }
}

function buildInactivityTemplate(inactHours, examType) {
  // Basit örnek şablonlar
  if (inactHours >= 72) {
    return {
      title: 'Geri dön ve hedefini yakala! 💪',
      body: examType ? `${examType} için kaldığın yerden devam edelim. Şimdi 1 mini görevle açılış yap!` : 'Bugün bir adım atmak için harika bir an. 10 dakikalık bir görev seni bekliyor!',
      route: '/home/quests',
    };
  }
  if (inactHours >= 24) {
    return {
      title: 'Bir gün ara verdin. Şimdi hızlanma zamanı! ⚡',
      body: 'Hedefini 10’a çıkar: k��sa bir pratikle ivme yakala! 🎯',
      route: '/home/add-test',
    };
  }
  if (inactHours >= 3) {
    return {
      title: 'Mini odak molası ister misin? ⏱️',
      body: 'Sadece 15 dakikalık Pomodoro ile müthiş bir geri dönüş yap. 10’a çıkarma yolunda ilk adım!',
      route: '/home/pomodoro',
    };
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
    const resp = await admin.messaging().sendEachForMulticast(message);
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
async function selectAudienceUids(audience) {
  let query = db.collection('users');
  const lc = (s) => typeof s === 'string' ? s.toLowerCase() : s;
  if (audience?.type === 'exam' && audience.examType) {
    const exam = lc(audience.examType);
    query = query.where('selectedExam', '==', exam);
    const snap = await query.select().limit(20000).get();
    return snap.docs.map((d)=> d.id);
  }
  if (audience?.type === 'exams' && Array.isArray(audience.exams) && audience.exams.length > 0) {
    const exams = audience.exams.filter((x)=> typeof x === 'string').map((s)=> s.toLowerCase());
    if (exams.length === 0) {
      const snap = await db.collection('users').select().limit(20000).get();
      return snap.docs.map((d)=> d.id);
    }
    if (exams.length <= 10) {
      const snap = await db.collection('users').where('selectedExam', 'in', exams).select().limit(20000).get();
      return snap.docs.map((d)=> d.id);
    }
    // 10'dan fazlaysa basit filtreleme (tüm kullanıcıları çekip bellekte filtreleyin)
    const all = await db.collection('users').select('selectedExam').limit(20000).get();
    return all.docs.filter((d)=> exams.includes((d.data()||{}).selectedExam)).map((d)=> d.id);
  }
  if (audience?.type === 'uids' && Array.isArray(audience.uids)) {
    return audience.uids.filter((x)=> typeof x === 'string');
  }
  const snap = await query.select().limit(20000).get();
  return snap.docs.map((d)=> d.id);
}

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
  const audience = request.data?.audience || {type: 'all'}; // 'all'|'exam'|'uids'|'inactive'
  const scheduledAt = typeof request.data?.scheduledAt === 'number' ? request.data.scheduledAt : null; // epoch ms
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

  // Planlı ise dokümana yazıp çık
  if (scheduledAt && scheduledAt > Date.now() + 15000) { // 15sn sonrası kabul
    await campaignRef.set({ ...baseDoc, status: 'scheduled', scheduledAt });
    return {ok: true, campaignId: campaignRef.id, scheduled: true};
  }

  // Hemen gönder
  await campaignRef.set({ ...baseDoc, status: 'sending' });

  // Alıcılar
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

  let totalSent = 0, totalFail = 0, totalUsers = 0, totalInApp = 0;
  for (const uid of targetUids) {
    totalUsers++;

    if (sendType === 'inapp' || sendType === 'both') {
      const ok = await createInAppForUser(uid, { title, body, imageUrl, route, type: 'campaign', campaignId: campaignRef.id });
      if (ok) totalInApp++;
    }

    if (sendType === 'push' || sendType === 'both') {
      const tokens = await getActiveTokensFiltered(uid, filters);
      if (tokens.length > 0) {
        const r = await sendPushToTokens(tokens, { title, body, imageUrl, route, type: 'campaign', campaignId: campaignRef.id });
        totalSent += r.successCount; totalFail += r.failureCount;
        await campaignRef.collection('logs').add({uid, success: r.successCount, failed: r.failureCount, ts: admin.firestore.FieldValue.serverTimestamp()});
      } else {
        await campaignRef.collection('logs').add({uid, success: 0, failed: 0, ts: admin.firestore.FieldValue.serverTimestamp(), note: 'no_tokens'});
      }
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

// Yardımcı: İstanbul saatine göre şimdi
function nowIstanbul() {
  const now = new Date();
  try { return new Date(now.toLocaleString('en-US', {timeZone: 'Europe/Istanbul'})); } catch (_) { return now; }
}

// Blog kapakları için storage temizliği
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

// Görev şablonları
const QUEST_TEMPLATES = (() => {
  try {
    const p = path.join(__dirname, "quests.json");
    const raw = fs.readFileSync(p, "utf8");
    return JSON.parse(raw);
  } catch (error) {
    logger.error("quests.json dosyası okunamadı!", error);
    return [];
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

async function getUserContext(userRef) {
  const ctx = { analysis: null, stats: null, app: null, user: null, yesterdayInactive: false, examType: null };
  const userSnap = await userRef.get();
  ctx.user = userSnap.exists ? userSnap.data() : {};
  ctx.examType = ctx.user?.selectedExam || null;
  try { const a = await userRef.collection('performance').doc('analysis_summary').get(); ctx.analysis = a.exists ? a.data() : null; } catch(_) {}
  try { const s = await userRef.collection('state').doc('stats').get(); ctx.stats = s.exists ? s.data() : null; } catch(_) {}
  try { const app = await userRef.collection('state').doc('app_state').get(); ctx.app = app.exists ? app.data() : null; } catch(_) {}
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

function timeOfDayLabel(d) { const h = d.getHours(); if (h < 12) return 'morning'; if (h < 18) return 'afternoon'; return 'night'; }

function evaluateTriggerConditions(template, ctx) {
  const cond = template.triggerConditions || {};
  if (!cond || Object.keys(cond).length === 0) return true;
  const now = nowIstanbul();
  if (cond.timeOfDay) {
    const wanted = Array.isArray(cond.timeOfDay) ? cond.timeOfDay : [cond.timeOfDay];
    if (!wanted.includes(timeOfDayLabel(now))) return false;
  }
  if (cond.dayOfWeek) {
    const map = ['sunday','monday','tuesday','wednesday','thursday','friday','saturday'];
    const today = map[now.getDay()];
    const wanted = Array.isArray(cond.dayOfWeek) ? cond.dayOfWeek : [cond.dayOfWeek];
    if (!wanted.includes(today)) return false;
  }
  if (cond.wasInactiveYesterday === true && ctx.yesterdayInactive !== true) return false;
  if (cond.hasWeakSubject === true) { const w = ctx.analysis?.weakestSubjectByNet; if (!w || w === 'Belirlenemedi') return false; }
  if (cond.hasStrongSubject === true) { const s = ctx.analysis?.strongestSubjectByNet; if (!s || s === 'Belirlenemedi') return false; }
  if (cond.examType) { const wanted = Array.isArray(cond.examType) ? cond.examType : [cond.examType]; if (!ctx.examType || !wanted.includes(ctx.examType)) return false; }
  if (cond.notUsedFeature) { const f = String(cond.notUsedFeature); const used = ctx.app?.[`feature_${f}_used`]; if (used === true) return false; }
  if (cond.usedFeatureRecently) { const f = String(cond.usedFeatureRecently); const used = ctx.app?.[`feature_${f}_used`]; if (used !== true) return false; }
  if (cond.lowYesterdayPlanRatio === true) { const r = ctx.user?.lastScheduleCompletionRatio; if (!(typeof r === 'number' && r < 0.5)) return false; }
  if (cond.highYesterdayPlanRatio === true) { const r = ctx.user?.lastScheduleCompletionRatio; if (!(typeof r === 'number' && r >= 0.85)) return false; }
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
  const scored = pool.map((q) => ({q, s: scoreTemplateForUser(q, ctx)})).sort((a,b)=> b.s - a.s);
  const selected = []; const usedCategories = new Set();
  for (const it of scored) { if (selected.length >= desiredCount) break; const q = it.q; if (usedCategories.has(q.category) && Math.random() < 0.45) continue; selected.push(q); usedCategories.add(q.category); }
  return selected;
}

function materializeTemplates(templates, userData, analysis) {
  const nowTs = admin.firestore.Timestamp.now();
  return templates.map((q) => {
    const { title, description, tags } = personalizeTemplate(q, userData, analysis);
    const actionRoute = q.actionRoute || '/home';
    const routeKey = routeKeyFromPath(actionRoute);
    return { qid: q.id, title, description, type: q.type || 'daily', category: q.category, progressType: q.progressType || 'increment', reward: q.reward, goalValue: q.goalValue, currentProgress: 0, isCompleted: false, actionRoute, routeKey, tags, rewardClaimed: false, createdAt: nowTs, schemaVersion: 2 };
  });
}

async function ensureWeeklyAndMonthly(userRef, userData, analysis, force = false) {
  const ctx = await getUserContext(userRef);
  const now = nowIstanbul();
  const weekStart = new Date(now); weekStart.setDate(now.getDate() - (now.getDay() === 0 ? 6 : (now.getDay()-1))); weekStart.setHours(0,0,0,0);
  const weekKey = `${weekStart.getFullYear()}-${(weekStart.getMonth()+1).toString().padStart(2,'0')}-${weekStart.getDate().toString().padStart(2,'0')}`;
  const weeklyCol = userRef.collection('weekly_quests');
  const weeklySnap = await weeklyCol.where('weekKey', '==', weekKey).limit(1).get();
  if (weeklySnap.empty || force) {
    if (force) { const toDel = await weeklyCol.where('weekKey', '==', weekKey).get(); const delBatch = db.batch(); toDel.docs.forEach((d)=> delBatch.delete(d.ref)); if (!toDel.empty) await delBatch.commit(); }
    const tpls = pickTemplatesForType('weekly', ctx, 6);
    const list = materializeTemplates(tpls, userData, analysis).map((x)=> ({...x, weekKey}));
    const batch = db.batch(); list.forEach((q)=> batch.set(weeklyCol.doc(q.qid), q, {merge:true})); await batch.commit();
  }
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const monthKey = `${monthStart.getFullYear()}-${(monthStart.getMonth()+1).toString().padStart(2,'0')}`;
  const monthlyCol = userRef.collection('monthly_quests');
  const monthlySnap = await monthlyCol.where('monthKey', '==', monthKey).limit(1).get();
  if (monthlySnap.empty || force) {
    if (force) { const toDel = await monthlyCol.where('monthKey', '==', monthKey).get(); const delBatch = db.batch(); toDel.docs.forEach((d)=> delBatch.delete(d.ref)); if (!toDel.empty) await delBatch.commit(); }
    const tpls = pickTemplatesForType('monthly', ctx, 6);
    const list = materializeTemplates(tpls, userData, analysis).map((x)=> ({...x, monthKey}));
    const batch = db.batch(); list.forEach((q)=> batch.set(monthlyCol.doc(q.qid), q, {merge:true})); await batch.commit();
  }
}

function pickDailyQuestsForUser(userData, analysis, ctx) {
  const tpls = pickTemplatesForType('daily', ctx, 7);
  return materializeTemplates(tpls, userData, analysis);
}

async function generateQuestsForAllUsers() {
  const usersSnap = await db.collection("users").get();
  const batchPromises = []; let batch = db.batch(); let opCount = 0;
  for (const doc of usersSnap.docs) {
    const userRef = doc.ref; let analysis = null; let ctx = null;
    try { const a = await userRef.collection('performance').doc('analysis_summary').get(); analysis = a.exists ? a.data() : null; } catch (_) { analysis = null; }
    ctx = await getUserContext(userRef);
    const dailyRef = userRef.collection("daily_quests");
    const daily = pickDailyQuestsForUser(doc.data(), analysis, ctx);
    const existing = await dailyRef.get(); existing.docs.forEach((d) => { batch.delete(d.ref); opCount++; });
    daily.forEach((q) => { batch.set(dailyRef.doc(q.qid), q, {merge:true}); opCount++; });
    batch.update(userRef, { lastQuestRefreshDate: admin.firestore.FieldValue.serverTimestamp() });
    await ensureWeeklyAndMonthly(userRef, doc.data(), analysis, false);
    if (opCount > 400) { batchPromises.push(batch.commit()); batch = db.batch(); opCount = 0; }
  }
  if (opCount > 0) batchPromises.push(batch.commit());
  await Promise.all(batchPromises);
}

// Gemini API'sine güvenli bir şekilde istek atan proxy fonksiyonu.
const GEMINI_KEY = process.env.GEMINI_API_KEY;

// Güvenlik ve kötüye kullanım önleme ayarları
const GEMINI_PROMPT_MAX_CHARS = parseInt(process.env.GEMINI_PROMPT_MAX_CHARS || '50000', 10);
const GEMINI_MAX_OUTPUT_TOKENS = parseInt(process.env.GEMINI_MAX_OUTPUT_TOKENS || '50000', 10);
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
