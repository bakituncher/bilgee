const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const { db, admin, storage } = require("./init");

// Süresi dolan yazıları periyodik olarak temizle
exports.cleanupExpiredPosts = onSchedule(
  { schedule: "0 * * * *", timeZone: "Europe/Istanbul" },
  async () => {
    const nowTs = admin.firestore.Timestamp.now();
    let totalDeleted = 0;
    for (let i = 0; i < 10; i++) { // güvenli döngü, her seferinde en fazla ~1000 kayıt
      const snap = await db
        .collection("posts")
        .where("expireAt", "<=", nowTs)
        .limit(100)
        .get();
      if (snap.empty) break;

      const batch = db.batch();
      const jobs = [];
      snap.docs.forEach((doc) => {
        const data = doc.data() || {};
        const slug = data.slug || doc.id;
        // Yalnızca gerçekten yayında olup süresi dolmuşları sil
        const status = (data.status || "draft");
        if (status === "published") {
          batch.delete(doc.ref);
          jobs.push(deletePostAssetsBySlug(slug));
          totalDeleted++;
        }
      });
      await Promise.all([batch.commit(), Promise.all(jobs)]);
      if (snap.size < 100) break; // bitti
    }
    logger.info(`cleanupExpiredPosts tamamlandı. Silinen yazı: ${totalDeleted}`);
  },
);

// Bir yazı silindiğinde kapak görsellerini de temizle
exports.onPostDeletedCleanup = onDocumentDeleted({
  document: "posts/{postId}",
  region: "us-central1",
}, async (event) => {
  const snap = event.data; // DocumentSnapshot
  const slug = (snap && snap.data()?.slug) || event.params.postId;
  await deletePostAssetsBySlug(slug);
});

// Blog kapakları için storage temizliği
async function deletePostAssetsBySlug(slug) {
  if (!slug) return;
  try {
    const bucket = storage.bucket();
    const prefix = `blog_covers/${slug}/`;
    await bucket.deleteFiles({ prefix });
    logger.info(`Storage temizlendi: ${prefix}`);
  } catch (e) {
    logger.warn("Storage dosyaları temizlenemedi", { slug, error: String(e) });
  }
}
