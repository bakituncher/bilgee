const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { db, admin } = require("./init");
const { nowIstanbul, computeTestAggregates, enforceRateLimit, enforceDailyQuota, getClientIpFromRawRequest, isBranchTest } = require("./utils");
const { updatePublicProfile } = require("./profile");

exports.addEngagementPoints = onCall({ region: "us-central1", enforceAppCheck: true, maxInstances: 20 }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const uid = request.auth.uid;

  // Rate limit + günlük kota (istismar önleme)
  const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
  await Promise.all([
    enforceRateLimit(`eng_points_uid_${uid}`, 60, 10),
    enforceRateLimit(`eng_points_ip_${ip}`, 60, 60),
    enforceDailyQuota(`eng_points_daily_${uid}`, 500),
  ]);

  const deltaRaw = request.data && request.data.pointsToAdd;
  const delta = typeof deltaRaw === "number" ? Math.floor(deltaRaw) : parseInt(String(deltaRaw || "0"), 10);
  if (!Number.isFinite(delta) || delta <= 0 || delta > 100000) {
    throw new HttpsError("invalid-argument", "pointsToAdd pozitif bir tam sayı olmalı");
  }

  const userRef = db.collection("users").doc(uid);
  const statsRef = userRef.collection("state").doc("stats");

  // Transaction içinde sadece kullanıcının puanını artırıyoruz.
  // Liderlik tablosu güncellemesini leaderboard.js'deki onUserStatsWritten trigger yapacak.
  await db.runTransaction(async (tx) => {
    const [uSnap] = await Promise.all([tx.get(userRef)]);
    if (!uSnap.exists) throw new HttpsError("failed-precondition", "Kullanıcı bulunamadı");

    tx.set(statsRef, {
      engagementScore: admin.firestore.FieldValue.increment(delta),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  // Manuel leaderboard güncellemeleri kaldırıldı - trigger tarafından yapılacak

  await updatePublicProfile(uid).catch(() => { });
  return { ok: true, added: delta };
});

exports.addTestResult = onCall({ region: "us-central1", timeoutSeconds: 30, enforceAppCheck: true, maxInstances: 20 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Oturum gerekli");
  }
  const uid = request.auth.uid;
  const input = request.data || {};

  // Rate limit + günlük kota
  const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
  await Promise.all([
    enforceRateLimit(`add_test_uid_${uid}`, 60, 5),
    enforceRateLimit(`add_test_ip_${ip}`, 60, 30),
    enforceDailyQuota(`tests_submit_${uid}`, 200),
  ]);

  // Sade log: sadece gerekli alanlar
  try {
    const logSafe = {
      uid,
      testName: String(input.testName || "").slice(0, 64),
      examType: String(input.examType || "").slice(0, 32),
      sectionName: String(input.sectionName || "").slice(0, 32),
      dateMs: Number.isFinite(input.dateMs) ? Number(input.dateMs) : null,
      scoresKeys: input && input.scores ? Object.keys(input.scores).slice(0, 20) : [],
    };
    logger.info("[addTestResult] incoming", logSafe);
  } catch (_) {/* ignore logging errors */}

  try {
    const testName = String(input.testName || "").trim();
    const examTypeParam = String(input.examType || "").trim();
    const sectionName = String(input.sectionName || "").trim();
    const dateMs = Number.isFinite(input.dateMs) ? Number(input.dateMs) : null;
    if (!testName) throw new HttpsError("invalid-argument", "testName gerekli");
    if (!examTypeParam) throw new HttpsError("invalid-argument", "examType gerekli");
    if (!sectionName) throw new HttpsError("invalid-argument", "sectionName gerekli");

    const { normalizedScores, totalCorrect, totalWrong, totalBlank, totalQuestions, totalNet, penaltyCoefficient } = await computeTestAggregates(input);

    const userRef = db.collection("users").doc(uid);
    const statsRef = userRef.collection("state").doc("stats");
    const testsCol = db.collection("tests");

    let newTestId = null;
    const pointsAward = 50;

    await db.runTransaction(async (tx) => {
      // Önce tüm okuma işlemleri
      const [uSnap, sSnap, questsSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(statsRef),
        tx.get(userRef.collection("daily_quests").where("isCompleted", "==", false)),
      ]);

      if (!uSnap.exists) throw new HttpsError("failed-precondition", "Kullanıcı yok");
      const userDocData = uSnap.data() || {};
      const examType = ((userDocData && userDocData.selectedExam) || examTypeParam || "").toString();

      const stats = sSnap.exists ? (sSnap.data() || {}) : {};
      const lastTs = stats.lastStreakUpdate; // beklenen Timestamp
      const currentStreak = typeof stats.streak === "number" ? stats.streak : 0;

      const now = nowIstanbul();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      let newStreak = 1;
      if (lastTs && typeof lastTs.toDate === "function") {
        const lastDate = lastTs.toDate();
        const lastDay = new Date(lastDate.getFullYear(), lastDate.getMonth(), lastDate.getDate());
        if (lastDay.getTime() === today.getTime()) {
          newStreak = currentStreak; // aynı gün
        } else {
          const y = new Date(today);
          y.setDate(today.getDate() - 1);
          newStreak = (lastDay.getTime() === y.getTime()) ? currentStreak + 1 : 1;
        }
      }

      // Branş denemesi kontrolü
      const isTestBranch = isBranchTest(normalizedScores, sectionName, examType);

      // Şimdi tüm yazma işlemleri
      const newDocRef = testsCol.doc();
      newTestId = newDocRef.id;
      const testDate = dateMs && Number.isFinite(dateMs) ? admin.firestore.Timestamp.fromMillis(dateMs) : admin.firestore.Timestamp.now();
      tx.set(newDocRef, {
        userId: uid,
        testName,
        examType,
        sectionName,
        date: testDate,
        scores: normalizedScores,
        totalNet,
        totalQuestions,
        totalCorrect,
        totalWrong,
        totalBlank,
        penaltyCoefficient,
        isBranchTest: isTestBranch,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // İstatistikleri güncelle (onUserStatsWritten trigger'ı buradan tetiklenecek)
      // testCount ve totalNetSum sadece ana sınav denemeleri için artırılır (branş denemeleri hariç)
      const statsUpdate = {
        streak: newStreak,
        lastStreakUpdate: admin.firestore.Timestamp.fromDate(today),
        engagementScore: admin.firestore.FieldValue.increment(pointsAward),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Sadece ana sınav denemelerinde testCount ve totalNetSum'ı artır
      if (!isTestBranch) {
        statsUpdate.testCount = admin.firestore.FieldValue.increment(1);
        statsUpdate.totalNetSum = admin.firestore.FieldValue.increment(totalNet);
      }

      tx.set(statsRef, statsUpdate, { merge: true });

      if (!questsSnap.empty) {
        for (const doc of questsSnap.docs) {
          const quest = doc.data();
          if (quest.category === "practice" || quest.category === "test_submission") {
            tx.update(doc.ref, {
              currentProgress: admin.firestore.FieldValue.increment(totalQuestions),
            });
          }
          if (quest.id === "daily_tes_01_result_entry") {
            tx.update(doc.ref, {
              currentProgress: admin.firestore.FieldValue.increment(1),
            });
          }
        }
      }
    });

    // Manuel leaderboard güncellemeleri kaldırıldı - onUserStatsWritten trigger'ı yapacak

    await updatePublicProfile(uid).catch(() => { });
    return { ok: true, testId: newTestId, awarded: pointsAward };
  } catch (error) {
    logger.error("[addTestResult] error", {
      uid,
      message: error.message,
      code: error.code,
    });
    throw error;
  }
});
