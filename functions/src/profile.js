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
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await db.collection("public_profiles").doc(uid).set(publicDoc, { merge: true });
  } catch (e) {
    logger.warn("updatePublicProfile failed", { uid, error: String(e) });
  }
}

// === Takip Sayaçları: public_profiles üzerinde takipçi/takip sayısını güncelle ===
async function adjustPublicCounts(uid, { followersDelta = 0, followingDelta = 0 }) {
  if (!uid) return;
  const ref = db.collection("public_profiles").doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const d = snap.exists ? (snap.data() || {}) : {};
    const currFollowers = typeof d.followersCount === "number" ? d.followersCount : 0;
    const currFollowing = typeof d.followingCount === "number" ? d.followingCount : 0;
    const nextFollowers = Math.max(0, currFollowers + followersDelta);
    const nextFollowing = Math.max(0, currFollowing + followingDelta);
    tx.set(ref, {
      followersCount: nextFollowers,
      followingCount: nextFollowing,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });
}

exports.onFollowerCreated = onDocumentCreated({
  document: "users/{userId}/followers/{followerId}",
  region: "us-central1"
}, async (event) => {
  const uid = event.params.userId;
  try { await adjustPublicCounts(uid, { followersDelta: +1 }); } catch (e) { logger.warn("onFollowerCreated failed", { uid, error: String(e) }); }
});

exports.onFollowerDeleted = onDocumentDeleted({
  document: "users/{userId}/followers/{followerId}",
  region: "us-central1"
}, async (event) => {
  const uid = event.params.userId;
  try { await adjustPublicCounts(uid, { followersDelta: -1 }); } catch (e) { logger.warn("onFollowerDeleted failed", { uid, error: String(e) }); }
});

exports.onFollowingCreated = onDocumentCreated({
  document: "users/{userId}/following/{followingId}",
  region: "us-central1"
}, async (event) => {
  const uid = event.params.userId;
  try { await adjustPublicCounts(uid, { followingDelta: +1 }); } catch (e) { logger.warn("onFollowingCreated failed", { uid, error: String(e) }); }
});

exports.onFollowingDeleted = onDocumentDeleted({
  document: "users/{userId}/following/{followingId}",
  region: "us-central1"
}, async (event) => {
  const uid = event.params.userId;
  try { await adjustPublicCounts(uid, { followingDelta: -1 }); } catch (e) { logger.warn("onFollowingDeleted failed", { uid, error: String(e) }); }
});

exports.onUserUpdate = onDocumentUpdated("users/{userId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const uid = event.params.userId;

  const fieldsToSync = ['name', 'username', 'avatarStyle', 'avatarSeed', 'selectedExam'];
  const needsSync = fieldsToSync.some(field => before[field] !== after[field]);

  if (!needsSync) {
    logger.log(`No relevant fields changed for user ${uid}. Skipping sync.`);
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
