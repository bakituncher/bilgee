// functions/src/moderation.js
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const { db, admin } = require("./init");

// Rate limiting için basit in-memory cache (production'da Redis kullanılmalı)
const rateLimitCache = new Map();

/**
 * Rate limiting kontrolü
 * @param {string} userId - Kullanıcı ID
 * @param {string} action - İşlem türü (block, report, etc.)
 * @param {number} maxRequests - Maksimum istek sayısı
 * @param {number} windowMs - Zaman penceresi (milisaniye)
 * @returns {boolean} - Rate limit aşılmışsa true
 */
function checkRateLimit(userId, action, maxRequests = 10, windowMs = 60000) {
  const key = `${userId}:${action}`;
  const now = Date.now();

  if (!rateLimitCache.has(key)) {
    rateLimitCache.set(key, []);
  }

  const requests = rateLimitCache.get(key);
  // Eski istekleri temizle
  const validRequests = requests.filter(timestamp => now - timestamp < windowMs);

  if (validRequests.length >= maxRequests) {
    return true; // Rate limit aşıldı
  }

  validRequests.push(now);
  rateLimitCache.set(key, validRequests);

  // Cache temizliği (her 100 işlemde bir)
  if (Math.random() < 0.01) {
    cleanupRateLimit();
  }

  return false;
}

/**
 * Eski rate limit kayıtlarını temizle
 */
function cleanupRateLimit() {
  const now = Date.now();
  for (const [key, timestamps] of rateLimitCache.entries()) {
    const valid = timestamps.filter(t => now - t < 300000); // 5 dakika
    if (valid.length === 0) {
      rateLimitCache.delete(key);
    } else {
      rateLimitCache.set(key, valid);
    }
  }
}

/**
 * Kullanıcıyı engelleme fonksiyonu
 * Rate-limited ve güvenli
 */
exports.blockUser = onCall({
  region: "us-central1",
  enforceAppCheck: true,
}, async (request) => {
  // Kimlik doğrulama kontrolü
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Kullanıcı giriş yapmamış");
  }

  const userId = request.auth.uid;
  const { targetUserId, reason } = request.data;

  // Parametrelerin varlığı
  if (!targetUserId || typeof targetUserId !== "string") {
    throw new HttpsError("invalid-argument", "Geçersiz kullanıcı ID");
  }

  // Kendi kendini engelleyemez
  if (userId === targetUserId) {
    throw new HttpsError("invalid-argument", "Kendinizi engelleyemezsiniz");
  }

  // Rate limiting (dakikada 5 engelleme)
  if (checkRateLimit(userId, "block", 5, 60000)) {
    throw new HttpsError(
      "resource-exhausted",
      "Çok fazla engelleme isteği. Lütfen bir süre bekleyin."
    );
  }

  try {
    // Hedef kullanıcının var olduğunu doğrula
    const targetUserDoc = await db.collection("users").doc(targetUserId).get();
    if (!targetUserDoc.exists) {
      throw new HttpsError("not-found", "Kullanıcı bulunamadı");
    }

    // Zaten engellenmiş mi kontrol et
    const blockRef = db.collection("users").doc(userId)
      .collection("blocked_users").doc(targetUserId);
    const existingBlock = await blockRef.get();

    if (existingBlock.exists) {
      throw new HttpsError("already-exists", "Bu kullanıcı zaten engellenmiş");
    }

    // Engelleme kaydı oluştur
    await blockRef.set({
      blockedBy: userId,
      blockedAt: admin.firestore.FieldValue.serverTimestamp(),
      reason: reason || null,
    });

    // Karşılıklı takibi kaldır (eğer varsa)
    const batch = db.batch();

    // Engelleyen kullanıcının takip ettiği listeinden çıkar
    const followingRef = db.collection("users").doc(userId)
      .collection("following").doc(targetUserId);
    batch.delete(followingRef);

    // Engellenen kullanıcının takipçi listesinden çıkar
    const followerRef = db.collection("users").doc(targetUserId)
      .collection("followers").doc(userId);
    batch.delete(followerRef);

    // Engellenen kullanıcının takip ettiği listeinden çıkar (karşı yönlü)
    const targetFollowingRef = db.collection("users").doc(targetUserId)
      .collection("following").doc(userId);
    batch.delete(targetFollowingRef);

    // Engelleyen kullanıcının takipçi listesinden çıkar (karşı yönlü)
    const userFollowerRef = db.collection("users").doc(userId)
      .collection("followers").doc(targetUserId);
    batch.delete(userFollowerRef);

    await batch.commit();

    logger.info("User blocked successfully", {
      blocker: userId,
      blocked: targetUserId,
    });

    return {
      success: true,
      message: "Kullanıcı başarıyla engellendi",
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    logger.error("Error blocking user", { userId, targetUserId, error: String(error) });
    throw new HttpsError("internal", "Engelleme sırasında bir hata oluştu");
  }
});

/**
 * Kullanıcı engelini kaldırma fonksiyonu
 */
exports.unblockUser = onCall({
  region: "us-central1",
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Kullanıcı giriş yapmamış");
  }

  const userId = request.auth.uid;
  const { targetUserId } = request.data;

  if (!targetUserId || typeof targetUserId !== "string") {
    throw new HttpsError("invalid-argument", "Geçersiz kullanıcı ID");
  }

  try {
    const blockRef = db.collection("users").doc(userId)
      .collection("blocked_users").doc(targetUserId);

    const blockDoc = await blockRef.get();
    if (!blockDoc.exists) {
      throw new HttpsError("not-found", "Bu kullanıcı engellenmemiş");
    }

    await blockRef.delete();

    logger.info("User unblocked successfully", {
      blocker: userId,
      unblocked: targetUserId,
    });

    return {
      success: true,
      message: "Engel kaldırıldı",
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    logger.error("Error unblocking user", { userId, targetUserId, error: String(error) });
    throw new HttpsError("internal", "Engel kaldırma sırasında bir hata oluştu");
  }
});

/**
 * Kullanıcı raporlama fonksiyonu
 * Rate-limited ve güvenli
 */
exports.reportUser = onCall({
  region: "us-central1",
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Kullanıcı giriş yapmamış");
  }

  const reporterId = request.auth.uid;
  const { reportedUserId, reason, details } = request.data;

  // Parametrelerin varlığı ve geçerliliği
  if (!reportedUserId || typeof reportedUserId !== "string") {
    throw new HttpsError("invalid-argument", "Geçersiz kullanıcı ID");
  }

  if (!reason || typeof reason !== "string") {
    throw new HttpsError("invalid-argument", "Raporlama nedeni gerekli");
  }

  const validReasons = [
    "spam",
    "harassment",
    "inappropriate",
    "impersonation",
    "underage",
    "hate_speech",
    "scam",
    "other",
  ];

  if (!validReasons.includes(reason)) {
    throw new HttpsError("invalid-argument", "Geçersiz raporlama nedeni");
  }

  // Kendi kendini raporlayamaz
  if (reporterId === reportedUserId) {
    throw new HttpsError("invalid-argument", "Kendinizi raporlayamazsınız");
  }

  // Rate limiting (saatte 3 raporlama)
  if (checkRateLimit(reporterId, "report", 3, 3600000)) {
    throw new HttpsError(
      "resource-exhausted",
      "Çok fazla raporlama isteği. Lütfen bir süre bekleyin."
    );
  }

  try {
    // Hedef kullanıcının var olduğunu doğrula
    const reportedUserDoc = await db.collection("users").doc(reportedUserId).get();
    if (!reportedUserDoc.exists) {
      throw new HttpsError("not-found", "Kullanıcı bulunamadı");
    }

    // Aynı kullanıcıyı son 24 saatte raporlamış mı kontrol et
    const oneDayAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 86400000);
    const recentReports = await db.collection("user_reports")
      .where("reporterUserId", "==", reporterId)
      .where("reportedUserId", "==", reportedUserId)
      .where("createdAt", ">", oneDayAgo)
      .limit(1)
      .get();

    if (!recentReports.empty) {
      throw new HttpsError(
        "already-exists",
        "Bu kullanıcıyı son 24 saat içinde zaten raporladınız"
      );
    }

    // Rapor oluştur
    const reportRef = db.collection("user_reports").doc();
    await reportRef.set({
      reportedUserId,
      reporterUserId: reporterId,
      reason,
      details: details || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "pending",
      adminNotes: null,
      reviewedAt: null,
      reviewedBy: null,
    });

    // Rapor indeksini güncelle (moderasyon için)
    const indexRef = db.collection("user_report_index").doc(reportedUserId);
    await indexRef.set({
      reportedUserId,
      reportCount: admin.firestore.FieldValue.increment(1),
      lastReportedAt: admin.firestore.FieldValue.serverTimestamp(),
      reasons: admin.firestore.FieldValue.arrayUnion(reason),
    }, { merge: true });

    logger.info("User reported successfully", {
      reporter: reporterId,
      reported: reportedUserId,
      reason,
    });

    return {
      success: true,
      message: "Rapor başarıyla gönderildi. İnceleme süreci başlatıldı.",
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    logger.error("Error reporting user", {
      reporterId,
      reportedUserId,
      error: String(error),
    });
    throw new HttpsError("internal", "Raporlama sırasında bir hata oluştu");
  }
});

/**
 * Engellenen kullanıcı listesini getir
 */
exports.getBlockedUsers = onCall({
  region: "us-central1",
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Kullanıcı giriş yapmamış");
  }

  const userId = request.auth.uid;

  try {
    const blockedSnapshot = await db.collection("users").doc(userId)
      .collection("blocked_users")
      .orderBy("blockedAt", "desc")
      .limit(100)
      .get();

    const blockedUsers = [];
    for (const doc of blockedSnapshot.docs) {
      const blockData = doc.data();
      const blockedUserId = doc.id;

      // Engellenen kullanıcının temel bilgilerini al
      const userDoc = await db.collection("public_profiles").doc(blockedUserId).get();
      const userData = userDoc.exists ? userDoc.data() : {};

      blockedUsers.push({
        userId: blockedUserId,
        blockedAt: blockData.blockedAt,
        reason: blockData.reason,
        name: userData.name || "İsimsiz Kullanıcı",
        username: userData.username || "",
        avatarStyle: userData.avatarStyle,
        avatarSeed: userData.avatarSeed,
      });
    }

    return {
      success: true,
      blockedUsers,
    };
  } catch (error) {
    logger.error("Error getting blocked users", { userId, error: String(error) });
    throw new HttpsError("internal", "Engellenen kullanıcılar getirilirken hata oluştu");
  }
});

/**
 * Kullanıcının belirli bir kullanıcıyı engelleyip engellemediğini kontrol et
 */
exports.checkIfBlocked = onCall({
  region: "us-central1",
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Kullanıcı giriş yapmamış");
  }

  const userId = request.auth.uid;
  const { targetUserId } = request.data;

  if (!targetUserId) {
    throw new HttpsError("invalid-argument", "Hedef kullanıcı ID gerekli");
  }

  try {
    // İki yönlü kontrol: Kullanıcı hedefi engellemiş mi veya hedef kullanıcıyı engellemiş mi
    const [userBlockedTarget, targetBlockedUser] = await Promise.all([
      db.collection("users").doc(userId).collection("blocked_users").doc(targetUserId).get(),
      db.collection("users").doc(targetUserId).collection("blocked_users").doc(userId).get(),
    ]);

    return {
      success: true,
      isBlockedByMe: userBlockedTarget.exists,
      isBlockingMe: targetBlockedUser.exists,
      isBlocked: userBlockedTarget.exists || targetBlockedUser.exists,
    };
  } catch (error) {
    logger.error("Error checking block status", { userId, targetUserId, error: String(error) });
    throw new HttpsError("internal", "Engel durumu kontrol edilirken hata oluştu");
  }
});

// Admin fonksiyonları

/**
 * Raporları listele (Admin)
 */
exports.adminListReports = onCall({
  region: "us-central1",
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth || !request.auth.token.admin) {
    throw new HttpsError("permission-denied", "Admin yetkisi gerekli");
  }

  const { status = "pending", limit = 50 } = request.data;

  try {
    let query = db.collection("user_reports");

    if (status !== "all") {
      query = query.where("status", "==", status);
    }

    const snapshot = await query
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    const reports = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      success: true,
      reports,
    };
  } catch (error) {
    logger.error("Error listing reports", { error: String(error) });
    throw new HttpsError("internal", "Raporlar getirilirken hata oluştu");
  }
});

/**
 * Raporu güncelle (Admin)
 */
exports.adminUpdateReport = onCall({
  region: "us-central1",
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth || !request.auth.token.admin) {
    throw new HttpsError("permission-denied", "Admin yetkisi gerekli");
  }

  const { reportId, status, adminNotes } = request.data;

  if (!reportId || !status) {
    throw new HttpsError("invalid-argument", "Rapor ID ve durum gerekli");
  }

  const validStatuses = ["pending", "reviewed", "resolved", "dismissed"];
  if (!validStatuses.includes(status)) {
    throw new HttpsError("invalid-argument", "Geçersiz rapor durumu");
  }

  try {
    const reportRef = db.collection("user_reports").doc(reportId);
    const reportDoc = await reportRef.get();

    if (!reportDoc.exists) {
      throw new HttpsError("not-found", "Rapor bulunamadı");
    }

    await reportRef.update({
      status,
      adminNotes: adminNotes || null,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewedBy: request.auth.uid,
    });

    logger.info("Report updated by admin", {
      reportId,
      status,
      adminId: request.auth.uid,
    });

    return {
      success: true,
      message: "Rapor güncellendi",
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    logger.error("Error updating report", { reportId, error: String(error) });
    throw new HttpsError("internal", "Rapor güncellenirken hata oluştu");
  }
});

module.exports = exports;

