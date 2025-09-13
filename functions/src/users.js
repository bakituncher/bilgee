const { db } = require("./init");
const { dayKeyIstanbul, nowIstanbul } = require("./utils");

async function computeInactivityHours(userRef) {
  // user_activity bugun ve dunden kontrol edilir; yoksa app_state.lastActiveTs kullan
  try {
    const now = nowIstanbul();
    const ids = [];
    const today = dayKeyIstanbul(now);
    const y = new Date(now);
    y.setDate(now.getDate() - 1);
    const yesterday = dayKeyIstanbul(y);
    ids.push(today, yesterday);
    let lastTs = 0;
    for (const id of ids) {
      const snap = await userRef.collection("user_activity").doc(id).get();
      if (snap.exists) {
        const data = snap.data() || {};
        const visits = Array.isArray(data.visits) ? data.visits : [];
        for (const v of visits) {
          const t = typeof v === "number" ? v : (v && (v.ts || v.t)) || 0;
          if (typeof t === "number" && t > lastTs) lastTs = t;
        }
      }
    }
    if (lastTs === 0) {
      const app = await userRef.collection("state").doc("app_state").get();
      const t = app.exists ? (app.data() || {}).lastActiveTs : 0;
      if (typeof t === "number") lastTs = t;
    }
    if (lastTs === 0) return 1e6; // bilinmiyorsa çok uzun kabul et
    const diffMs = now.getTime() - lastTs;
    return Math.max(0, Math.floor(diffMs / (1000 * 60 * 60)));
  } catch (_) {
    return 1e6;
  }
}

async function selectAudienceUids(audience) {
  let query = db.collection("users");
  const lc = (s) => (typeof s === "string" ? s.toLowerCase() : s);
  if (audience && audience.type === "exam" && audience.examType) {
    const exam = lc(audience.examType);
    query = query.where("selectedExam", "==", exam);
    const snap = await query.select().limit(20000).get();
    return snap.docs.map((d) => d.id);
  }
  if (audience && audience.type === "exams" && Array.isArray(audience.exams) && audience.exams.length > 0) {
    const exams = audience.exams.filter((x) => typeof x === "string").map((s) => s.toLowerCase());
    if (exams.length === 0) {
      const snap = await db.collection("users").select().limit(20000).get();
      return snap.docs.map((d) => d.id);
    }
    if (exams.length <= 10) {
      const snap = await db.collection("users").where("selectedExam", "in", exams).select().limit(20000).get();
      return snap.docs.map((d) => d.id);
    }
    // 10'dan fazlaysa basit filtreleme (tüm kullanıcıları çekip bellekte filtreleyin)
    const all = await db.collection("users").select("selectedExam").limit(20000).get();
    return all.docs.filter((d) => exams.includes((d.data() || {}).selectedExam)).map((d) => d.id);
  }
  if (audience && audience.type === "uids" && Array.isArray(audience.uids)) {
    return audience.uids.filter((x) => typeof x === "string");
  }
  const snap = await query.select().limit(20000).get();
  return snap.docs.map((d) => d.id);
}

module.exports = {
  computeInactivityHours,
  selectAudienceUids,
};
