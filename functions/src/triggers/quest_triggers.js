const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { db, admin } = require("../init");
const { nowIstanbul } = require("../utils");

/**
 * Yardımcı Fonksiyon: Günlük Görev İlerlemesini Güncelle
 * @param {string} uid Kullanıcı ID
 * @param {string} category Görev kategorisi (study, practice, focus, test_submission)
 * @param {number} amount İlerleme miktarı
 * @param {string} routeKey (Opsiyonel) Route filtresi
 * @param {string[]} tags (Opsiyonel) Etiket filtreleri
 */
async function updateDailyQuestProgress(uid, category, amount, routeKey = null, tags = []) {
  if (!amount || amount <= 0) return;

  const questColRef = db.collection("users").doc(uid).collection("daily_quests");

  // Aktif ve ilgili kategorideki görevleri çek
  const query = questColRef
    .where("category", "==", category)
    .where("isCompleted", "==", false);

  const querySnap = await query.get();
  if (querySnap.empty) return;

  const batch = db.batch();
  let updatedCount = 0;

  for (const doc of querySnap.docs) {
    const quest = doc.data();

    // Filtreleme Kontrolleri

    // 1. Route Key Kontrolü
    if (routeKey) {
      const qRoute = quest.routeKey;
      const qAction = quest.actionRoute || "";
      // Görevin routeKey'i veya actionRoute'u eşleşmeli
      if (qRoute !== routeKey && !qAction.includes(routeKey)) {
        continue;
      }
    }

    // 2. Tag Kontrolü (Varsa)
    if (tags && tags.length > 0) {
      const qTags = quest.tags || [];
      // Görevin etiketlerinden en az biri, parametre olarak gelen taglerden biriyle eşleşmeli
      // (OR mantığı: Herhangi biri tutarsa ilerler)
      const hasMatchingTag = tags.some((t) => qTags.includes(t));

      // Ancak bazı özel durumlarda daha katı kontrol gerekebilir.
      // Şimdilik "Broad Match" yapıyoruz.
      if (!hasMatchingTag) {
        continue;
      }
    }

    // İlerleme Kaydet
    const current = Number(quest.currentProgress || 0);
    const goal = Number(quest.goalValue || 1);
    const newProgress = current + amount;
    const isCompleted = newProgress >= goal;

    const updateData = {
      currentProgress: newProgress,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      isCompleted: isCompleted,
    };

    if (isCompleted) {
      updateData.completionDate = admin.firestore.FieldValue.serverTimestamp();
    }

    batch.update(doc.ref, updateData);
    updatedCount++;
  }

  if (updatedCount > 0) {
    await batch.commit();
    console.log(`[QuestTrigger] Updated ${updatedCount} quests for user ${uid} (Cat: ${category})`);
  }
}

/**
 * Trigger: Yeni Test Sonucu Eklendiğinde
 * Hedef: 'test_submission' ve 'practice' görevlerini ilerlet
 */
exports.onTestCreated = onDocumentCreated("tests/{testId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const testData = snapshot.data();
  const uid = testData.userId;
  if (!uid) return;

  // 1. 'test_submission' görevlerini ilerlet (1 adet test çözüldü)
  await updateDailyQuestProgress(uid, "test_submission", 1, null, ["test", "analysis"]);

  // 2. 'practice' görevlerini ilerlet (Soru sayısı kadar)
  const questionCount = Number(testData.correctCount || 0) + Number(testData.incorrectCount || 0) + Number(testData.emptyCount || 0);
  if (questionCount > 0) {
    const tags = ["practice"];
    // Derse özel etiket ekle (örn: 'matematik', 'tarih')
    if (testData.lessonName) {
      tags.push(testData.lessonName.toLowerCase());
    }
    // Konuya özel etiket ekle
    if (testData.topicName) {
      tags.push(testData.topicName.toLowerCase());
    }

    await updateDailyQuestProgress(uid, "practice", questionCount, "coach", tags);
  }
});

/**
 * Trigger: Yeni Pomodoro Seansı Tamamlandığında
 * Hedef: 'focus' ve 'study' görevlerini ilerlet
 */
exports.onFocusSessionCreated = onDocumentCreated("focusSessions/{sessionId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const session = snapshot.data();
  const uid = session.userId;
  // Sadece tamamlanmış seansları say
  if (!uid || session.status !== "completed") return;

  const durationSeconds = Number(session.duration || 0);
  const minutes = Math.floor(durationSeconds / 60);

  if (minutes > 0) {
    // 1. 'focus' görevleri (Pomodoro odaklı)
    await updateDailyQuestProgress(uid, "focus", minutes, "pomodoro", ["pomodoro", "deep_work"]);

    // 2. 'study' görevleri (Genel çalışma süresi)
    await updateDailyQuestProgress(uid, "study", minutes, "pomodoro", ["intensive", "productivity"]);
  }
});
