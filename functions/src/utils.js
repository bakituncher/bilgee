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

// Yeni: Genel amaçlı oran sınırlama yardımcıları (TTL içeren)
async function enforceRateLimit(key, windowSeconds, maxCount) {
  if (!key) return;
  const ref = db.collection("rate_limits").doc(String(key));
  const now = Date.now();
  const windowMs = windowSeconds * 1000;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      tx.set(ref, { count: 1, windowStart: now, expireAt: new Date(now + 3 * 24 * 60 * 60 * 1000) });
      return;
    }
    const data = snap.data() || {};
    const count = Number(data.count || 0);
    const windowStart = typeof data.windowStart === "number" ? data.windowStart : now;
    if (now - windowStart > windowMs) {
      tx.set(ref, { count: 1, windowStart: now, expireAt: new Date(now + 3 * 24 * 60 * 60 * 1000) });
      return;
    }
    if (count >= maxCount) {
      const { HttpsError } = require("firebase-functions/v2/https");
      throw new HttpsError("resource-exhausted", "Oran sınırı aşıldı. Lütfen sonra tekrar deneyin.");
    }
    tx.update(ref, { count: count + 1, expireAt: new Date(now + 3 * 24 * 60 * 60 * 1000) });
  });
}

// Yeni: Günlük kota (YYYY-MM-DD bazlı doc ile)
async function enforceDailyQuota(key, limitPerDay) {
  const day = dayKeyIstanbul();
  const ref = db.collection("quotas").doc(`${key}_${day}`);
  let allowed = false;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      tx.set(ref, { day, count: 1, key, createdAt: new Date(), expireAt: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000) });
      allowed = true;
      return;
    }
    const data = snap.data() || {};
    const count = Number(data.count || 0);
    if (count >= limitPerDay) {
      const { HttpsError } = require("firebase-functions/v2/https");
      throw new HttpsError("resource-exhausted", "Günlük kota aşıldı");
    }
    tx.update(ref, { count: count + 1, expireAt: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000) });
    allowed = true;
  });
  return allowed;
}

function getClientIpFromRawRequest(rawRequest) {
  try {
    if (!rawRequest) return null;
    // Cloud Run/Functions arkasındaki tipik başlıklar
    const xf = rawRequest.headers && (rawRequest.headers["x-forwarded-for"] || rawRequest.headers["X-Forwarded-For"]);
    if (typeof xf === "string" && xf.length > 0) {
      const first = xf.split(",")[0].trim();
      return first || null;
    }
    if (rawRequest.ip) return rawRequest.ip;
  } catch (_) {/* ignore */}
  return null;
}

// Branş denemesi kontrolü (Dart'taki TestModel.isBranchTest mantığı)
function isBranchTest(scores, sectionName, examType) {
  if (!scores || typeof scores !== "object") return false;

  const scoreKeys = Object.keys(scores);

  // 1. Eğer sadece 1 ders varsa...
  if (scoreKeys.length === 1) {
    const subjectName = scoreKeys[0];
    // İSTİSNA: "Alan Bilgisi" veya "Temel Alan Bilgisi" -> Ana sınav
    if (subjectName === "Alan Bilgisi" || subjectName === "Temel Alan Bilgisi") {
      // DÜZELTME: Eğer bölüm isminde "(Branş)" ifadesi varsa, bu kesinlikle branş denemesidir.
      if (sectionName && sectionName.includes("(Branş)")) {
        return true;
      }
      return false;
    }
    // Diğer tek derslik durumlar branş denemesidir
    return true;
  }

  const sectionUpper = (sectionName || "").toUpperCase().trim();
  const examTypeUpper = (examType || "").toUpperCase().trim();

  // 2. Ana sınav bölümleri - Kesin liste
  const mainSections = ["TYT", "LGS", "KPSS", "AGS", "YDT", "GENEL", "TÜMÜ", "DENEME"];

  // Eğer sectionName direkt sınav türüyle aynıysa -> Ana Deneme
  if (sectionUpper === examTypeUpper) {
    return false;
  }

  // Ana sınav isimlerini içeriyorsa -> Ana Deneme
  if (mainSections.includes(sectionUpper)) {
    return false;
  }

  // "TYT GENEL", "TYT DENEME" gibi kombinasyonları yakala
  if (sectionUpper.includes("GENEL") || (sectionUpper.includes(examTypeUpper) && sectionUpper.includes("DENEME"))) {
    return false;
  }

  // AYT ve alt türleri (AYT-SAY, AYT-EA, AYT-SOZ, AYT-DIL, vs.) -> Ana Deneme
  if (sectionUpper.startsWith("AYT")) {
    return false;
  }

  // Diğer her şey branş denemesi
  return true;
}

module.exports = {
  nowIstanbul,
  dayKeyIstanbul,
  weekKeyIstanbul,
  routeKeyFromPath,
  computeTestAggregates,
  logAdminAction,
  enforceRateLimit,
  enforceDailyQuota,
  getClientIpFromRawRequest,
  isBranchTest,
};
