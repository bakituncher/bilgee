function nowIstanbul() {
  const now = new Date();
  try {
    return new Date(now.toLocaleString("en-US", { timeZone: "Europe/Istanbul" }));
  } catch (_) {
    return now;
  }
}

function dayKeyIstanbul(d = nowIstanbul()) {
  return `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, "0")}-${d.getDate().toString().padStart(2, "0")}`;
}

function weekKeyIstanbul(d = nowIstanbul()) {
  // Haftanın pazartesi başlangıcı (ISO) baz alınır
  const day = d.getDay(); // 0=PAZAR
  const isoMonday = new Date(d);
  const diff = day === 0 ? -6 : 1 - day;
  isoMonday.setDate(d.getDate() + diff);
  isoMonday.setHours(0, 0, 0, 0);
  return `${isoMonday.getFullYear()}-${(isoMonday.getMonth() + 1).toString().padStart(2, "0")}-${isoMonday.getDate().toString().padStart(2, "0")}`;
}

function routeKeyFromPath(pathname) {
  switch (pathname) {
    case "/home":
      return "home";
    case "/home/pomodoro":
      return "pomodoro";
    case "/coach":
      return "coach";
    case "/home/stats":
      return "stats";
    case "/home/add-test":
      return "addTest";
    case "/home/quests":
      return "quests";
    case "/ai-hub/strategic-planning":
      return "strategy";
    case "/ai-hub/weakness-workshop":
      return "workshop";
    case "/availability":
      return "availability";
    case "/profile/avatar-selection":
      return "avatar";
    case "/arena":
      return "arena";
    case "/library":
      return "library";
    case "/ai-hub/motivation-chat":
      return "motivationChat";
    default:
      return "home";
  }
}

async function computeTestAggregates(input) {
  const scores = (input && input.scores) && typeof input.scores === "object" ? input.scores : {};
  const coefRaw = typeof (input && input.penaltyCoefficient) === "number" ? input.penaltyCoefficient : Number((input && input.penaltyCoefficient));
  const penaltyCoefficient = Number.isFinite(coefRaw) ? coefRaw : 0.25;
  let totalCorrect = 0;
  let totalWrong = 0;
  let totalBlank = 0;
  let totalQuestions = 0;
  const normalizedScores = {};
  for (const [subject, m] of Object.entries(scores)) {
    const mm = m && typeof m === "object" ? m : {};
    const c = Number(mm.dogru || mm.correct || 0) | 0;
    const w = Number(mm.yanlis || mm.wrong || 0) | 0;
    const b = Number(mm.bos || mm.blank || 0) | 0;
    totalCorrect += c;
    totalWrong += w;
    totalBlank += b;
    totalQuestions += c + w + b;
    normalizedScores[subject] = { dogru: c, yanlis: w, bos: b };
  }
  const totalNet = totalCorrect - penaltyCoefficient * totalWrong;
  return {
    normalizedScores,
    totalCorrect,
    totalWrong,
    totalBlank,
    totalQuestions,
    totalNet,
    penaltyCoefficient,
  };
}

const { db } = require("./init");

async function logAdminAction(adminUid, action, data = {}) {
  if (!adminUid || !action) {
    console.error("logAdminAction: adminUid and action are required");
    return;
  }

  try {
    await db.collection("admin_logs").add({
      adminUid,
      action,
      timestamp: new Date(),
      ...data,
    });
  } catch (error) {
    console.error(`Failed to log admin action: ${action}`, error);
  }
}

module.exports = {
  nowIstanbul,
  dayKeyIstanbul,
  weekKeyIstanbul,
  routeKeyFromPath,
  computeTestAggregates,
  logAdminAction,
};
