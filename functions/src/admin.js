const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { admin, auth, db } = require("./init");
const { logAdminAction, enforceRateLimit, getClientIpFromRawRequest } = require("./utils");

// ---- ADMIN CLAIM YÖNETİMİ ----
async function getSuperAdmins() {
  try {
    const snap = await db.collection("config").doc("super_admins").get();
    if (!snap.exists) return [];
    const data = snap.data() || {};
    const emails = Array.isArray(data.emails) ? data.emails : [];
    return Array.from(new Set(emails.map((e) => String(e).trim().toLowerCase()).filter(Boolean)));
  } catch (e) {
    console.error("Error getting super admins", e);
    return [];
  }
}

async function isSuperAdmin(uid) {
  try {
    const user = await auth.getUser(uid);
    const email = (user.email || "").toLowerCase();
    if (!email) return false;
    const allow = await getSuperAdmins();
    return allow.includes(email);
  } catch (_) {
    return false;
  }
}

exports.setAdminClaim = onCall({
  region: "us-central1",
  enforceAppCheck: true,
  maxInstances: 5,
  rateLimits: { maxCalls: 10, timeFrameSeconds: 60 },
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
  await Promise.all([
    enforceRateLimit(`admin_set_claim_uid_${request.auth.uid}`, 60, 2),
    enforceRateLimit(`admin_set_claim_ip_${ip}`, 60, 10),
  ]);

  const isSuper = await isSuperAdmin(request.auth.uid);
  if (!isSuper) throw new HttpsError("permission-denied", "Bu işlem için süper admin yetkisi gereklidir.");

  const uid = request.data?.uid;
  const makeAdmin = !!request.data?.makeAdmin;
  if (typeof uid !== "string" || uid.length < 6) {
    throw new HttpsError("invalid-argument", "Geçerli uid gerekli");
  }
  const target = await auth.getUser(uid);
  const existing = target.customClaims || {};
  const newClaims = { ...existing, admin: makeAdmin };
  await auth.setCustomUserClaims(uid, newClaims);
  if (makeAdmin === false) {
    // Revoke tokens to force re-login and claim refresh
    await auth.revokeRefreshTokens(uid);
  }

  await logAdminAction(request.auth.uid, "SET_ADMIN_CLAIM", {
    targetUid: uid,
    makeAdmin,
  });

  return { ok: true, uid, admin: makeAdmin };
});

exports.setSelfAdmin = onCall({
  region: "us-central1",
  enforceAppCheck: true,
  maxInstances: 5,
  rateLimits: { maxCalls: 5, timeFrameSeconds: 60 },
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
  await Promise.all([
    enforceRateLimit(`admin_self_uid_${request.auth.uid}`, 60, 2),
    enforceRateLimit(`admin_self_ip_${ip}`, 60, 10),
  ]);
  const allowed = await isSuperAdmin(request.auth.uid);
  if (!allowed) throw new HttpsError("permission-denied", "Yetki yok");
  const uid = request.auth.uid;
  const me = await auth.getUser(uid);
  const existing = me.customClaims || {};
  await auth.setCustomUserClaims(uid, { ...existing, admin: true });

  await logAdminAction(uid, "SET_SELF_ADMIN_CLAIM");

  return { ok: true, uid, admin: true };
});

exports.getUsers = onCall({
  region: "us-central1",
  enforceAppCheck: true,
  maxInstances: 10,
  rateLimits: { maxCalls: 20, timeFrameSeconds: 60 },
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
  await Promise.all([
    enforceRateLimit(`admin_get_users_uid_${request.auth.uid}`, 60, 30),
    enforceRateLimit(`admin_get_users_ip_${ip}`, 60, 120),
  ]);
  const isSuper = await isSuperAdmin(request.auth.uid);
  const isAdmin = request.auth.token && request.auth.token.admin === true;
  if (!isSuper && !isAdmin) throw new HttpsError("permission-denied", "Admin yetkisi gerekli");

  const superAdminEmails = await getSuperAdmins();
  const pageSize = 100;
  const pageToken = request.data?.pageToken;
  const listUsersResult = await auth.listUsers(pageSize, pageToken);

  const users = listUsersResult.users
    .filter((user) => !superAdminEmails.includes((user.email || "").toLowerCase()))
    .map((userRecord) => {
      return {
        uid: userRecord.uid,
        email: userRecord.email,
        displayName: userRecord.displayName,
        admin: !!userRecord.customClaims?.admin,
      };
    });

  return {
    users,
    nextPageToken: listUsersResult.pageToken,
  };
});

exports.findUserByEmail = onCall({
  region: "us-central1",
  enforceAppCheck: true,
  maxInstances: 10,
  rateLimits: { maxCalls: 30, timeFrameSeconds: 60 },
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
  await Promise.all([
    enforceRateLimit(`admin_find_user_uid_${request.auth.uid}`, 60, 60),
    enforceRateLimit(`admin_find_user_ip_${ip}`, 60, 240),
  ]);
  const isSuper = await isSuperAdmin(request.auth.uid);
  const isAdmin = request.auth.token && request.auth.token.admin === true;
  if (!isSuper && !isAdmin) throw new HttpsError("permission-denied", "Admin yetkisi gerekli");

  const email = request.data?.email;
  if (!email) {
    throw new HttpsError("invalid-argument", "Email adresi gerekli");
  }

  try {
    const superAdminEmails = await getSuperAdmins();
    if (superAdminEmails.includes(email.toLowerCase())) {
      return null; // Hide super admin
    }

    const userRecord = await auth.getUserByEmail(email);
    return {
      uid: userRecord.uid,
      email: userRecord.email,
      displayName: userRecord.displayName,
      admin: !!userRecord.customClaims?.admin,
    };
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      return null;
    }
    throw new HttpsError("internal", "Kullanıcı aranırken bir hata oluştu.");
  }
});

exports.isCurrentUserSuperAdmin = onCall({
  region: "us-central1",
  enforceAppCheck: true,
  maxInstances: 20,
  rateLimits: { maxCalls: 30, timeFrameSeconds: 60 },
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const ip = getClientIpFromRawRequest(request.rawRequest) || "unknown";
  await Promise.all([
    enforceRateLimit(`admin_is_super_uid_${request.auth.uid}`, 60, 60),
    enforceRateLimit(`admin_is_super_ip_${ip}`, 60, 240),
  ]);
  return { isSuperAdmin: await isSuperAdmin(request.auth.uid) };
});
