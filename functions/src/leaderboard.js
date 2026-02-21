const { onDocumentWritten, onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const { db, admin } = require("./init");
const { weekKeyIstanbul, dayKeyIstanbul } = require("./utils");
const { updatePublicProfile } = require("./profile");

// ==== Liderlik Tabloları: Yardımcılar ====

async function upsertLeaderboardExam(examType) {
  if (!examType) return;
  try {
    await db.collection("leaderboard_exams").doc(String(examType)).set({ exists: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  } catch (_) {}
}

async function upsertLeaderboardScore({ examType, uid, delta, userDocData }) {
  if (!examType || !uid || !(delta > 0)) return;
  const dayKey = dayKeyIstanbul();
  const weekKey = weekKeyIstanbul();
  const base = db.collection("leaderboard_scores").doc(examType);
  const dailyRef = base.collection("daily").doc(dayKey).collection("users").doc(uid);
  const weeklyRef = base.collection("weekly").doc(weekKey).collection("users").doc(uid);
  const safeName = userDocData?.name || "";
  const username = userDocData?.username || "";
  const avatarStyle = userDocData?.avatarStyle || null;
  const avatarSeed = userDocData?.avatarSeed || null;
  const payload = {
    userId: uid,
    userName: safeName,
    username: username,
    avatarStyle,
    avatarSeed,
    score: admin.firestore.FieldValue.increment(delta),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await Promise.all([
    dailyRef.set(payload, { merge: true }),
    weeklyRef.set(payload, { merge: true }),
    upsertLeaderboardExam(examType),
  ]);
}

// Yeni: Skoru mutlak değerle yazan yardımcı (backfill için)
async function setLeaderboardScoreAbsolute({ examType, uid, score, userDocData, kinds = ["daily", "weekly"] }) {
  if (!examType || !uid) return;
  const safeScore = Number.isFinite(score) ? Number(score) : 0;
  const dayKey = dayKeyIstanbul();
  const weekKey = weekKeyIstanbul();
  const base = db.collection("leaderboard_scores").doc(String(examType));
  const dailyRef = base.collection("daily").doc(dayKey).collection("users").doc(uid);
  const username = userDocData?.username || "";
  const weeklyRef = base.collection("weekly").doc(weekKey).collection("users").doc(uid);
  const safeName = userDocData?.name || "";
  const avatarStyle = userDocData?.avatarStyle || null;
  const avatarSeed = userDocData?.avatarSeed || null;
  const payload = {
    username: username,
    userId: uid,
    userName: safeName,
    avatarStyle,
    avatarSeed,
    score: safeScore,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  const writes = [];
  if (kinds.includes("daily")) writes.push(dailyRef.set(payload, { merge: true }));
  if (kinds.includes("weekly")) writes.push(weeklyRef.set(payload, { merge: true }));
  writes.push(upsertLeaderboardExam(examType));
  await Promise.all(writes);
}

// YENİ: Genişletilmiş ve optimize edilmiş anlık görüntü yayıncısı
async function publishLeaderboardSnapshot(examType, kind, limit = 200) {
  const container = db.collection("leaderboard_scores").doc(examType).collection(kind);
  const periodId = kind === "daily" ? dayKeyIstanbul() : weekKeyIstanbul();
  const usersCol = container.doc(periodId).collection("users");

  // Top 200 kullanıcıyı çek
  const qs = await usersCol.orderBy("score", "desc").limit(limit).get();
  if (qs.empty) {
    // Eğer hiç kullanıcı yoksa, eski snapshot'ı temizle
    const snapshotRef = db.collection("leaderboard_snapshots").doc(`${examType}_${kind}`);
    await snapshotRef.delete().catch(() => {}); // Hata durumunda devam et
    return;
  }

  // Kullanıcıların isPremium bilgilerini toplu olarak al
  const userIds = qs.docs.map(d => d.data()?.userId || d.id);
  const userRefs = userIds.map(uid => db.collection("users").doc(uid));
  const userSnaps = await db.getAll(...userRefs, { fieldMask: ['isPremium'] });
  const premiumMap = {};
  userSnaps.forEach(snap => {
    if (snap.exists) {
      premiumMap[snap.id] = snap.data().isPremium === true;
    }
  });

  const entries = qs.docs.map((d, index) => {
    const x = d.data() || {};
    const userId = x.userId || d.id;
    return {
      userId: userId,
      userName: x.userName || "",
      username: x.username || "",
      score: typeof x.score === "number" ? x.score : 0,
      rank: index + 1, // Sıralamayı doğrudan ekle
      avatarStyle: x.avatarStyle || null,
      avatarSeed: x.avatarSeed || null,
      isPremium: premiumMap[userId] || false,
    };
  });

  const snapshotRef = db.collection("leaderboard_snapshots").doc(`${examType}_${kind}`);
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
  const topRef = db.collection("leaderboard_top").doc(examType).collection(kind).doc("latest");
  await topRef.set({ entries: top20, updatedAt: admin.firestore.FieldValue.serverTimestamp(), periodId }, { merge: true });
}

async function cleanupOldLeaderboards() {
  const today = dayKeyIstanbul();
  const thisWeek = weekKeyIstanbul();
  // Temizleme: leaderboard_scores günlük (dünkü ve öncesi) ve haftalık (geçen hafta ve öncesi)
  const examsSnap = await db.collection("leaderboard_exams").get();
  for (const ex of examsSnap.docs) {
    const examType = ex.id;
    // Daily
    const dailyColl = db.collection("leaderboard_scores").doc(examType).collection("daily");
    const oldDaily = await dailyColl.where(admin.firestore.FieldPath.documentId(), "<", today).limit(10).get();
    for (const d of oldDaily.docs) {
      // Silmeden önce alt koleksiyon kullanıcılarını parti parti temizle
      const usersCol = d.ref.collection("users");
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
    const weeklyColl = db.collection("leaderboard_scores").doc(examType).collection("weekly");
    const oldWeekly = await weeklyColl.where(admin.firestore.FieldPath.documentId(), "<", thisWeek).limit(5).get();
    for (const w of oldWeekly.docs) {
      const usersCol = w.ref.collection("users");
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
    const topDaily = db.collection("leaderboard_top").doc(examType).collection("daily");
    const td = await topDaily.where(admin.firestore.FieldPath.documentId(), "!=", "latest").limit(20).get();
    for (const d of td.docs) {
      if (d.id < today) await d.ref.delete().catch(()=>{});
    }
    const topWeekly = db.collection("leaderboard_top").doc(examType).collection("weekly");
    const tw = await topWeekly.where(admin.firestore.FieldPath.documentId(), "!=", "latest").limit(20).get();
    for (const w of tw.docs) {
      if (w.id < thisWeek) await w.ref.delete().catch(()=>{});
    }
  }
}

// ==== Stats tetikleyicisi: günlük/haftalık skorları türet ve public profile güncelle ====
exports.onUserStatsWritten = onDocumentWritten({
  document: "users/{userId}/state/stats",
  region: "us-central1",
}, async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  const uid = event.params.userId;
  try {
    const prev = typeof before.engagementScore === "number" ? before.engagementScore : 0;
    const curr = typeof after.engagementScore === "number" ? after.engagementScore : 0;
    const delta = Math.max(0, curr - prev);
    // Kullanıcının examType'ını oku
    const userSnap = await db.collection("users").doc(uid).get();
    const examType = (userSnap.data() || {}).selectedExam || null;
    if (delta > 0 && examType) {
      await upsertLeaderboardScore({ examType, uid, delta, userDocData: userSnap.data() || {} });
    }
    // Public profile'ı güncelle
    await updatePublicProfile(uid);
  } catch (e) {
    logger.error("onUserStatsWritten failed", { uid, error: String(e) });
  }
});

// Kullanıcı profil güncellemesi: public_profile yansıt
// Kullanıcı profil güncellemesi: İsim ve avatar değişikliklerini liderlik tablosuna yansıtır
exports.onUserProfileChanged = onDocumentWritten({
  document: "users/{userId}",
  region: "us-central1",
}, async (event) => {
  const uid = event.params.userId;
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};

  try {
    // 1. Public profile senkronu (Her zaman çalışmalı)
    await updatePublicProfile(uid);

    const newExam = after?.selectedExam || null;
    const name = after?.name || "";
    const username = after?.username || "";
    const avatarStyle = after?.avatarStyle || null;
    const avatarSeed = after?.avatarSeed || null;

    // Sınav türü seçili değilse işlem yapma
    if (!newExam) return;

    // 2. Liderlik Tablosu Senkronizasyonu (Sadece Metadata)
    // KRİTİK DÜZELTME: Buradan 'score' alanını kaldırdık.
    // Puanlar sadece 'onUserStatsWritten' trigger'ı ile güncellenir.
    // Burada sadece kullanıcının adı, kullanıcı adı ve avatarı değişirse tabloda güncelliyoruz.

    const dayKey = dayKeyIstanbul();
    const weekKey = weekKeyIstanbul();
    const base = db.collection("leaderboard_scores").doc(String(newExam));

    await Promise.all([
      // Günlük Tabloda İsim/Username/Avatar Güncelle
      base.collection("daily").doc(dayKey).collection("users").doc(uid).set({
        userId: uid,
        userName: name,
        username: username,
        avatarStyle,
        avatarSeed,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true }),

      // Haftalık Tabloda İsim/Username/Avatar Güncelle
      base.collection("weekly").doc(weekKey).collection("users").doc(uid).set({
        userId: uid,
        userName: name,
        username: username,
        avatarStyle,
        avatarSeed,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true }),
    ]);

    // Not: Eski sınavdan silme işlemi (garbage collection) günlük temizlik fonksiyonuna bırakılmıştır.
    // Anlık silme işlemi, çok fazla write operasyonu yarattığı için kaldırıldı.

  } catch (e) {
    logger.warn("onUserProfileChanged sync failed", { uid, error: String(e) });
  }
});

// YENİ: Zamanlanmış: Saatte bir anlık görüntüleri yayınla
exports.publishLeaderboardSnapshots = onSchedule({ schedule: "0 * * * *", timeZone: "Europe/Istanbul" }, async () => {
  const examsSnap = await db.collection("leaderboard_exams").get();
  if (examsSnap.empty) {
    logger.info("publishLeaderboardSnapshots: No exams found to process.");
    return;
  }
  const jobs = [];
  for (const ex of examsSnap.docs) {
    const examType = ex.id;
    // Her sınav türü için günlük ve haftalık anlık görüntüleri oluştur
    jobs.push(publishLeaderboardSnapshot(examType, "daily"));
    jobs.push(publishLeaderboardSnapshot(examType, "weekly"));
  }
  await Promise.all(jobs);
  logger.info(`publishLeaderboardSnapshots completed for ${examsSnap.size} exams.`);
});

// ==== Zamanlanmış: Günlük temizlik ====
exports.cleanupLeaderboards = onSchedule({ schedule: "30 3 * * *", timeZone: "Europe/Istanbul" }, async () => {
  await cleanupOldLeaderboards();
  logger.info("cleanupLeaderboards completed");
});

module.exports = {
  ...exports,
  upsertLeaderboardScore,
};