const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const { db } = require("./init");

// Kullanıcının ana profil dokümanı değiştiğinde tetiklenir
exports.onUserUpdated = onDocumentWritten("users/{uid}", async (event) => {
  const uid = event.params.uid;
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  if (!afterData) {
    // Kullanıcı silindi, context'i de silebiliriz (opsiyonel)
    const contextRef = db.collection("users").doc(uid).collection("state").doc("notification_context");
    await contextRef.delete();
    logger.info(`Notification context deleted for user ${uid}`);
    return;
  }

  const updates = {};
  const isPremiumBefore = !!beforeData?.isPremium;
  const isPremiumAfter = !!afterData.isPremium;
  if (isPremiumBefore !== isPremiumAfter) {
    updates.isPremium = isPremiumAfter;
  }

  const selectedExamBefore = beforeData?.selectedExam || null;
  const selectedExamAfter = afterData.selectedExam || null;
  if (selectedExamBefore !== selectedExamAfter) {
    updates.selectedExam = selectedExamAfter;
  }

  if (Object.keys(updates).length > 0) {
    const contextRef = db.collection("users").doc(uid).collection("state").doc("notification_context");
    await contextRef.set(updates, { merge: true });
    logger.info(`Notification context updated for user ${uid} from user profile`, { updates });
  }
});

// Kullanıcının performans özeti değiştiğinde tetiklenir
exports.onPerformanceSummaryUpdated = onDocumentWritten("users/{uid}/performance/summary", async (event) => {
  const uid = event.params.uid;
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  if (!afterData) return; // Summary silinirse bir şey yapma

  const updates = {};
  const weakestSubjectBefore = beforeData?.weakestSubject || null;
  const weakestSubjectAfter = afterData.weakestSubject || null;
  if (weakestSubjectBefore !== weakestSubjectAfter) {
    updates.weakestSubject = weakestSubjectAfter;
  }

  if (Object.keys(updates).length > 0) {
    const contextRef = db.collection("users").doc(uid).collection("state").doc("notification_context");
    await contextRef.set(updates, { merge: true });
    logger.info(`Notification context updated for user ${uid} from performance summary`, { updates });
  }
});


// Kullanıcının istatistikleri (seri vb.) değiştiğinde tetiklenir
exports.onStatsUpdated = onDocumentWritten("users/{uid}/state/stats", async (event) => {
  const uid = event.params.uid;
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  if (!afterData) return;

  const updates = {};
  const streakBefore = beforeData?.streak || 0;
  const streakAfter = afterData.streak || 0;
  if (streakBefore !== streakAfter) {
    updates.streak = streakAfter;
  }

  const lostStreakBefore = !!beforeData?.lostStreak;
  const lostStreakAfter = !!afterData.lostStreak;
  if (lostStreakBefore !== lostStreakAfter) {
    updates.lostStreak = lostStreakAfter;
  }

  if (Object.keys(updates).length > 0) {
    const contextRef = db.collection("users").doc(uid).collection("state").doc("notification_context");
    await contextRef.set(updates, { merge: true });
    logger.info(`Notification context updated for user ${uid} from stats`, { updates });
  }
});


// Kullanıcının uygulama durumu (son aktif olma) değiştiğinde tetiklenir
exports.onAppStateUpdated = onDocumentWritten("users/{uid}/state/app_state", async (event) => {
  const uid = event.params.uid;
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  if (!afterData) return;

  const updates = {};
  const lastActiveTsBefore = beforeData?.lastActiveTs || 0;
  const lastActiveTsAfter = afterData.lastActiveTs || 0;

  // Sadece anlamlı bir değişiklik varsa güncelle (örneğin 5 dakikadan fazla)
  if (Math.abs(lastActiveTsAfter - lastActiveTsBefore) > 5 * 60 * 1000) {
    updates.lastActiveTs = lastActiveTsAfter;
  }

  if (Object.keys(updates).length > 0) {
    const contextRef = db.collection("users").doc(uid).collection("state").doc("notification_context");
    await contextRef.set(updates, { merge: true });
    logger.info(`Notification context updated for user ${uid} from app_state`, { updates });
  }
});
