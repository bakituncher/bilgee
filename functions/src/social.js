
const functions = require("firebase-functions");
const admin = require("./admin");
const { HttpsError } = require("firebase-functions/v1/https");

const db = admin.firestore();

/**
 * Kullanıcının başka bir kullanıcıyı engellemesini sağlar.
 * @param {object} data - Fonksiyona gönderilen veri.
 * @param {string} data.userIdToBlock - Engellenecek kullanıcının ID'si.
 * @param {functions.https.CallableContext} context - Çağrı bağlamı.
 * @returns {Promise<{success: boolean}>} - İşlem başarı durumu.
 */
exports.blockUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new HttpsError("unauthenticated", "Bu işlemi yapmak için giriş yapmalısınız.");
  }

  const callingUid = context.auth.uid;
  const { userIdToBlock } = data;

  if (!userIdToBlock) {
    throw new HttpsError("invalid-argument", "Engellenecek kullanıcı ID'si belirtilmelidir.");
  }

  if (callingUid === userIdToBlock) {
    throw new HttpsError("invalid-argument", "Kullanıcı kendini engelleyemez.");
  }

  const userRef = db.collection("users").doc(callingUid);

  try {
    await userRef.update({
      blockedUsers: admin.firestore.FieldValue.arrayUnion(userIdToBlock),
    });
    console.log(`Kullanıcı ${callingUid}, ${userIdToBlock} kullanıcısını engelledi.`);
    return { success: true };
  } catch (error) {
    console.error("Engelleme işlemi sırasında hata:", error);
    throw new HttpsError("internal", "Kullanıcı engellenirken bir hata oluştu.");
  }
});

/**
 * Kullanıcının engellediği bir kullanıcının engelini kaldırmasını sağlar.
 * @param {object} data - Fonksiyona gönderilen veri.
 * @param {string} data.userIdToUnblock - Engeli kaldırılacak kullanıcının ID'si.
 * @param {functions.https.CallableContext} context - Çağrı bağlamı.
 * @returns {Promise<{success: boolean}>} - İşlem başarı durumu.
 */
exports.unblockUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new HttpsError("unauthenticated", "Bu işlemi yapmak için giriş yapmalısınız.");
  }

  const callingUid = context.auth.uid;
  const { userIdToUnblock } = data;

  if (!userIdToUnblock) {
    throw new HttpsError("invalid-argument", "Engeli kaldırılacak kullanıcı ID'si belirtilmelidir.");
  }

  const userRef = db.collection("users").doc(callingUid);

  try {
    await userRef.update({
      blockedUsers: admin.firestore.FieldValue.arrayRemove(userIdToUnblock),
    });
    console.log(`Kullanıcı ${callingUid}, ${userIdToUnblock} kullanıcısının engelini kaldırdı.`);
    return { success: true };
  } catch (error) {
    console.error("Engel kaldırma işlemi sırasında hata:", error);
    throw new HttpsError("internal", "Kullanıcı engeli kaldırılırken bir hata oluştu.");
  }
});

/**
 * Bir kullanıcının başka bir kullanıcıyı raporlamasını sağlar.
 * @param {object} data - Fonksiyona gönderilen veri.
 * @param {string} data.reportedUserId - Rapor edilen kullanıcının ID'si.
 * @param {string} data.reason - Raporlama nedeni.
 * @param {functions.https.CallableContext} context - Çağrı bağlamı.
 * @returns {Promise<{success: boolean}>} - İşlem başarı durumu.
 */
exports.reportUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new HttpsError("unauthenticated", "Bu işlemi yapmak için giriş yapmalısınız.");
  }

  const reporterId = context.auth.uid;
  const { reportedUserId, reason } = data;

  if (!reportedUserId || !reason) {
    throw new HttpsError("invalid-argument", "Rapor edilen kullanıcı ID'si ve neden belirtilmelidir.");
  }

    if (reporterId === reportedUserId) {
    throw new HttpsError("invalid-argument", "Kullanıcı kendini raporlayamaz.");
  }

  const report = {
    reporterId,
    reportedUserId,
    reason,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: "pending", // "pending", "reviewed", "action-taken"
  };

  try {
    await db.collection("reports").add(report);
    console.log(`Kullanıcı ${reporterId}, ${reportedUserId} kullanıcısını raporladı. Neden: ${reason}`);
    return { success: true };
  } catch (error) {
    console.error("Raporlama işlemi sırasında hata:", error);
    throw new HttpsError("internal", "Kullanıcı raporlanırken bir hata oluştu.");
  }
});

/**
 * Bir raporun durumunu günceller. Sadece adminler çağırabilir.
 * @param {object} data - Fonksiyona gönderilen veri.
 * @param {string} data.reportId - Güncellenecek raporun ID'si.
 * @param {string} data.newStatus - Raporun yeni durumu ('reviewed', 'action-taken' etc.).
 * @param {functions.https.CallableContext} context - Çağrı bağlamı.
 * @returns {Promise<{success: boolean}>} - İşlem başarı durumu.
 */
exports.updateReportStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.token.admin) {
    throw new HttpsError("permission-denied", "Bu işlemi yapmak için admin yetkisine sahip olmalısınız.");
  }

  const { reportId, newStatus } = data;

  if (!reportId || !newStatus) {
    throw new HttpsError("invalid-argument", "Rapor ID'si ve yeni durum belirtilmelidir.");
  }

  const reportRef = db.collection("reports").doc(reportId);

  try {
    await reportRef.update({
      status: newStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: context.auth.uid,
    });
    console.log(`Rapor ${reportId}, ${context.auth.uid} tarafından ${newStatus} olarak güncellendi.`);
    return { success: true };
  } catch (error) {
    console.error("Rapor durumu güncellenirken hata:", error);
    throw new HttpsError("internal", "Rapor durumu güncellenirken bir hata oluştu.");
  }
});
