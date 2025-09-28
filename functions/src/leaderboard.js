const { onDocumentWritten, onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { db, admin } = require("./init");
const { weekKeyIstanbul, dayKeyIstanbul } = require("./utils");
const { updatePublicProfile } = require("./profile");

// ==== Liderlik Tabloları: Yardımcılar ====

async function upsertLeaderboardExam(examType) {
  if (!examType) return;
  try { await db.collection('leaderboard_exams').doc(String(examType)).set({ exists: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, {merge: true}); } catch(_) {}
}

async function upsertLeaderboardScore({ examType, uid, delta, userDocData }) {
  if (!examType || !uid || !(delta > 0)) return;
  const dayKey = dayKeyIstanbul();
  const weekKey = weekKeyIstanbul();
  const base = db.collection('leaderboard_scores').doc(examType);
  const dailyRef = base.collection('daily').doc(dayKey).collection('users').doc(uid);
  const weeklyRef = base.collection('weekly').doc(weekKey).collection('users').doc(uid);
  const safeName = userDocData?.name || '';
  const avatarStyle = userDocData?.avatarStyle || null;
  const avatarSeed = userDocData?.avatarSeed || null;
  const payload = {
    userId: uid,
    userName: safeName,
    avatarStyle,
    avatarSeed,
    score: admin.firestore.FieldValue.increment(delta),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await Promise.all([
    dailyRef.set(payload, {merge: true}),
    weeklyRef.set(payload, {merge: true}),
    upsertLeaderboardExam(examType),
  ]);
}

// Yeni: Skoru mutlak değerle yazan yardımcı (backfill için)
async function setLeaderboardScoreAbsolute({ examType, uid, score, userDocData, kinds = ['daily','weekly'] }) {
  if (!examType || !uid) return;
  const safeScore = Number.isFinite(score) ? Number(score) : 0;
  const dayKey = dayKeyIstanbul();
  const weekKey = weekKeyIstanbul();
  const base = db.collection('leaderboard_scores').doc(String(examType));
  const dailyRef = base.collection('daily').doc(dayKey).collection('users').doc(uid);
  const weeklyRef = base.collection('weekly').doc(weekKey).collection('users').doc(uid);
  const safeName = userDocData?.name || '';
  const avatarStyle = userDocData?.avatarStyle || null;
  const avatarSeed = userDocData?.avatarSeed || null;
  const payload = {
    userId: uid,
    userName: safeName,
    avatarStyle,
    avatarSeed,
    score: safeScore,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  const writes = [];
  if (kinds.includes('daily')) writes.push(dailyRef.set(payload, {merge: true}));
  if (kinds.includes('weekly')) writes.push(weeklyRef.set(payload, {merge: true}));
  writes.push(upsertLeaderboardExam(examType));
  await Promise.all(writes);
}

// YENİ: Genişletilmiş ve optimize edilmiş anlık görüntü yayıncısı
async function publishLeaderboardSnapshot(examType, kind, limit = 200) {
  const container = db.collection('leaderboard_scores').doc(examType).collection(kind);
  const periodId = kind === 'daily' ? dayKeyIstanbul() : weekKeyIstanbul();
  const usersCol = container.doc(periodId).collection('users');

  // Top 200 kullanıcıyı çek
  const qs = await usersCol.orderBy('score', 'desc').limit(limit).get();
  if (qs.empty) {
    // Eğer hiç kullanıcı yoksa, eski snapshot'ı temizle
    const snapshotRef = db.collection('leaderboard_snapshots').doc(`${examType}_${kind}`);
    await snapshotRef.delete().catch(() => {}); // Hata durumunda devam et
    return;
  }

  const entries = qs.docs.map((d, index) => {
    const x = d.data() || {};
    return {
      userId: x.userId || d.id,
      userName: x.userName || '',
      score: typeof x.score === 'number' ? x.score : 0,
      rank: index + 1, // Sıralamayı doğrudan ekle
      avatarStyle: x.avatarStyle || null,
      avatarSeed: x.avatarSeed || null,
    };
  });

  const snapshotRef = db.collection('leaderboard_snapshots').doc(`${examType}_${kind}`);
  const doc = {
    entries,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    periodId,
    examType,
    kind,
  };
  await snapshotRef.set(doc);

  // Geriye dönük uyumluluk veya anlık en tepeyi isteyenler için top-20'yi de yayınla
  const top20 = entries.slice(0, 20);
  const topRef = db.collection('leaderboard_top').doc(examType).collection(kind).doc('latest');
  await topRef.set({ entries: top20, updatedAt: admin.firestore.FieldValue.serverTimestamp(), periodId }, { merge: true });
}

async function cleanupOldLeaderboards() {
  const today = dayKeyIstanbul();
  const thisWeek = weekKeyIstanbul();
  // Temizleme: leaderboard_scores günlük (dünkü ve öncesi) ve haftalık (geçen hafta ve öncesi)
  const examsSnap = await db.collection('leaderboard_exams').get();
  for (const ex of examsSnap.docs) {
    const examType = ex.id;
    // Daily
    const dailyColl = db.collection('leaderboard_scores').doc(examType).collection('daily');
    const oldDaily = await dailyColl.where(admin.firestore.FieldPath.documentId(), '<', today).limit(10).get();
    for (const d of oldDaily.docs) {
      // Silmeden önce alt koleksiyon kullanıcılarını parti parti temizle
      const usersCol = d.ref.collection('users');
      while (true) {
        const batchUsers = await usersCol.limit(500).get();
        if (batchUsers.empty) break;
        const batch = db.batch();
        batchUsers.docs.forEach((u) => batch.delete(u.ref));
        await batch.commit();
      }
      await d.ref.delete().catch(()=>{});
    }
    // Weekly
    const weeklyColl = db.collection('leaderboard_scores').doc(examType).collection('weekly');
    const oldWeekly = await weeklyColl.where(admin.firestore.FieldPath.documentId(), '<', thisWeek).limit(5).get();
    for (const w of oldWeekly.docs) {
      const usersCol = w.ref.collection('users');
      while (true) {
        const batchUsers = await usersCol.limit(500).get();
        if (batchUsers.empty) break;
        const batch = db.batch();
        batchUsers.docs.forEach((u) => batch.delete(u.ref));
        await batch.commit();
      }
      await w.ref.delete().catch(()=>{});
    }
    // Top doküman eski dönemler (periodId) – latest bırak
    const topDaily = db.collection('leaderboard_top').doc(examType).collection('daily');
    const td = await topDaily.where(admin.firestore.FieldPath.documentId(), '!=', 'latest').limit(20).get();
    for (const d of td.docs) { if (d.id < today) await d.ref.delete().catch(()=>{}); }
    const topWeekly = db.collection('leaderboard_top').doc(examType).collection('weekly');
    const tw = await topWeekly.where(admin.firestore.FieldPath.documentId(), '!=', 'latest').limit(20).get();
    for (const w of tw.docs) { if (w.id < thisWeek) await w.ref.delete().catch(()=>{}); }
  }
}

// ==== Stats tetikleyicisi: günlük/haftalık skorları türet ve public profile güncelle ====
exports.onUserStatsWritten = onDocumentWritten({
  document: "users/{userId}/state/stats",
  region: "us-central1"
}, async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const uid = event.params.userId;
    try {
      const prev = typeof before.engagementScore === 'number' ? before.engagementScore : 0;
      const curr = typeof after.engagementScore === 'number' ? after.engagementScore : 0;
      const delta = Math.max(0, curr - prev);
      // Kullanıcının examType'ını oku
      const userSnap = await db.collection('users').doc(uid).get();
      const examType = (userSnap.data() || {}).selectedExam || null;
      if (delta > 0 && examType) {
        await upsertLeaderboardScore({ examType, uid, delta, userDocData: userSnap.data() || {} });
      }
      // Public profile'ı güncelle
      await updatePublicProfile(uid);
    } catch (e) {
      logger.error('onUserStatsWritten failed', { uid, error: String(e) });
    }
  });

  // Kullanıcı profil güncellemesi: public_profile yansıt
exports.onUserProfileChanged = onDocumentWritten({
  document: "users/{userId}",
  region: "us-central1"
}, async (event) => {
    const uid = event.params.userId;
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    try {
      // Public profile senkronu
      await updatePublicProfile(uid);

      const prevExam = before?.selectedExam || null;
      const newExam = after?.selectedExam || null;
      const name = after?.name || '';
      const avatarStyle = after?.avatarStyle || null;
      const avatarSeed = after?.avatarSeed || null;

      if (newExam) {
        // Stats oku (puan/testCount için)
        let stats = {};
        try {
          const sSnap = await db.collection('users').doc(uid).collection('state').doc('stats').get();
          stats = sSnap.exists ? (sSnap.data() || {}) : {};
        } catch (_) {}
        const score = typeof stats.engagementScore === 'number' ? stats.engagementScore : 0;
        const testCount = typeof stats.testCount === 'number' ? stats.testCount : 0;

        // Legacy leaderboards kaydını güncelle
        const lbRef = db.collection('leaderboards').doc(String(newExam)).collection('users').doc(uid);
        await lbRef.set({
          userId: uid,
          userName: name,
          avatarStyle,
          avatarSeed,
          score, // skorun kendisi de tutarlı kalsın
          testCount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        // Yeni leaderboard_scores (günlük/haftalık) isim ve avatar senkronu
        const dayKey = dayKeyIstanbul();
        const weekKey = weekKeyIstanbul();
        const base = db.collection('leaderboard_scores').doc(String(newExam));
        await Promise.all([
          base.collection('daily').doc(dayKey).collection('users').doc(uid).set({
            userId: uid,
            userName: name,
            avatarStyle,
            avatarSeed,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true }),
          base.collection('weekly').doc(weekKey).collection('users').doc(uid).set({
            userId: uid,
            userName: name,
            avatarStyle,
            avatarSeed,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true }),
        ]);

        // YENİ: Periyodik snapshot güncellemeleri bu anlık yeniden yayını gereksiz kılar.
        // await Promise.allSettled([
        //   publishLeaderboardSnapshot(String(newExam), 'daily'),
        //   publishLeaderboardSnapshot(String(newExam), 'weekly'),
        // ]);
      }

      // Sınav değiştiyse eski leaderboard kaydını temizle
      if (prevExam && prevExam !== newExam) {
        await db.collection('leaderboards').doc(String(prevExam)).collection('users').doc(uid).delete().catch(()=>{});
      }
    } catch (e) {
      logger.warn('onUserProfileChanged sync failed', { uid, error: String(e) });
    }
  });

  // YENİ: Zamanlanmış: 15 dakikada bir anlık görüntüleri yayınla
exports.publishLeaderboardSnapshots = onSchedule({ schedule: '*/15 * * * *', timeZone: 'Europe/Istanbul' }, async () => {
    const examsSnap = await db.collection('leaderboard_exams').get();
    if (examsSnap.empty) {
      logger.info('publishLeaderboardSnapshots: No exams found to process.');
      return;
    }
    const jobs = [];
    for (const ex of examsSnap.docs) {
      const examType = ex.id;
      // Her sınav türü için günlük ve haftalık anlık görüntüleri oluştur
      jobs.push(publishLeaderboardSnapshot(examType, 'daily'));
      jobs.push(publishLeaderboardSnapshot(examType, 'weekly'));
    }
    await Promise.all(jobs);
    logger.info(`publishLeaderboardSnapshots completed for ${examsSnap.size} exams.`);
  });

  // ==== Zamanlanmış: Günlük temizlik ====
exports.cleanupLeaderboards = onSchedule({ schedule: '30 3 * * *', timeZone: 'Europe/Istanbul' }, async () => {
    await cleanupOldLeaderboards();
    logger.info('cleanupLeaderboards completed');
  });

  // ==== Kullanıcı rütbe ve komşu sorgusu (callable) ====
// YENİ: Optimize edilmiş: Anlık görüntüden sıralama ve komşuları al
exports.getLeaderboardRank = onCall({region: 'us-central1', timeoutSeconds: 30, enforceAppCheck: true}, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
    const uid = request.auth.uid;
    const examType = String(request.data?.examType || '').trim();
    const period = String(request.data?.period || 'daily').trim();
    if (!examType) throw new HttpsError('invalid-argument', 'examType gerekli');

    const kind = period === 'weekly' ? 'weekly' : 'daily';
    const snapshotRef = db.collection('leaderboard_snapshots').doc(`${examType}_${kind}`);
    const snapshot = await snapshotRef.get();

    if (!snapshot.exists) {
      // Anlık görüntü henüz yoksa, kullanıcıya boş bir yanıt döndür.
      // İstemci bunu "Sıralama hesaplanıyor..." olarak gösterebilir.
      return { rank: null, score: 0, neighbors: [] };
    }

    const data = snapshot.data() || {};
    const entries = Array.isArray(data.entries) ? data.entries : [];
    const userIndex = entries.findIndex((e) => e.userId === uid);

    if (userIndex === -1) {
      // Kullanıcı listede (örneğin ilk 200'de) değilse.
      // Bu durumda, kendi skorunu `leaderboard_scores`'dan okuyabiliriz.
      const periodId = kind === 'daily' ? dayKeyIstanbul() : weekKeyIstanbul();
      const userScoreRef = db.collection('leaderboard_scores').doc(examType).collection(kind).doc(periodId).collection('users').doc(uid);
      const userScoreSnap = await userScoreRef.get();
      const score = userScoreSnap.exists ? (userScoreSnap.data()?.score || 0) : 0;
      // Sıralamayı "200+" gibi bir ifadeyle döndürebiliriz veya null bırakabiliriz.
      return { rank: null, score: score, neighbors: [], totalCount: entries.length };
    }

    const userEntry = entries[userIndex];
    const rank = userEntry.rank;
    const score = userEntry.score;

    // Komşuları hesapla: kendisinden önceki 2 ve sonraki 2
    const start = Math.max(0, userIndex - 2);
    const end = Math.min(entries.length, userIndex + 3);
    const neighbors = entries.slice(start, end);

    return { rank, score, neighbors, totalCount: entries.length };
  });

  // Admin: Liderlik tablolarını geriye dönük doldurma (backfill)
exports.adminBackfillLeaderboard = onCall({region: 'us-central1', timeoutSeconds: 540, enforceAppCheck: true}, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
    const isAdmin = request.auth.token && request.auth.token.admin === true;
    if (!isAdmin) throw new HttpsError('permission-denied', 'Admin gerekli');

    const kindsReq = request.data?.period;
    const kinds = kindsReq === 'daily' ? ['daily'] : (kindsReq === 'weekly' ? ['weekly'] : ['daily','weekly']);
    const pageSize = Math.min(1000, Math.max(50, Number(request.data?.pageSize || 500)));
    const startAfterId = typeof request.data?.startAfter === 'string' ? request.data.startAfter : null;
    const dryRun = !!request.data?.dryRun;

    let q = db.collection('users').orderBy(admin.firestore.FieldPath.documentId());
    if (startAfterId) q = q.startAfter(startAfterId);
    const snap = await q.limit(pageSize).get();
    if (snap.empty) return { processed: 0, done: true };

    const examsTouched = new Set();
    let processed = 0;
    for (const doc of snap.docs) {
      const uid = doc.id; const u = doc.data() || {};
      const examType = u.selectedExam || null; if (!examType) continue;
      try {
        const stats = await db.collection('users').doc(uid).collection('state').doc('stats').get();
        const s = stats.exists ? (stats.data() || {}) : {};
        const score = typeof s.engagementScore === 'number' ? s.engagementScore : 0;
        if (!dryRun) {
          await setLeaderboardScoreAbsolute({ examType, uid, score, userDocData: u, kinds });
        }
        examsTouched.add(String(examType));
        processed++;
      } catch (e) {
        logger.warn('Backfill user failed', { uid, error: String(e) });
      }
    }

    if (!dryRun) {
      for (const ex of examsTouched) {
        if (kinds.includes('daily')) await publishTopFor(ex, 'daily');
        if (kinds.includes('weekly')) await publishTopFor(ex, 'weekly');
      }
    }

    const lastId = snap.docs[snap.docs.length - 1].id;
    return { processed, nextPageToken: lastId, exams: Array.from(examsTouched), dryRun };
  });

module.exports = {
    ...exports,
    upsertLeaderboardScore,
}
