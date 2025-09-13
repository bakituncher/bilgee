const { onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { db, admin } = require("./init");

// Yeni: Soru bildirimi oluşturulunca indeks güncelle
exports.onQuestionReportCreated = onDocumentCreated("questionReports/{reportId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const d = snap.data();
  if (!d) return;
  const qhash = d.qhash;
  if (!qhash) return;

  const idxRef = db.collection("question_report_index").doc(qhash);
  await db.runTransaction(async (tx) => {
    const idx = await tx.get(idxRef);
    if (!idx.exists) {
      tx.set(idxRef, {
        qhash,
        question: d.question || "",
        options: d.options || [],
        correctIndex: d.correctIndex || -1,
        subjects: d.subject ? [d.subject] : [],
        topics: d.topic ? [d.topic] : [],
        reportCount: 1,
        sampleReasons: d.reason ? [d.reason] : [],
        lastReportedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      const updates = {
        reportCount: admin.firestore.FieldValue.increment(1),
        lastReportedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (d.subject) updates.subjects = admin.firestore.FieldValue.arrayUnion(d.subject);
      if (d.topic) updates.topics = admin.firestore.FieldValue.arrayUnion(d.topic);
      if (d.reason) updates.sampleReasons = admin.firestore.FieldValue.arrayUnion(d.reason);
      tx.update(idxRef, updates);
    }
  });
});

// Yardımcı: qhash için indeks dokümanını yeniden hesapla
async function recomputeQuestionReportIndex(qhash) {
  if (!qhash) return;
  const idxRef = db.collection("question_report_index").doc(qhash);
  // Kalan raporları çek
  const snap = await db.collection("questionReports").where("qhash", "==", qhash).limit(1000).get();
  if (snap.empty) {
    // Hiç rapor yoksa indeks dokümanını kaldır
    await idxRef.delete().catch(() => { });
    return { reportCount: 0 };
  }
  let reportCount = 0;
  const subjects = new Set();
  const topics = new Set();
  const reasons = new Set();
  let question = "";
  let options = [];
  let correctIndex = -1;

  snap.docs.forEach((d) => {
    const data = d.data() || {};
    reportCount++;
    if (!question && data.question) {
      question = data.question;
      options = Array.isArray(data.options) ? data.options : [];
      correctIndex = typeof data.correctIndex === "number" ? data.correctIndex : -1;
    }
    if (data.subject) subjects.add(String(data.subject));
    if (data.topic) topics.add(String(data.topic));
    if (data.reason) {
      if (reasons.size < 12) reasons.add(String(data.reason));
    }
  });

  const updates = {
    qhash,
    question,
    options,
    correctIndex,
    subjects: Array.from(subjects),
    topics: Array.from(topics),
    sampleReasons: Array.from(reasons),
    reportCount,
    lastReportedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await idxRef.set(updates, { merge: true });
  return updates;
}

// Silme tetikleyicisi: bir rapor silindiğinde indeksi güncel tut
exports.onQuestionReportDeleted = onDocumentDeleted("questionReports/{reportId}", async (event) => {
  const snap = event.data; // DocumentSnapshot
  const d = snap && snap.data();
  const qhash = d && d.qhash;
  if (!qhash) return;
  try {
    await recomputeQuestionReportIndex(qhash);
  } catch (e) {
    logger.warn("Index recompute failed on delete", { qhash, error: String(e) });
  }
});

// Admin: bildirimi silmek için callable (tekil veya toplu)
exports.adminDeleteQuestionReports = onCall({ region: "us-central1", timeoutSeconds: 300 }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const isAdmin = request.auth.token && request.auth.token.admin === true;
  if (!isAdmin) throw new HttpsError("permission-denied", "Admin gerekli");

  const mode = String((request.data && request.data.mode) || "single");

  if (mode === "single") {
    const reportId = String((request.data && request.data.reportId) || "");
    if (!reportId) throw new HttpsError("invalid-argument", "reportId gerekli");
    const ref = db.collection("questionReports").doc(reportId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "Rapor bulunamadı");
    const qhash = (snap.data() || {}).qhash;
    await ref.delete();
    await recomputeQuestionReportIndex(qhash);
    return { ok: true, qhash, deleted: 1 };
  }

  if (mode === "byQhash") {
    const qhash = String((request.data && request.data.qhash) || "");
    if (!qhash) throw new HttpsError("invalid-argument", "qhash gerekli");
    let total = 0;
    // Parti parti sil
    while (true) {
      const qs = await db.collection("questionReports").where("qhash", "==", qhash).limit(300).get();
      if (qs.empty) break;
      const batch = db.batch();
      qs.docs.forEach((d) => {
        batch.delete(d.ref);
        total++;
      });
      await batch.commit();
      if (qs.size < 300) break;
    }
    // İndeksi kaldır (rapor kalmadı)
    await db.collection("question_report_index").doc(qhash).delete().catch(() => { });
    return { ok: true, qhash, deleted: total };
  }

  if (mode === "indexOnly") {
    const qhash = String((request.data && request.data.qhash) || "");
    if (!qhash) throw new HttpsError("invalid-argument", "qhash gerekli");
    await db.collection("question_report_index").doc(qhash).delete();
    return { ok: true, qhash, deleted: 0 };
  }

  throw new HttpsError("invalid-argument", "Geçersiz mode");
});
