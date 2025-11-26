const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { logger } = require("firebase-functions");
const { db } = require("./init");
const { dayKeyIstanbul, nowIstanbul, enforceRateLimit, enforceDailyQuota, getClientIpFromRawRequest } = require("./utils");

// KALDIRILDI: resetUserDataForNewExam() - "Sınav Değiştir" özelliği kaldırıldı
// Artık sadece deleteUserAccount() kullanılıyor

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

/**
 * Kullanıcı hesabını kalıcı olarak siler.
 * TÜM Firestore verilerini ve Firebase Authentication kaydını siler.
 * Bu işlem GERİ ALINAMAZ!
 */
const deleteUserAccount = onCall({ region: "us-central1", timeoutSeconds: 540, enforceAppCheck: true, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new Error("The function must be called while authenticated.");
  }
  const userId = request.auth.uid;

  // Rate limit: Hesap silme için daha sıkı kontrol
  const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
  await Promise.all([
    enforceRateLimit(`delete_account_uid_${userId}`, 3600, 1), // Saatte 1 kez
    enforceRateLimit(`delete_account_ip_${ip}`, 3600, 3), // IP başına saatte 3 kez
  ]);

  try {
    logger.info(`Account deletion started for user: ${userId}`);

    // Helper: Batch silme fonksiyonu
    async function deleteQueryInBatches(query, batchSize = 300) {
      while (true) {
        const snap = await query.limit(batchSize).get();
        if (snap.empty) break;
        const batch = db.batch();
        snap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        await new Promise((r) => setTimeout(r, 25));
      }
    }

    // Helper: Alt koleksiyon silme
    async function deleteAllDocsInSubcollection(path) {
      while (true) {
        const snap = await db.collection(path).limit(300).get();
        if (snap.empty) break;
        const batch = db.batch();
        snap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        await new Promise((r) => setTimeout(r, 25));
      }
    }

    // 1) Kullanıcının alt koleksiyonlarını sil
    const subcollections = [
      `users/${userId}/state`,
      `users/${userId}/user_activity`,
      `users/${userId}/topic_performance`,
      `users/${userId}/savedWorkshops`,
      `users/${userId}/daily_quests`,
      `users/${userId}/performance`,
      `users/${userId}/plans`,
      `users/${userId}/devices`, // FCM token cihazları
      `users/${userId}/in_app_notifications`, // Uygulama içi bildirimler
    ];

    for (const sub of subcollections) {
      await deleteAllDocsInSubcollection(sub);
    }

    // masteredTopics alt koleksiyonu
    await deleteAllDocsInSubcollection(`users/${userId}/performance/summary/masteredTopics`);

    // 2) Kullanıcının user_activity alt dokümanlarının visits koleksiyonlarını sil
    const activitySnap = await db.collection(`users/${userId}/user_activity`).get();
    for (const activityDoc of activitySnap.docs) {
      await deleteAllDocsInSubcollection(`users/${userId}/user_activity/${activityDoc.id}/visits`);
    }

    // 3) Üst seviye koleksiyonlardaki kullanıcı verilerini sil
    await deleteQueryInBatches(db.collection("tests").where("userId", "==", userId));
    await deleteQueryInBatches(db.collection("focusSessions").where("userId", "==", userId));
    await deleteQueryInBatches(db.collection("posts").where("userId", "==", userId));
    await deleteQueryInBatches(db.collection("questionReports").where("userId", "==", userId));

    // 4) Liderlik tablolarından kullanıcıyı temizle
    const leaderboardsSnap = await db.collection("leaderboards").get();
    for (const leaderboardDoc of leaderboardsSnap.docs) {
      const userLeaderboardRef = leaderboardDoc.ref.collection("users").doc(userId);
      if ((await userLeaderboardRef.get()).exists) {
        await userLeaderboardRef.delete();
      }
    }

    // 5) Public profile'ı sil
    const publicProfileRef = db.collection("public_profiles").doc(userId);
    if ((await publicProfileRef.get()).exists) {
      await publicProfileRef.delete();
    }

    // 6) Reset ve deletion loglarını sil
    const resetLogRef = db.collection("reset_logs").doc(userId);
    if ((await resetLogRef.get()).exists) {
      await resetLogRef.delete();
    }

    // 7) Ana kullanıcı dokümanını sil
    await db.collection("users").doc(userId).delete();

    // 8) Firebase Authentication kaydını sil (EN SON ADIM)
    await admin.auth().deleteUser(userId);

    logger.info(`Account deletion completed successfully for user: ${userId}`);
    return {
      success: true,
      message: "Your account has been permanently deleted.",
      timestamp: Date.now()
    };
  } catch (error) {
    logger.error(`Account deletion failed for user ${userId}:`, error);
    throw new Error(`Account deletion failed: ${error.message}`);
  }
});

module.exports = {
  computeInactivityHours,
  processAudienceInBatches,
  deleteUserAccount,
};
