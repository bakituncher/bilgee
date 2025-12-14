const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { logger } = require("firebase-functions");
const { db } = require("./init");
const { dayKeyIstanbul, nowIstanbul, enforceRateLimit, enforceDailyQuota, getClientIpFromRawRequest } = require("./utils");
const { getFirestore } = require("firebase-admin/firestore");

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
 * TÜM Firestore verilerini, Storage dosyalarını ve Firebase Authentication kaydını siler.
 * Bu işlem GERİ ALINAMAZ!
 *
 * GÜNCELLENME TARİHİ: 2025-11-26
 * DEĞİŞİKLİKLER:
 * - ✨ recursiveDelete() kullanımı: Alt koleksiyonlar otomatik olarak silinir
 * - Storage dosyaları eklendi (avatars, user_files)
 * - Takip sistemi temizliği eklendi (followers/following)
 * - Engelleme sistemi temizliği optimize edildi (performans güvenliği)
 * - Moderasyon kayıtları eklendi (user_reports, user_report_index)
 * - Analitik olaylar eklendi (analytics_events)
 * - Rate limit/quota kayıtları eklendi
 * - Push kampanya logları eklendi
 * - Geliştirilmiş hata yönetimi
 * - Detaylı loglama
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

  const deletionLog = {
    userId,
    startTime: Date.now(),
    steps: [],
    errors: []
  };

  try {
    logger.info(`Account deletion started for user: ${userId}`);

    // Helper: Batch silme fonksiyonu (üst seviye koleksiyonlar için)
    async function deleteQueryInBatches(query, batchSize = 300, stepName = "unknown") {
      try {
        let totalDeleted = 0;
        while (true) {
          const snap = await query.limit(batchSize).get();
          if (snap.empty) break;
          const batch = db.batch();
          snap.docs.forEach((doc) => batch.delete(doc.ref));
          await batch.commit();
          totalDeleted += snap.docs.length;
          await new Promise((r) => setTimeout(r, 25));
        }
        deletionLog.steps.push({ step: stepName, deleted: totalDeleted, status: "success" });
        logger.info(`${stepName}: ${totalDeleted} documents deleted`);
      } catch (error) {
        deletionLog.errors.push({ step: stepName, error: String(error) });
        logger.error(`${stepName} failed:`, error);
        // Devam et, tüm silme işlemini durdurmayalım
      }
    }


    // Helper: Storage klasörü silme
    async function deleteStorageFolder(path, stepName = path) {
      try {
        const bucket = admin.storage().bucket();
        const [files] = await bucket.getFiles({ prefix: path });
        let totalDeleted = 0;

        // Batch silme (her seferinde 100 dosya)
        for (let i = 0; i < files.length; i += 100) {
          const batch = files.slice(i, i + 100);
          await Promise.all(batch.map(file => file.delete().catch(e => {
            logger.warn(`Failed to delete file ${file.name}:`, e);
          })));
          totalDeleted += batch.length;
        }

        deletionLog.steps.push({ step: stepName, deleted: totalDeleted, status: "success" });
        logger.info(`${stepName}: ${totalDeleted} files deleted`);
      } catch (error) {
        deletionLog.errors.push({ step: stepName, error: String(error) });
        logger.error(`${stepName} failed:`, error);
      }
    }

    // === 1) ÜST SEVİYE KOLEKSİYONLARDAKİ KULLANICI VERİLERİNİ SİL (TAKİP/ENGELLEME TEMİZLİĞİ İÇİN) ===
    // Not: Kullanıcının ana dökümanını silmeden ÖNCE, diğer koleksiyonlardaki
    //      çapraz referansları temizlememiz gerekiyor
    await deleteQueryInBatches(db.collection("tests").where("userId", "==", userId), 300, "Tests collection");
    await deleteQueryInBatches(db.collection("focusSessions").where("userId", "==", userId), 300, "Focus sessions collection");
    await deleteQueryInBatches(db.collection("posts").where("userId", "==", userId), 300, "Posts collection");
    await deleteQueryInBatches(db.collection("questionReports").where("userId", "==", userId), 300, "Question reports collection");


    // === 4) TAKİP SİSTEMİ TEMİZLİĞİ (LAZY CLEANUP - PERFORMANS GÜVENLİĞİ) ===
    // ⚠️ ÖNCEKİ YÖNTEM:
    //    - Kullanıcının takip ettiklerinin followers listesinden sil (N okuma/yazma)
    //    - Kullanıcıyı takip edenlerin following listesinden sil (M okuma/yazma)
    //    Toplam: N + M işlem (50K takipçi = 50K+ işlem = timeout + OOM riski!)
    //
    // ✅ YENİ YAKLAŞIM: Lazy Cleanup
    //    1. Kullanıcının kendi followers/following koleksiyonları recursiveDelete ile silinecek
    //    2. Karşı taraftaki "zombi" referanslar kalabilir (örn: başkasının following'inde bu kullanıcı)
    //    3. UI tarafında profil görüntülenirken lazy cleanup yapılır:
    //       - Kullanıcı bir profil görüntülediğinde
    //       - Eğer o kullanıcı silinmişse (users/{id} yok)
    //       - Kendi following/followers listesinden otomatik temizle
    //
    // Avantajlar:
    //    ✅ Hesap silme anında timeout riski YOK
    //    ✅ 50K takipçi olsa bile saniyeler içinde tamamlanır
    //    ✅ Temizlik zamanla otomatik yapılır (kullanıcı aktivitesine bağlı)
    //    ✅ Sistem kaynaklarını adil dağıtır (her kullanıcı kendi temizliğini yapar)
    //
    // Not: Kullanıcının kendi followers/following koleksiyonları zaten recursiveDelete
    //      ile silineceği için burada HIÇBIR işlem yapmıyoruz.

    deletionLog.steps.push({
      step: "Follow system cleanup",
      deleted: 0,
      status: "lazy_cleanup_enabled",
      reason: "Karşı taraf temizliği UI lazy cleanup ile yapılacak (timeout önlendi)"
    });
    logger.info("Follow system: Lazy cleanup enabled, no sync operations");

    // === 5) ENGELLEME SİSTEMİ TEMİZLİĞİ (KALDIRILDI - PERFORMANS GÜVENLİĞİ) ===
    // ⚠️ ÖNCEKİ YÖNTEM: Tüm kullanıcıları tarayıp "acaba beni kim engelledi?" diye bakmak
    //    100.000 kullanıcılı sistemde TEK BİR hesap silme işlemi 100.000+ okuma yapardı!
    //    Bu, fonksiyon timeout'una, OOM hatalarına ve maliyet patlamasına yol açardı.
    //
    // ✅ YENİ YAKLAŞIM: Bu taramayı hiç yapmıyoruz.
    //    - Bir kullanıcının ID'si başkasının blocked_users listesinde kalabilir.
    //    - UI tarafında zaten o kullanıcı "bulunamadı" olarak görünecektir.
    //    - Sistem sağlığı ve performans için bu küçük "zombi ID" sorunu kabul edilebilir.
    //
    // Not: Eğer gerçekten temizlik yapılması gerekirse, bunu scheduled function
    //      olarak arka planda yavaşça çalıştırabilirsiniz (günlük/haftalık temizlik)

    deletionLog.steps.push({
      step: "Block system cleanup",
      deleted: 0,
      status: "skipped_for_performance",
      reason: "Tüm kullanıcıları taramak yerine zombi ID'lere izin veriliyor (UI güvenli)"
    });
    logger.info("Block system cleanup: Skipped for performance safety");


    // === 6) MODERASYON SİSTEMİ TEMİZLİĞİ ===
    // Kullanıcı tarafından yapılan raporlar
    await deleteQueryInBatches(
      db.collection("user_reports").where("reporterUserId", "==", userId),
      300,
      "User reports (reporter)"
    );

    // Kullanıcı hakkında yapılan raporlar
    await deleteQueryInBatches(
      db.collection("user_reports").where("reportedUserId", "==", userId),
      300,
      "User reports (reported)"
    );

    // Rapor indeksi
    try {
      const reportIndexRef = db.collection("user_report_index").doc(userId);
      if ((await reportIndexRef.get()).exists) {
        await reportIndexRef.delete();
        deletionLog.steps.push({ step: "User report index", deleted: 1, status: "success" });
      }
    } catch (error) {
      deletionLog.errors.push({ step: "User report index", error: String(error) });
      logger.error("User report index cleanup failed:", error);
    }

    // === 7) RATE LIMIT VE QUOTA KAYITLARI TEMİZLİĞİ ===
    // Rate limits (userId içeren tüm kayıtlar)
    try {
      const rateLimitSnap = await db.collection("rate_limits")
        .where(admin.firestore.FieldPath.documentId(), ">=", userId)
        .where(admin.firestore.FieldPath.documentId(), "<=", userId + "\uf8ff")
        .get();
      let deleted = 0;
      const batch = db.batch();
      rateLimitSnap.docs.forEach(doc => {
        batch.delete(doc.ref);
        deleted++;
      });
      if (deleted > 0) await batch.commit();
      deletionLog.steps.push({ step: "Rate limits", deleted, status: "success" });
    } catch (error) {
      deletionLog.errors.push({ step: "Rate limits", error: String(error) });
      logger.error("Rate limits cleanup failed:", error);
    }

    // Quotas (userId içeren tüm kayıtlar)
    try {
      const quotaSnap = await db.collection("quotas")
        .where(admin.firestore.FieldPath.documentId(), ">=", userId)
        .where(admin.firestore.FieldPath.documentId(), "<=", userId + "\uf8ff")
        .get();
      let deleted = 0;
      const batch = db.batch();
      quotaSnap.docs.forEach(doc => {
        batch.delete(doc.ref);
        deleted++;
      });
      if (deleted > 0) await batch.commit();
      deletionLog.steps.push({ step: "Quotas", deleted, status: "success" });
    } catch (error) {
      deletionLog.errors.push({ step: "Quotas", error: String(error) });
      logger.error("Quotas cleanup failed:", error);
    }

    // === 8-12) PARALEL İŞLEM GRUBU: PUSH KAMPANYA, LEADERBOARD, PROFIL, LOGS VE STORAGE ===
    const miscellaneousDeletions = Promise.all([
      // Push bildirim kampanya logları
      (async () => {
        try {
          const campaignsSnap = await db.collection("push_campaigns").get();
          let logsDeleted = 0;
          for (const campaign of campaignsSnap.docs) {
            const logsSnap = await campaign.ref.collection("logs")
              .where("userId", "==", userId)
              .get();
            const batch = db.batch();
            logsSnap.docs.forEach(doc => {
              batch.delete(doc.ref);
              logsDeleted++;
            });
            if (logsSnap.docs.length > 0) await batch.commit();
          }
          deletionLog.steps.push({ step: "Push campaign logs", deleted: logsDeleted, status: "success" });
          logger.info(`Push campaign logs: ${logsDeleted} entries deleted`);
        } catch (error) {
          deletionLog.errors.push({ step: "Push campaign logs", error: String(error) });
          logger.error("Push campaign logs cleanup failed:", error);
        }
      })(),
      // Liderlik tabloları
      (async () => {
        try {
          const leaderboardsSnap = await db.collection("leaderboards").get();
          let lbDeleted = 0;
          for (const leaderboardDoc of leaderboardsSnap.docs) {
            const userLeaderboardRef = leaderboardDoc.ref.collection("users").doc(userId);
            if ((await userLeaderboardRef.get()).exists) {
              await userLeaderboardRef.delete();
              lbDeleted++;
            }
          }
          deletionLog.steps.push({ step: "Leaderboards", deleted: lbDeleted, status: "success" });
          logger.info(`Leaderboards: ${lbDeleted} entries deleted`);
        } catch (error) {
          deletionLog.errors.push({ step: "Leaderboards", error: String(error) });
          logger.error("Leaderboards cleanup failed:", error);
        }
      })(),
      // Public profile
      (async () => {
        try {
          const publicProfileRef = db.collection("public_profiles").doc(userId);
          if ((await publicProfileRef.get()).exists) {
            await publicProfileRef.delete();
            deletionLog.steps.push({ step: "Public profile", deleted: 1, status: "success" });
          }
        } catch (error) {
          deletionLog.errors.push({ step: "Public profile", error: String(error) });
          logger.error("Public profile cleanup failed:", error);
        }
      })(),
      // Reset logları
      (async () => {
        try {
          const resetLogRef = db.collection("reset_logs").doc(userId);
          if ((await resetLogRef.get()).exists) {
            await resetLogRef.delete();
            deletionLog.steps.push({ step: "Reset logs", deleted: 1, status: "success" });
          }
        } catch (error) {
          deletionLog.errors.push({ step: "Reset logs", error: String(error) });
          logger.error("Reset logs cleanup failed:", error);
        }
      })(),
      // Storage dosyaları (GDPR - kritik)
      deleteStorageFolder(`avatars/${userId}/`, "Storage: avatars"),
      deleteStorageFolder(`user_files/${userId}/`, "Storage: user_files"),
    ]);

    await miscellaneousDeletions;

    // === 12.5) KULLANICI ALT KOLEKSİYONLARINDAN KRİTİK VERİLERİ MANUEL SİL ===
    // Not: recursiveDelete() güvenilir olsa da, kritik verileri önceden manuel silmek
    //      hem log'da görünürlük sağlar hem de daha kontrollü bir silme işlemi yapar
    try {
      // Uygulama içi bildirimler (subcollection: users/{userId}/in_app_notifications)
      await deleteQueryInBatches(
        db.collection("users").doc(userId).collection("in_app_notifications"),
        300,
        "In-app notifications (subcollection)"
      );
    } catch (error) {
      deletionLog.errors.push({ step: "In-app notifications subcollection", error: String(error) });
      logger.error("In-app notifications subcollection cleanup failed:", error);
      // Devam et, recursiveDelete yine de deneyecek
    }

    // === 13) ANA KULLANICI DOKUMANI VE TÜM ALT KOLEKSİYONLARINI SİL (RECURSİVE DELETE) ===
    // ✨ YENİ: recursiveDelete() metodu kullanılıyor
    // Bu, users/{userId} dokümanını ve TÜM alt koleksiyonlarını otomatik olarak siler:
    // - state, user_activity, topic_performance, savedWorkshops
    // - daily_quests, performance, plans, devices, in_app_notifications (yukarıda manuel silindi)
    // - followers, following, blocked_users
    // - İç içe koleksiyonlar (user_activity/{day}/visits, completed_tasks, vb.)
    // - masteredTopics ve diğer tüm nested koleksiyonlar
    try {
      const firestore = getFirestore();
      const userDocRef = db.collection("users").doc(userId);

      // recursiveDelete: Döküman + tüm alt koleksiyonları siler
      await firestore.recursiveDelete(userDocRef);

      deletionLog.steps.push({
        step: "Main user document + all subcollections (recursive)",
        deleted: "all",
        status: "success",
        note: "recursiveDelete() used - all nested collections automatically deleted"
      });
      logger.info("User document and all subcollections recursively deleted");
    } catch (error) {
      deletionLog.errors.push({ step: "Recursive delete user document", error: String(error) });
      logger.error("Recursive user document deletion failed:", error);
      throw error; // Ana doküman silinemezse işlemi başarısız say
    }

    // === 14) FIREBASE AUTHENTICATION KAYDINI SİL (EN SON ADIM) ===
    try {
      await admin.auth().deleteUser(userId);
      deletionLog.steps.push({ step: "Firebase Auth", deleted: 1, status: "success" });
      logger.info("Firebase Auth user deleted");
    } catch (error) {
      deletionLog.errors.push({ step: "Firebase Auth", error: String(error) });
      logger.error("Firebase Auth deletion failed:", error);
      throw error; // Auth kaydı silinemezse işlemi başarısız say
    }

    // === BAŞARI LOGU ===
    deletionLog.endTime = Date.now();
    deletionLog.duration = deletionLog.endTime - deletionLog.startTime;
    deletionLog.totalSteps = deletionLog.steps.length;
    deletionLog.totalErrors = deletionLog.errors.length;

    logger.info(`Account deletion completed for user: ${userId}`, deletionLog);

    return {
      success: true,
      message: "Your account has been permanently deleted.",
      timestamp: Date.now(),
      stats: {
        totalSteps: deletionLog.totalSteps,
        totalErrors: deletionLog.totalErrors,
        duration: deletionLog.duration
      }
    };
  } catch (error) {
    deletionLog.endTime = Date.now();
    deletionLog.duration = deletionLog.endTime - deletionLog.startTime;
    deletionLog.fatalError = String(error);

    logger.error(`Account deletion FAILED for user ${userId}:`, deletionLog);
    throw new Error(`Account deletion failed: ${error.message}`);
  }
});

module.exports = {
  computeInactivityHours,
  processAudienceInBatches,
  deleteUserAccount,
};
