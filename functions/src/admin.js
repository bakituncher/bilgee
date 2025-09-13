const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { auth, db } = require("./init");

// ---- ADMIN CLAIM YÖNETİMİ ----
const DEFAULT_SUPER_ADMINS = ['baki@gmail.com'];
const SUPER_ADMINS = (process.env.SUPER_ADMINS || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);

async function getSuperAdmins() {
  try {
    const snap = await db.collection('config').doc('super_admins').get();
    const data = snap.exists ? (snap.data() || {}) : {};
    const emails = Array.isArray(data.emails) ? data.emails : [];
    const list = [
      ...DEFAULT_SUPER_ADMINS,
      ...SUPER_ADMINS,
      ...emails.map((e) => String(e).trim().toLowerCase()),
    ];
    // benzersizleştir
    return Array.from(new Set(list.filter(Boolean)));
  } catch (_) {
    // fallback sadece default + env
    return Array.from(new Set([...DEFAULT_SUPER_ADMINS, ...SUPER_ADMINS]));
  }
}

async function isSuperAdmin(uid) {
  try {
    const user = await auth.getUser(uid);
    const email = (user.email || '').toLowerCase();
    if (!email) return false;
    const allow = await getSuperAdmins();
    return allow.includes(email);
  } catch (_) {
    return false;
  }
}

exports.setAdminClaim = onCall({region: 'us-central1'}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
  const allowed = await isSuperAdmin(request.auth.uid);
  if (!allowed) throw new HttpsError('permission-denied', 'Yetki yok');

  const uid = request.data?.uid;
  const makeAdmin = !!request.data?.makeAdmin;
  if (typeof uid !== 'string' || uid.length < 6) {
    throw new HttpsError('invalid-argument', 'Geçerli uid gerekli');
  }
  const target = await auth.getUser(uid);
  const existing = target.customClaims || {};
  const newClaims = {...existing, admin: makeAdmin};
  await auth.setCustomUserClaims(uid, newClaims);
  return {ok: true, uid, admin: makeAdmin};
});

exports.setSelfAdmin = onCall({region: 'us-central1'}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
  const allowed = await isSuperAdmin(request.auth.uid);
  if (!allowed) throw new HttpsError('permission-denied', 'Yetki yok');
  const uid = request.auth.uid;
  const me = await auth.getUser(uid);
  const existing = me.customClaims || {};
  await auth.setCustomUserClaims(uid, {...existing, admin: true});
  return {ok: true, uid, admin: true};
});
