const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { db } = require("./init");
const { dayKeyIstanbul, nowIstanbul } = require("./utils");

/**
 * Deletes all data for a user when they reset their profile for a new exam.
 * This is a critical, multi-step operation handled by a callable function
 * to ensure atomicity and prevent data inconsistencies.
 */
const resetUserDataForNewExam = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }
  const userId = context.auth.uid;
  const batch = db.batch();

  // 1. Reset main user document fields
  const userDocRef = db.collection('users').doc(userId);
  batch.update(userDocRef, {
    tutorialCompleted: false,
    selectedExam: null,
    selectedExamSection: null,
    weeklyAvailability: {},
    goal: null,
    challenges: [],
    weeklyStudyGoal: null,
  });

  // 2. Reset stats, performance, and plan documents
  const statsRef = userDocRef.collection('state').doc('stats');
  batch.set(statsRef, {
    streak: 0,
    lastStreakUpdate: null,
    testCount: 0,
    totalNetSum: 0.0,
    engagementScore: 0,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  const performanceDocRef = userDocRef.collection('performance').doc('summary');
  batch.set(performanceDocRef, {
      netGains: {}, lastTenNetAvgs: [], lastTenWarriorScores: [],
      masteredTopics: [], recentPerformance: {}, strongestSubject: null,
      strongestTopic: null, totalCorrect: 0, totalIncorrect: 0,
      totalNet: 0.0, totalTests: 0, weakestSubject: null, weakestTopic: null,
  });

  const planDocRef = userDocRef.collection('plans').doc('current_plan');
  batch.set(planDocRef, { studyPacing: 'balanced', weeklyPlan: {} });

  // 3. Delete all documents in subcollections
  const subcollections = [
    'tests', 'focusSessions', 'user_activity',
    'topic_performance', 'savedWorkshops'
  ];

  for (const collectionName of subcollections) {
    const snapshot = await db.collection('users').doc(userId).collection(collectionName).limit(500).get();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
  }

  const masteredTopicsSnap = await performanceDocRef.collection('masteredTopics').limit(500).get();
  masteredTopicsSnap.docs.forEach(doc => batch.delete(doc.ref));

  // 4. Commit the atomic batch
  try {
    await batch.commit();
    return { success: true, message: `User data for ${userId} has been reset.` };
  } catch (error) {
    console.error(`Failed to reset data for user ${userId}`, error);
    throw new functions.https.HttpsError('internal', 'Failed to reset user data.', error);
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
