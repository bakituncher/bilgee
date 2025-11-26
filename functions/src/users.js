const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { logger } = require("firebase-functions");
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
  // Önce app_state.lastActiveTs'ye bak (en güvenilir kaynak)
  // Yoksa user_activity bugün ve dünü kontrol et
  try {
    const now = nowIstanbul();
    let lastTs = 0;

    // 1. Öncelik: app_state.lastActiveTs (Flutter tarafında her ziyarette güncelleniyor)
    const appStateSnap = await userRef.collection("state").doc("app_state").get();
    if (appStateSnap.exists) {
      const appData = appStateSnap.data() || {};
      const t = typeof appData.lastActiveTs === "number" ? appData.lastActiveTs : 0;
      if (t > 0) lastTs = t;
    }

    // 2. Yedek: user_activity/visits alt koleksiyonuna bak (bugün ve dün)
    if (lastTs === 0) {
      const today = dayKeyIstanbul(now);
      const y = new Date(now);
      y.setDate(now.getDate() - 1);
      const yesterday = dayKeyIstanbul(y);

      for (const dayId of [today, yesterday]) {
        // visits alt koleksiyonundan son ziyareti oku
        const visitsSnap = await userRef
          .collection("user_activity")
          .doc(dayId)
          .collection("visits")
          .orderBy("visitTime", "desc")
          .limit(1)
          .get();

        if (!visitsSnap.empty) {
          const visitDoc = visitsSnap.docs[0];
          const visitData = visitDoc.data() || {};
          const vt = visitData.visitTime;
          // Firestore Timestamp veya number olabilir
          const t = typeof vt === "object" && vt._seconds
            ? vt._seconds * 1000
            : typeof vt === "number" ? vt : 0;
          if (t > lastTs) lastTs = t;
        }
      }
    }

    // 3. Hiçbir kayıt bulunamadıysa çok uzun süre inaktif kabul et
    if (lastTs === 0) return 999999; // ~114 yıl (çok uzun süre)

    const diffMs = now.getTime() - lastTs;
    return Math.max(0, Math.floor(diffMs / (1000 * 60 * 60)));
  } catch (err) {
    logger.error("computeInactivityHours failed", { error: String(err) });
    return 999999;
  }
}

/**
 * Kullanıcıları 1000'erli gruplar halinde çeker ve işleyici fonksiyonuna gönderir.
 * Bu yöntem OOM (Bellek Taşması) hatasını önler.
 *
 * @param {Object} audience - Hedef kitle kriterleri
 * @param {Function} batchCallback - Her 1000 kişilik UID grubu için çalışacak asenkron fonksiyon
 */
async function processAudienceInBatches(audience, batchCallback) {
  const BATCH_SIZE = 1000;
  // Sadece ID ve filtreleme alanlarını çekerek veriyi küçültüyoruz
  let query = db.collection("users").select("selectedExam");

  // --- Filtreleme Mantığı ---
  const lc = (s) => (typeof s === "string" ? s.toLowerCase() : s);

  // 1. Tekil Sınav Filtresi
  if (audience && audience.type === "exam" && audience.examType) {
    const exam = lc(audience.examType);
    query = query.where("selectedExam", "==", exam);
  }

  // 2. Çoğul Sınav Filtresi
  else if (audience && audience.type === "exams" && Array.isArray(audience.exams)) {
    const exams = audience.exams.filter((x) => typeof x === "string").map((s) => s.toLowerCase());
    if (exams.length > 0 && exams.length <= 10) {
      query = query.where("selectedExam", "in", exams);
    }
    // Not: 10'dan fazla sınav türü varsa 'in' sorgusu çalışmaz,
    // bu durumda client-side filtreleme veya batchCallback içinde kontrol gerekir.
  }
  // 3. Özel UID Listesi (Database sorgusu gerektirmez)
  else if (audience && audience.type === "uids" && Array.isArray(audience.uids)) {
    const cleanUids = audience.uids.filter((x) => typeof x === "string");
    for (let i = 0; i < cleanUids.length; i += BATCH_SIZE) {
      await batchCallback(cleanUids.slice(i, i + BATCH_SIZE));
    }
    return;
  }

  // --- Batch (Sayfalama) Döngüsü ---
  let lastDoc = null;
  let totalProcessed = 0;

  while (true) {
    let currentQuery = query.limit(BATCH_SIZE);

    // Bir önceki sayfanın son dökümanından sonrasını getir
    if (lastDoc) {
      currentQuery = currentQuery.startAfter(lastDoc);
    }

    const snapshot = await currentQuery.get();

    if (snapshot.empty) {
      break; // Veri bitti
    }

    // UID listesini oluştur
    const uids = snapshot.docs.map((doc) => doc.id);

    // İşleyiciye (callback) gönder (Örn: Push bildirimi at)
    if (uids.length > 0) {
      await batchCallback(uids);
    }

    totalProcessed += uids.length;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];

    // İşlemciyi boğmamak için kısa bir bekleme (Throttling)
    await new Promise((resolve) => setTimeout(resolve, 50));
  }

  console.log(`Batch işlemi tamamlandı. Toplam işlenen kullanıcı: ${totalProcessed}`);
}

module.exports = {
  computeInactivityHours,
  processAudienceInBatches,
  resetUserDataForNewExam,
};
