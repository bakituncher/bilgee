const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { db } = require("./init");
const { dayKeyIstanbul, nowIstanbul, enforceRateLimit, enforceDailyQuota, getClientIpFromRawRequest } = require("./utils");

/**
 * Deletes all data for a user when they reset their profile for a new exam.
 * This is a critical, multi-step operation handled by a callable function
 * to ensure atomicity and prevent data inconsistencies.
 */
const resetUserDataForNewExam = onCall({ region: "us-central1", timeoutSeconds: 300, enforceAppCheck: true, maxInstances: 10 }, async (request) => {
  if (!request.auth) {
    throw new Error("The function must be called while authenticated.");
  }
  const userId = request.auth.uid;

  // Rate limit ve günlük kota: suistimali önlemek için
  const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
  await Promise.all([
    enforceRateLimit(`reset_user_uid_${userId}`, 60, 2),
    enforceRateLimit(`reset_user_ip_${ip}`, 60, 10),
    enforceDailyQuota(`reset_user_daily_${userId}`, 2),
  ]);

  try {
    // 0.1) Kullanıcının varlığını kontrol et
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new Error("User document not found");
    }

    // 0.2) Rate limiting kontrolü (son 24 saatte kaç kez çağrıldı?)
    const resetLogRef = db.collection("reset_logs").doc(userId);
    const resetLog = await resetLogRef.get();

    if (resetLog.exists) {
      const lastReset = resetLog.data()?.lastReset;
      if (lastReset && (Date.now() - lastReset.toMillis()) < 24 * 60 * 60 * 1000) {
        throw new Error("Reset can only be performed once per 24 hours");
      }
    }

    // 0.3) Reset log'u güncelle
    await resetLogRef.set({
      lastReset: admin.firestore.FieldValue.serverTimestamp(),
      userId: userId,
    }, { merge: true });

    // 0) Helper: delete query in batches (top-level collections)
    async function deleteQueryInBatches(query, batchSize = 300) {
      // Loop until no docs left
      // Each iteration loads up to batchSize docs and deletes them in a write batch
      // to avoid timeouts and write limits.

      while (true) {
        const snap = await query.limit(batchSize).get();
        if (snap.empty) break;
        const batch = db.batch();
        snap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        // Small delay to yield
        await new Promise((r) => setTimeout(r, 25));
      }
    }

    // 1) Reset main user document fields and core state via a batch
    const userDocRef = db.collection("users").doc(userId);
    const batch1 = db.batch();
    batch1.update(userDocRef, {
      tutorialCompleted: false,
      selectedExam: null,
      selectedExamSection: null,
      weeklyAvailability: {},
      goal: null,
      challenges: [],
      weeklyStudyGoal: null,
    });

    // 2) Reset stats, performance, and plan documents
    const statsRef = userDocRef.collection("state").doc("stats");
    batch1.set(statsRef, {
      streak: 0,
      lastStreakUpdate: null,
      testCount: 0,
      totalNetSum: 0.0,
      engagementScore: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const performanceDocRef = userDocRef.collection("performance").doc("summary");
    batch1.set(performanceDocRef, {
      netGains: {}, lastTenNetAvgs: [], lastTenWarriorScores: [],
      masteredTopics: [], recentPerformance: {}, strongestSubject: null,
      strongestTopic: null, totalCorrect: 0, totalIncorrect: 0,
      totalNet: 0.0, totalTests: 0, weakestSubject: null, weakestTopic: null,
    }, { merge: true });

    const planDocRef = userDocRef.collection("plans").doc("current_plan");
    batch1.set(planDocRef, { studyPacing: "balanced", weeklyPlan: {} }, { merge: true });

    // Commit the initial resets (this will also trigger onUserUpdate to clean leaderboards)
    await batch1.commit();

    // 3) Delete all documents in subcollections under the user (iterate until empty)
    async function deleteAllDocsInSubcollection(path) {
      // path example: users/{userId}/topic_performance

      while (true) {
        const snap = await db.collection(path).limit(300).get();
        if (snap.empty) break;
        const batch = db.batch();
        snap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        await new Promise((r) => setTimeout(r, 25));
      }
    }

    // These subcollections exist under the user document
    const subcollections = [
      `users/${userId}/user_activity`,
      `users/${userId}/topic_performance`,
      `users/${userId}/savedWorkshops`,
      `users/${userId}/daily_quests`, // Görevler sınav değiştiğinde silinir
    ];

    for (const sub of subcollections) {
      await deleteAllDocsInSubcollection(sub);
    }

    // masteredTopics is a subcollection of the performance doc
    await deleteAllDocsInSubcollection(`users/${userId}/performance/summary/masteredTopics`);

    // 4) Delete top-level collections filtered by userId (true data locations)
    await deleteQueryInBatches(db.collection("tests").where("userId", "==", userId));
    await deleteQueryInBatches(db.collection("focusSessions").where("userId", "==", userId));

    // Done - başarı loglaması
    console.log(`User data reset completed for ${userId}`);
    return { success: true, message: `User data for ${userId} has been reset.`, timestamp: Date.now() };
  } catch (error) {
    console.error(`Reset failed for user ${userId}:`, error);
    throw new Error(`Reset operation failed: ${error.message}`);
  }
});

async function computeInactivityHours(userRef) {
  // user_activity bugun ve dunden kontrol edilir; yoksa app_state.lastActiveTs kullan
  try {
    const now = nowIstanbul();
    const ids = [];
    const today = dayKeyIstanbul(now);
    const y = new Date(now);
    y.setDate(now.getDate() - 1);
    const yesterday = dayKeyIstanbul(y);
    ids.push(today, yesterday);
    let lastTs = 0;
    for (const id of ids) {
      const snap = await userRef.collection("user_activity").doc(id).get();
      if (snap.exists) {
        const data = snap.data() || {};
        const visits = Array.isArray(data.visits) ? data.visits : [];
        for (const v of visits) {
          const t = typeof v === "number" ? v : (v && (v.ts || v.t)) || 0;
          if (typeof t === "number" && t > lastTs) lastTs = t;
        }
      }
    }
    if (lastTs === 0) {
      const app = await userRef.collection("state").doc("app_state").get();
      const t = app.exists ? (app.data() || {}).lastActiveTs : 0;
      if (typeof t === "number") lastTs = t;
    }
    if (lastTs === 0) return 1e6; // bilinmiyorsa çok uzun kabul et
    const diffMs = now.getTime() - lastTs;
    return Math.max(0, Math.floor(diffMs / (1000 * 60 * 60)));
  } catch (_) {
    return 1e6;
  }
}

async function selectAudienceUids(audience) {
  let query = db.collection("users");
  const lc = (s) => (typeof s === "string" ? s.toLowerCase() : s);
  if (audience && audience.type === "exam" && audience.examType) {
    const exam = lc(audience.examType);
    query = query.where("selectedExam", "==", exam);
    const snap = await query.select().limit(20000).get();
    return snap.docs.map((d) => d.id);
  }
  if (audience && audience.type === "exams" && Array.isArray(audience.exams) && audience.exams.length > 0) {
    const exams = audience.exams.filter((x) => typeof x === "string").map((s) => s.toLowerCase());
    if (exams.length === 0) {
      const snap = await db.collection("users").select().limit(20000).get();
      return snap.docs.map((d) => d.id);
    }
    if (exams.length <= 10) {
      const snap = await db.collection("users").where("selectedExam", "in", exams).select().limit(20000).get();
      return snap.docs.map((d) => d.id);
    }
    // 10'dan fazlaysa basit filtreleme (tüm kullanıcıları çekip bellekte filtreleyin)
    const all = await db.collection("users").select("selectedExam").limit(20000).get();
    return all.docs.filter((d) => exams.includes((d.data() || {}).selectedExam)).map((d) => d.id);
  }
  if (audience && audience.type === "uids" && Array.isArray(audience.uids)) {
    return audience.uids.filter((x) => typeof x === "string");
  }
  const snap = await query.select().limit(20000).get();
  return snap.docs.map((d) => d.id);
}

module.exports = {
  computeInactivityHours,
  selectAudienceUids,
  resetUserDataForNewExam,
};
