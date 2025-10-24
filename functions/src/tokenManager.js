const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { db, admin } = require("./init");

// ---- FCM TOKEN KAYDI ----
exports.registerFcmToken = onCall({ region: "us-central1", enforceAppCheck: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const uid = request.auth.uid;
  const token = String(request.data?.token || "");
  const platform = String(request.data?.platform || "unknown");
  const lang = String(request.data?.lang || "tr");
  if (!token || token.length < 10) throw new HttpsError("invalid-argument", "Geçerli token gerekli");
  const deviceId = token.replace(/[^a-zA-Z0-9_-]/g, "").slice(0, 140);
  const appVersion = request.data?.appVersion ? String(request.data.appVersion) : null;
  const appBuild = request.data?.appBuild != null ? Number(request.data.appBuild) : null;
  const ref = db.collection("users").doc(uid).collection("devices").doc(deviceId);
  await ref.set({
    uid,
    token,
    platform,
    lang,
    disabled: false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(appVersion ? { appVersion } : {}),
    ...(Number.isFinite(appBuild) ? { appBuild } : {}),
  }, { merge: true });
  return { ok: true };
});

// ---- FCM TOKEN TEMİZLEME ----
exports.unregisterFcmToken = onCall({ region: "us-central1", enforceAppCheck: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const uid = request.auth.uid;
  const token = String(request.data?.token || "");
  if (!token || token.length < 10) throw new HttpsError("invalid-argument", "Geçerli token gerekli");

  try {
    // Token'a sahip tüm cihaz kayıtlarını bul ve devre dışı bırak
    const devicesRef = db.collection("users").doc(uid).collection("devices");
    const snapshot = await devicesRef.where("token", "==", token).get();

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        disabled: true,
        unregisteredAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    if (!snapshot.empty) {
      await batch.commit();
      logger.info("FCM token unregistered", { uid, tokenLength: token.length, devicesUpdated: snapshot.size });
    }

    return { ok: true, devicesUpdated: snapshot.size };
  } catch (error) {
    logger.error("FCM token unregister failed", { uid, error: String(error) });
    throw new HttpsError("internal", "Token temizleme işlemi başarısız");
  }
});

async function getActiveTokens(uid) {
  const snap = await db.collection("users").doc(uid).collection("devices").where("disabled", "==", false).limit(50).get();
  if (snap.empty) return [];
  const list = snap.docs.map((d)=> (d.data()||{}).token).filter(Boolean);
  return Array.from(new Set(list));
}

async function getActiveTokensFiltered(uid, filters = {}) {
  try {
    const platforms = Array.isArray(filters.platforms) ? filters.platforms.filter((x)=> typeof x === "string" && x).map((s)=> s.toLowerCase()) : [];
    // Firestore'da sadece basit filtre: disabled ve (opsiyonel) platform in
    let q = db.collection("users").doc(uid).collection("devices").where("disabled", "==", false);
    if (platforms.length > 0 && platforms.length <= 10) q = q.where("platform", "in", platforms);

    // Limit makul bir değerde tutulur; kullanıcı başına çok az cihaz vardır.
    const snap = await q.limit(200).get();
    if (snap.empty) return [];

    const buildMin = Number.isFinite(filters.buildMin) ? Number(filters.buildMin) : null;
    const buildMax = Number.isFinite(filters.buildMax) ? Number(filters.buildMax) : null;

    const list = [];
    for (const d of snap.docs) {
      const it = d.data() || {};
      const build = typeof it.appBuild === "number" ? it.appBuild : (typeof it.appBuild === "string" ? Number(it.appBuild) : null);
      // Build filtrelerini bellek içinde uygula; alan yoksa 0 varsayalım
      const b = Number.isFinite(build) ? Number(build) : 0;
      if (buildMin !== null && !(b >= buildMin)) continue;
      if (buildMax !== null && !(b <= buildMax)) continue;
      if (it.token) list.push(it.token);
    }
    return Array.from(new Set(list));
  } catch (e) {
    // Aşırı durumlarda güvenli geri dönüş
    logger.error("getActiveTokensFiltered failed, fallback to unfiltered", { error: String(e) });
    const all = await db.collection("users").doc(uid).collection("devices").where("disabled", "==", false).limit(200).get();
    if (all.empty) return [];
    const buildMin = Number.isFinite(filters.buildMin) ? Number(filters.buildMin) : null;
    const buildMax = Number.isFinite(filters.buildMax) ? Number(filters.buildMax) : null;
    const platforms = Array.isArray(filters.platforms) ? filters.platforms.filter((x)=> typeof x === "string" && x).map((s)=> s.toLowerCase()) : [];
    const list = [];
    for (const d of all.docs) {
      const it = d.data() || {};
      if (platforms.length > 0 && !platforms.includes(String(it.platform || "").toLowerCase())) continue;
      const build = typeof it.appBuild === "number" ? it.appBuild : (typeof it.appBuild === "string" ? Number(it.appBuild) : null);
      const b = Number.isFinite(build) ? Number(build) : 0;
      if (buildMin !== null && !(b >= buildMin)) continue;
      if (buildMax !== null && !(b <= buildMax)) continue;
      if (it.token) list.push(it.token);
    }
    return Array.from(new Set(list));
  }
}

module.exports = {
  registerFcmToken: exports.registerFcmToken,
  unregisterFcmToken: exports.unregisterFcmToken,
  getActiveTokens,
  getActiveTokensFiltered,
};
