const { onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
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

exports.onFollowerCreated = onDocumentCreated("users/{userId}/followers/{followerId}", async (event) => {
  const uid = event.params.userId;
  try { await adjustPublicCounts(uid, { followersDelta: +1 }); } catch (e) { logger.warn("onFollowerCreated failed", { uid, error: String(e) }); }
});
exports.onFollowerDeleted = onDocumentDeleted("users/{userId}/followers/{followerId}", async (event) => {
  const uid = event.params.userId;
  try { await adjustPublicCounts(uid, { followersDelta: -1 }); } catch (e) { logger.warn("onFollowerDeleted failed", { uid, error: String(e) }); }
});
exports.onFollowingCreated = onDocumentCreated("users/{userId}/following/{followingId}", async (event) => {
  const uid = event.params.userId;
  try { await adjustPublicCounts(uid, { followingDelta: +1 }); } catch (e) { logger.warn("onFollowingCreated failed", { uid, error: String(e) }); }
});
exports.onFollowingDeleted = onDocumentDeleted("users/{userId}/following/{followingId}", async (event) => {
  const uid = event.params.userId;
  try { await adjustPublicCounts(uid, { followingDelta: -1 }); } catch (e) { logger.warn("onFollowingDeleted failed", { uid, error: String(e) }); }
});

module.exports = {
  ...exports,
  updatePublicProfile,
};
