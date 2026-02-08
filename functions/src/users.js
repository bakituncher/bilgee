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
  // Varsayılan olarak sadece gerekli alanları çekelim (performans için)
  let query = db.collection("users").select("selectedExam", "isPremium");

  // --- Filtreleme Mantığı ---
  const lc = (s) => (typeof s === "string" ? s.toLowerCase() : s);

  // 🔥 GLOBAL FİLTRE (Hem otomatik hem manuel gönderimler için)
  // Eğer audience içinde 'onlyNonPremium' varsa veya tip 'non_premium' ise filtreyi en başa ekle.
  // Bu sayede "Sadece YKS seçili" olsa bile bu filtre üzerine eklenir (AND mantığı).
  const shouldFilterPremium = audience && (audience.type === "non_premium" || audience.onlyNonPremium === true);

  if (shouldFilterPremium) {
    // isPremium değeri true OLMAYAN her şeyi getir (false veya null)
    // Not: Firestore'da '!=' sorgusu bazen alanı hiç olmayanları getirmeyebilir,
    // ama uygulamanızda alanlar tutarlıysa bu en performanslı yoldur.
    query = query.where("isPremium", "!=", true);
  }

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
  }

  // 3. Özel UID Listesi (🔥 DÜZELTİLDİ: Premium filtresi desteği eklendi)
  else if (audience && audience.type === "uids" && Array.isArray(audience.uids)) {
    const cleanUids = audience.uids.filter((x) => typeof x === "string");

    // 🔥 DÜZELTME: Eğer premium filtresi varsa, UID'leri kontrol et
    if (shouldFilterPremium) {
      // UID'leri batch'ler halinde Firestore'dan kontrol et
      for (let i = 0; i < cleanUids.length; i += BATCH_SIZE) {
        const batchUids = cleanUids.slice(i, i + BATCH_SIZE);

        // Bu batch'teki kullanıcıların premium durumunu kontrol et
        // Performans için sadece isPremium alanını çekiyoruz
        const refs = batchUids.map(uid => db.collection("users").doc(uid));
        const snapshots = await db.getAll(...refs, { fieldMask: ['isPremium'] });

        // Filtreleme: Belge var mı VE isPremium != true mi?
        const filteredUids = snapshots
          .filter(snap => snap.exists && snap.data().isPremium !== true)
          .map(snap => snap.id);

        if (filteredUids.length > 0) {
          await batchCallback(filteredUids);
        }
      }
    } else {
      // Filtre yoksa eski hızlı yöntem
      for (let i = 0; i < cleanUids.length; i += BATCH_SIZE) {
        await batchCallback(cleanUids.slice(i, i + BATCH_SIZE));
      }
    }
    return;
  }

  // --- Batch Döngüsü ---
  let lastDoc = null;
  let totalProcessed = 0;

  while (true) {
    let currentQuery = query.limit(BATCH_SIZE);
    if (lastDoc) currentQuery = currentQuery.startAfter(lastDoc);

    const snapshot = await currentQuery.get();
    if (snapshot.empty) break;

    const uids = snapshot.docs.map((doc) => doc.id);

    if (uids.length > 0) {
      await batchCallback(uids);
    }

    totalProcessed += uids.length;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    await new Promise((resolve) => setTimeout(resolve, 50));
  }

  // Sadece log bas, return etme (void)
  console.log(`Batch işlemi tamamlandı. Toplam: ${totalProcessed}`);
}

/**
 * Kullanıcı hesabını kalıcı olarak siler.
 * * OPTİMİZASYON (2025):
 * - İşlemler sıralı (sequential) yerine PARALEL (concurrent) hale getirildi.
 * - Tüm koleksiyon temizlikleri ve recursiveDelete aynı anda başlatılır.
 * - İşlem süresi dramatik olarak kısaltıldı (Bekleme süresi minimize edildi).
 * - Auth silme işlemi veri temizliğinden sonra güvenli bir şekilde yapılır.
 */
const deleteUserAccount = onCall({ region: "us-central1", timeoutSeconds: 540, enforceAppCheck: false, maxInstances: 10 }, async (request) => {
  if (!request.auth) {
    throw new Error("The function must be called while authenticated.");
  }
  const userId = request.auth.uid;

  // Rate limit
  const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
  await Promise.all([
    enforceRateLimit(`delete_account_uid_${userId}`, 3600, 5),
    enforceRateLimit(`delete_account_ip_${ip}`, 3600, 15),
  ]);

  const deletionLog = {
    userId,
    startTime: Date.now(),
    steps: [],
    errors: []
  };

  try {
    logger.info(`Account deletion started (Optimized) for user: ${userId}`);

    // --- Helpers ---

    async function deleteQueryInBatches(query, batchSize = 400, stepName = "unknown") {
      try {
        let totalDeleted = 0;
        while (true) {
          const snap = await query.limit(batchSize).get();
          if (snap.empty) break;
          const batch = db.batch();
          snap.docs.forEach((doc) => batch.delete(doc.ref));
          await batch.commit();
          totalDeleted += snap.docs.length;
          // Paralel çalışmada bekleme süresini minimize ettik (25ms -> 10ms)
          await new Promise((r) => setTimeout(r, 10));
        }
        deletionLog.steps.push({ step: stepName, deleted: totalDeleted, status: "success" });
      } catch (error) {
        deletionLog.errors.push({ step: stepName, error: String(error) });
        logger.error(`${stepName} failed:`, error);
      }
    }

    async function deleteStorageFolder(path, stepName = path) {
      try {
        const bucket = admin.storage().bucket();
        // prefix ile listeleme hızlıdır
        const [files] = await bucket.getFiles({ prefix: path });
        if (files.length === 0) return;

        // Dosyaları paralel sil (Promise.all ile)
        // Maksimum 50'lik gruplar halinde gönderelim
        const chunkSize = 50;
        for (let i = 0; i < files.length; i += chunkSize) {
          const chunk = files.slice(i, i + chunkSize);
          await Promise.all(chunk.map(file => file.delete().catch(e => logger.warn(`File delete error ${file.name}:`, e))));
        }

        deletionLog.steps.push({ step: stepName, deleted: files.length, status: "success" });
      } catch (error) {
        deletionLog.errors.push({ step: stepName, error: String(error) });
        logger.error(`${stepName} failed:`, error);
      }
    }

    // --- PARALEL GÖREV LİSTESİ ---
    // Tüm temizlik görevlerini bu listeye ekleyip tek seferde (Promise.all) çalıştıracağız.
    const cleanupTasks = [];

    // 1. DIŞ REFERANSLAR (Kullanıcıya ait diğer koleksiyonlardaki veriler)
    cleanupTasks.push(deleteQueryInBatches(db.collection("tests").where("userId", "==", userId), 400, "Tests"));
    cleanupTasks.push(deleteQueryInBatches(db.collection("focusSessions").where("userId", "==", userId), 400, "FocusSessions"));
    cleanupTasks.push(deleteQueryInBatches(db.collection("posts").where("userId", "==", userId), 400, "Posts"));
    cleanupTasks.push(deleteQueryInBatches(db.collection("questionReports").where("userId", "==", userId), 400, "QuestionReports"));

    // 2. RAPORLAR & MODERASYON
    cleanupTasks.push(deleteQueryInBatches(db.collection("user_reports").where("reporterUserId", "==", userId), 300, "UserReports (Reporter)"));
    cleanupTasks.push(deleteQueryInBatches(db.collection("user_reports").where("reportedUserId", "==", userId), 300, "UserReports (Reported)"));

    // Rapor İndeksi (Tekil Doküman)
    cleanupTasks.push(async () => {
      try {
        await db.collection("user_report_index").doc(userId).delete();
      } catch(e) { /* ignore */ }
    });

    // 3. LİMİTLER VE KOTALAR
    cleanupTasks.push(deleteQueryInBatches(db.collection("rate_limits").where(admin.firestore.FieldPath.documentId(), ">=", userId).where(admin.firestore.FieldPath.documentId(), "<=", userId + "\uf8ff"), 300, "RateLimits"));
    cleanupTasks.push(deleteQueryInBatches(db.collection("quotas").where(admin.firestore.FieldPath.documentId(), ">=", userId).where(admin.firestore.FieldPath.documentId(), "<=", userId + "\uf8ff"), 300, "Quotas"));

    // 4. STORAGE (Dosyalar)
    cleanupTasks.push(deleteStorageFolder(`avatars/${userId}/`, "Storage: avatars"));
    cleanupTasks.push(deleteStorageFolder(`user_files/${userId}/`, "Storage: user_files"));

    // 5. DİĞER (Liderlik, Profiller, Loglar)
    // Push Logları
    cleanupTasks.push((async () => {
      try {
        const campaignsSnap = await db.collection("push_campaigns").get();
        const promises = campaignsSnap.docs.map(campaign =>
           deleteQueryInBatches(campaign.ref.collection("logs").where("userId", "==", userId), 100, `PushLogs-${campaign.id}`)
        );
        await Promise.all(promises);
      } catch (e) { logger.error("Push logs error", e); }
    })());

    // Liderlik Tabloları
    cleanupTasks.push((async () => {
      try {
        const leaderboardsSnap = await db.collection("leaderboards").get();
        const batch = db.batch();
        let count = 0;
        for (const doc of leaderboardsSnap.docs) {
           const ref = doc.ref.collection("users").doc(userId);
           batch.delete(ref);
           count++;
        }
        if (count > 0) await batch.commit();
      } catch (e) { logger.error("Leaderboard cleanup error", e); }
    })());

    // Public Profile & Reset Logs
    cleanupTasks.push(db.collection("public_profiles").doc(userId).delete());
    cleanupTasks.push(db.collection("reset_logs").doc(userId).delete());

    // 6. ANA KULLANICI DOKÜMANI VE ALT KOLEKSİYONLARI (Recursive Delete)
    // Bu işlem 'in_app_notifications', 'followers', 'following' vb. tüm alt koleksiyonları kapsar.
    // Diğer işlemlerle AYNI ANDA çalışmasında bir sakınca yoktur çünkü
    // diğer işlemler users/{userId} altındaki verilere dokunmuyor (Tests, Posts vb. dışarıda).
    cleanupTasks.push((async () => {
        try {
            const firestore = getFirestore();
            await firestore.recursiveDelete(db.collection("users").doc(userId));
            deletionLog.steps.push({ step: "Recursive User Delete", status: "success" });
        } catch (e) {
            deletionLog.errors.push({ step: "Recursive User Delete", error: String(e) });
            throw e; // Bu kritik bir hata
        }
    })());

    // --- TÜM VERİ TEMİZLİĞİNİ BAŞLAT VE BEKLE ---
    logger.info(`Executing ${cleanupTasks.length} parallel cleanup tasks...`);
    await Promise.all(cleanupTasks);

    // 7. SON ADIM: FIREBASE AUTH SİLME
    // Veriler temizlendikten sonra kullanıcıyı sil
    try {
      await admin.auth().deleteUser(userId);
      deletionLog.steps.push({ step: "Firebase Auth", status: "success" });
    } catch (error) {
      // Eğer kullanıcı zaten yoksa (önceki denemeden) hata verme
      if (error.code !== 'auth/user-not-found') {
        throw error;
      }
    }

    deletionLog.endTime = Date.now();
    deletionLog.duration = deletionLog.endTime - deletionLog.startTime;

    logger.info(`Account deletion completed in ${deletionLog.duration}ms`, deletionLog);

    return {
      success: true,
      message: "Account deleted successfully.",
      duration: deletionLog.duration
    };

  } catch (error) {
    logger.error(`Account deletion FAILED for user ${userId}`, error);
    throw new Error(`Account deletion failed: ${error.message}`);
  }
});

// Sunucu zamanını ve İstanbul tarihini döndüren fonksiyon (Bypass engelleme için)
const getServerTime = onCall({ region: "us-central1" }, async (request) => {
  const now = nowIstanbul();
  const dayKey = dayKeyIstanbul(now); // 'YYYY-MM-DD'

  return {
    timestamp: now.getTime(),
    istanbulDay: dayKey,
    timezone: "Europe/Istanbul"
  };
});

module.exports = {
  computeInactivityHours,
  processAudienceInBatches,
  deleteUserAccount,
  getServerTime,
};
