const { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const { db, admin } = require("./init");

async function updatePublicProfile(uid, options = {}) {
  try {
    const userRef = db.collection("users").doc(uid);
    const [userSnap, statsSnap] = await Promise.all([
      userRef.get(),
      userRef.collection("state").doc("stats").get(),
    ]);
    if (!userSnap.exists) return;
    const u = userSnap.data() || {};
    const s = statsSnap.exists ? (statsSnap.data() || {}) : {};
    const publicDoc = {
      userId: uid,
      name: u.name || "",
      username: u.username || "",
      avatarStyle: u.avatarStyle || null,
      avatarSeed: u.avatarSeed || null,
      selectedExam: u.selectedExam || null,
      engagementScore: typeof s.engagementScore === "number" ? s.engagementScore : 0,
      streak: typeof s.streak === "number" ? s.streak : 0,
      testCount: typeof s.testCount === "number" ? s.testCount : 0,
      totalNetSum: typeof s.totalNetSum === "number" ? s.totalNetSum : 0,
      // GÜVENLİK GÜNCELLEMESİ: Takipçi sayıları da senkronize edilir
      followerCount: typeof u.followerCount === "number" ? u.followerCount : 0,
      followingCount: typeof u.followingCount === "number" ? u.followingCount : 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await db.collection("public_profiles").doc(uid).set(publicDoc, { merge: true });
  } catch (e) {
    logger.warn("updatePublicProfile failed", { uid, error: String(e) });
  }
}

// GÜVENLİK GÜNCELLEMESİ: Takipçi sayıları artık /users koleksiyonu üzerinde atomik olarak güncellenir.
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
    // Sayıların negatif olmasını engellemek için transaction kullanılabilir,
    // ancak increment'in doğası ve akış mantığı bunu büyük ölçüde gereksiz kılar.
    // Şimdilik basit bir update yeterlidir.
    await ref.set(dataToUpdate, { merge: true });
  }
}

exports.onFollowerCreated = onDocumentCreated({
  document: "users/{userId}/followers/{followerId}",
  region: "us-central1",
}, async (event) => {
  const { userId, followerId } = event.params;
  try {
    // Takip edilen kullanıcının takipçi sayısını artır
    await adjustUserFollowCounts(userId, { followersDelta: +1 });
    // Takip eden kullanıcının takip ettikleri sayısını artır
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
    // Takip edilen kullanıcının takipçi sayısını azalt
    await adjustUserFollowCounts(userId, { followersDelta: -1 });
    // Takip eden kullanıcının takip ettikleri sayısını azalt
    await adjustUserFollowCounts(followerId, { followingDelta: -1 });
  } catch (e) {
    logger.warn("onFollowerDeleted failed", { userId, followerId, error: String(e) });
  }
});

// `following` alt koleksiyonu üzerindeki tetikleyiciler kaldırıldı.
// `followers` koleksiyonu üzerindeki değişiklikler, her iki kullanıcının da
// sayaçlarını atomik olarak güncellediği için `following` tetikleyicileri gereksizdir.
// Bu, hem maliyeti düşürür hem de sistemin karmaşıklığını azaltır.

exports.onUserUpdate = onDocumentUpdated("users/{userId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const uid = event.params.userId;

  // GÜVENLİK GÜNCELLEMESİ: Senkronize edilecek alanlara takipçi sayıları eklendi.
  const fieldsToSync = ["name", "username", "avatarStyle", "avatarSeed", "selectedExam", "followerCount", "followingCount"];
  const needsSync = fieldsToSync.some((field) => before[field] !== after[field]);

  if (!needsSync) {
    // logger.log(`No relevant fields changed for user ${uid}. Skipping sync.`);
    return null;
  }

  logger.log(`Syncing profile for user ${uid} due to field changes.`);
  const batch = db.batch();

  // 1. Update public_profiles
  const publicProfileRef = db.collection("public_profiles").doc(uid);
  const publicData = {
    name: after.name || "",
    username: after.username || "",
    avatarStyle: after.avatarStyle || null,
    avatarSeed: after.avatarSeed || null,
    selectedExam: after.selectedExam || null,
    // GÜVENLİK GÜNCELLEMESİ: Takipçi sayıları da senkronize edilir
    followerCount: typeof after.followerCount === "number" ? after.followerCount : 0,
    followingCount: typeof after.followingCount === "number" ? after.followingCount : 0,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  batch.set(publicProfileRef, publicData, { merge: true });

  // 2. Update leaderboards if exam type is selected
  if (after.selectedExam) {
    const leaderboardRef = db.collection("leaderboards").doc(after.selectedExam).collection("users").doc(uid);
    const leaderboardData = {
      userName: after.name || "",
      username: after.username || "",
      avatarStyle: after.avatarStyle || null,
      avatarSeed: after.avatarSeed || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    batch.set(leaderboardRef, leaderboardData, { merge: true });
  }

  // 3. If exam type changed, delete old leaderboard entry
  if (before.selectedExam && before.selectedExam !== after.selectedExam) {
    const oldLeaderboardRef = db.collection("leaderboards").doc(before.selectedExam).collection("users").doc(uid);
    batch.delete(oldLeaderboardRef);
  }

  try {
    await batch.commit();
    logger.log(`Successfully synced profile for user ${uid}.`);
  } catch (e) {
    logger.error("onUserUpdate failed", { uid, error: String(e) });
  }
});

module.exports = {
  ...exports,
  updatePublicProfile,
};
