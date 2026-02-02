const { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const { db, admin } = require("./init");
const { isBranchTest } = require("./utils");

async function updatePublicProfile(uid, options = {}) {
  try {
    const userRef = db.collection("users").doc(uid);
    const [userSnap, statsSnap] = await Promise.all([
      userRef.get(),
      userRef.collection("state").doc("stats").get(),
    ]);

    if (!userSnap.exists) {
      logger.info(`User ${uid} not found in updatePublicProfile (likely deleted). Skipping.`);
      return;
    }

    const u = userSnap.data() || {};
    const s = statsSnap.exists ? (statsSnap.data() || {}) : {};

    // KRİTİK: testCount/totalNetSum drift edebiliyor.
    // Tek kaynak: tests koleksiyonu. Hem yeni (isBranchTest alanı var) hem eski veriler desteklenir.
    let realTestCount = 0;
    let realTotalNetSum = 0;

    try {
      const qsAll = await db.collection("tests")
        .where("userId", "==", uid)
        .get();

      for (const d of qsAll.docs) {
        const data = d.data() || {};
        // Yeni veriler: isBranchTest boolean’ı doğrudan kullan
        // Eski veriler: utils.isBranchTest ile hesapla
        const branch = (typeof data.isBranchTest === "boolean")
          ? data.isBranchTest
          : isBranchTest(data.scores, data.sectionName, data.examType);

        // SADECE GENEL DENEMELERİ SAY (Branş denemelerini atla)
        if (branch) continue;

        realTestCount += 1;
        const net = typeof data.totalNet === "number" ? data.totalNet : 0;
        realTotalNetSum += net;
      }

    } catch (e) {
      // Hata durumunda eski stats değerlerini koru ama logla
      logger.warn("updatePublicProfile: tests aggregate failed, falling back to stats", { uid, error: String(e) });
      realTestCount = typeof s.testCount === "number" ? s.testCount : 0;
      realTotalNetSum = typeof s.totalNetSum === "number" ? s.totalNetSum : 0;
    }

    const publicDoc = {
      userId: uid,
      name: u.name || "",
      username: u.username || "",
      avatarStyle: u.avatarStyle || null,
      avatarSeed: u.avatarSeed || null,
      selectedExam: u.selectedExam || null,
      engagementScore: typeof s.engagementScore === "number" ? s.engagementScore : 0,
      streak: typeof s.streak === "number" ? s.streak : 0,
      testCount: realTestCount,
      totalNetSum: realTotalNetSum,
      followerCount: typeof u.followerCount === "number" ? u.followerCount : 0,
      followingCount: typeof u.followingCount === "number" ? u.followingCount : 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // 1. Public profili güncelle
    await db.collection("public_profiles").doc(uid).set(publicDoc, { merge: true });

    // 2. DÜZELTME: Hesaplanan doğru (filtreli) değerleri kullanıcının ÖZEL STATS dosyasına da eşitle.
    // Bu işlem, uygulamadaki 'Profile Screen' ve 'Dashboard'daki yanlış veriyi düzeltir.
    await userRef.collection("state").doc("stats").set({
      testCount: realTestCount,
      totalNetSum: realTotalNetSum,
      // Diğer alanlara (streak, score vb.) dokunmuyoruz, onlar merge ile korunur.
    }, { merge: true });

  } catch (e) {
    logger.warn("updatePublicProfile failed", { uid, error: String(e) });
  }
}

// ... (Geri kalan kodlar aynı) ...

async function adjustUserFollowCounts(uid, { followersDelta = 0, followingDelta = 0 }) {
  if (!uid) return;

  const ref = db.collection("users").doc(uid);
  const dataToUpdate = {};

  if (followersDelta !== 0) {
    dataToUpdate.followerCount = admin.firestore.FieldValue.increment(followersDelta);
  }
  if (followingDelta !== 0) {
    dataToUpdate.followingCount = admin.firestore.FieldValue.increment(followingDelta);
  }

  if (Object.keys(dataToUpdate).length > 0) {
    dataToUpdate.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    try {
      await ref.update(dataToUpdate);
    } catch (error) {
      if (error.code === 'not-found') {
        logger.info(`User ${uid} not found during follow count adjustment (likely deleted). Skipping.`);
      } else {
        throw error;
      }
    }
  }
}

exports.onFollowerCreated = onDocumentCreated({
  document: "users/{userId}/followers/{followerId}",
  region: "us-central1",
}, async (event) => {
  const { userId, followerId } = event.params;
  try {
    await adjustUserFollowCounts(userId, { followersDelta: +1 });
    await adjustUserFollowCounts(followerId, { followingDelta: +1 });
  } catch (e) {
    logger.warn("onFollowerCreated failed", { userId, followerId, error: String(e) });
  }
});

exports.onFollowerDeleted = onDocumentDeleted({
  document: "users/{userId}/followers/{followerId}",
  region: "us-central1",
}, async (event) => {
  const { userId, followerId } = event.params;
  try {
    await adjustUserFollowCounts(userId, { followersDelta: -1 });
    await adjustUserFollowCounts(followerId, { followingDelta: -1 });
  } catch (e) {
    logger.warn("onFollowerDeleted failed", { userId, followerId, error: String(e) });
  }
});

exports.onUserUpdate = onDocumentUpdated("users/{userId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const uid = event.params.userId;

  const fieldsToSync = ["name", "username", "avatarStyle", "avatarSeed", "selectedExam", "followerCount", "followingCount"];
  const needsSync = fieldsToSync.some((field) => before[field] !== after[field]);

  if (!needsSync) {
    return null;
  }

  logger.log(`Syncing profile for user ${uid} due to field changes.`);

  const publicProfileRef = db.collection("public_profiles").doc(uid);
  const publicData = {
    name: after.name || "",
    username: after.username || "",
    avatarStyle: after.avatarStyle || null,
    avatarSeed: after.avatarSeed || null,
    selectedExam: after.selectedExam || null,
    followerCount: typeof after.followerCount === "number" ? after.followerCount : 0,
    followingCount: typeof after.followingCount === "number" ? after.followingCount : 0,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  try {
    await publicProfileRef.set(publicData, { merge: true });
    logger.log(`Successfully synced profile for user ${uid}.`);
  } catch (e) {
    logger.error("onUserUpdate failed", { uid, error: String(e) });
  }
});

exports.onUserDeleted = onDocumentDeleted("users/{userId}", async (event) => {
  const uid = event.params.userId;
  try {
    await db.collection("public_profiles").doc(uid).delete();
    logger.info(`Public profile cleanup completed for deleted user ${uid}`);
  } catch (e) {
    logger.warn("onUserDeleted cleanup failed", { uid, error: String(e) });
  }
});

module.exports = {
  ...exports,
  updatePublicProfile,
};