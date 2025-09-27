const { onCall, HttpsError } = require("firebase-functions/v2/https");
const sanitizeHtml = require("sanitize-html");
const validator = require("validator");
const { admin, auth, db, messaging } = require("./init");
const { logAdminAction } = require("./utils");

// ---- ADMIN CLAIM YÖNETİMİ ----
async function getSuperAdmins() {
  try {
    const snap = await db.collection('config').doc('super_admins').get();
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
    const email = (user.email || '').toLowerCase();
    if (!email) return false;
    const allow = await getSuperAdmins();
    return allow.includes(email);
  } catch (_) {
    return false;
  }
}

exports.setAdminClaim = onCall({
  region: 'us-central1',
  rateLimits: {
    maxCalls: 10,
    timeFrameSeconds: 60,
  },
}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
  const isSuper = await isSuperAdmin(request.auth.uid);
  if (!isSuper) throw new HttpsError('permission-denied', 'Bu işlem için süper admin yetkisi gereklidir.');

  const uid = request.data?.uid;
  const makeAdmin = !!request.data?.makeAdmin;
  if (typeof uid !== 'string' || uid.length < 6) {
    throw new HttpsError('invalid-argument', 'Geçerli uid gerekli');
  }
  const target = await auth.getUser(uid);
  const existing = target.customClaims || {};
  const newClaims = {...existing, admin: makeAdmin};
  await auth.setCustomUserClaims(uid, newClaims);
  if (makeAdmin === false) {
    // Revoke tokens to force re-login and claim refresh
    await auth.revokeRefreshTokens(uid);
  }

  await logAdminAction(request.auth.uid, "SET_ADMIN_CLAIM", {
    targetUid: uid,
    makeAdmin,
  });

  return {ok: true, uid, admin: makeAdmin};
});

exports.setSelfAdmin = onCall({
  region: 'us-central1',
  rateLimits: {
    maxCalls: 5,
    timeFrameSeconds: 60,
  },
}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
  const allowed = await isSuperAdmin(request.auth.uid);
  if (!allowed) throw new HttpsError('permission-denied', 'Yetki yok');
  const uid = request.auth.uid;
  const me = await auth.getUser(uid);
  const existing = me.customClaims || {};
  await auth.setCustomUserClaims(uid, {...existing, admin: true});

  await logAdminAction(uid, "SET_SELF_ADMIN_CLAIM");

  return {ok: true, uid, admin: true};
});

exports.getUsers = onCall({
  region: 'us-central1',
  rateLimits: {
    maxCalls: 20,
    timeFrameSeconds: 60,
  },
}, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
    const isSuper = await isSuperAdmin(request.auth.uid);
    const isAdmin = request.auth.token && request.auth.token.admin === true;
    if (!isSuper && !isAdmin) throw new HttpsError('permission-denied', 'Admin yetkisi gerekli');

    const superAdminEmails = await getSuperAdmins();
    const pageSize = 100;
    const pageToken = request.data?.pageToken;
    const listUsersResult = await auth.listUsers(pageSize, pageToken);

    const users = listUsersResult.users
        .filter(user => !superAdminEmails.includes((user.email || '').toLowerCase()))
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
        nextPageToken: listUsersResult.pageToken
    };
});

async function _getAudienceQuery(audience) {
    let query = db.collection('users');

    switch (audience.type) {
        case 'exams':
            if (audience.exams && audience.exams.length > 0) {
                query = query.where('selectedExam', 'in', audience.exams);
            }
            break;
        case 'uids':
            if (audience.uids && audience.uids.length > 0) {
                query = query.where(admin.firestore.FieldPath.documentId(), 'in', audience.uids);
            }
            break;
        case 'inactive':
            const hours = audience.hours || 24;
            const inactiveSince = new Date(Date.now() - hours * 60 * 60 * 1000);
            query = query.where('lastStreakUpdate', '<=', inactiveSince);
            break;
        case 'all':
            break;
        default:
            throw new HttpsError('invalid-argument', 'Geçersiz kitle türü');
    }

    if (audience.platforms && audience.platforms.length > 0) {
        // This requires storing platform info in the user document, which might not exist.
        // Skipping for now.
    }
    if (audience.buildMin) {
        // This requires storing build number in the user document.
        // Skipping for now.
    }

    return query;
}

exports.adminEstimateAudience = onCall({
  region: 'us-central1',
  rateLimits: {
    maxCalls: 30,
    timeFrameSeconds: 60,
  },
}, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
    const allowed = await isSuperAdmin(request.auth.uid);
    if (!allowed) throw new HttpsError('permission-denied', 'Yetki yok');

    const audience = request.data.audience;
    if (!audience) {
        throw new HttpsError('invalid-argument', 'Kitle bilgisi eksik');
    }

    const query = await _getAudienceQuery(audience);
    const snapshot = await query.count().get();
    const count = snapshot.data().count;

    // tokenHolders is harder to get accurately without fetching all tokens.
    // We'll assume it's the same as the user count for an estimate.
    return { users: count, tokenHolders: count };
});

exports.adminSendPush = onCall({
  region: 'us-central1',
  rateLimits: {
    maxCalls: 5,
    timeFrameSeconds: 60,
  },
}, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
    const allowed = await isSuperAdmin(request.auth.uid);
    if (!allowed) throw new HttpsError('permission-denied', 'Yetki yok');

    const { title, body, route, imageUrl, audience, sendType } = request.data;

    const sanitizedTitle = sanitizeHtml(title, {
      allowedTags: [],
      allowedAttributes: {},
    });

    const sanitizedBody = sanitizeHtml(body, {
      allowedTags: [],
      allowedAttributes: {},
    });

    if (!sanitizedTitle || !sanitizedBody) {
        throw new HttpsError('invalid-argument', 'Başlık ve içerik gerekli');
    }

    if (imageUrl && !validator.isURL(imageUrl)) {
      throw new HttpsError('invalid-argument', 'Geçersiz resim URL adresi');
    }

    const query = await _getAudienceQuery(audience);
    const usersSnapshot = await query.get();
    const totalUsers = usersSnapshot.size;

    if (totalUsers === 0) {
        return { ok: true, totalSent: 0, totalUsers: 0 };
    }

    const tokenPromises = usersSnapshot.docs.map(doc =>
        db.collection('users').doc(doc.id).collection('fcm_tokens').get()
    );

    const tokenSnapshots = await Promise.all(tokenPromises);
    const allTokens = tokenSnapshots.flatMap(snap => snap.docs.map(doc => doc.id));

    if (allTokens.length === 0) {
        return { ok: true, totalSent: 0, totalUsers: totalUsers, message: 'Kullanıcılar için token bulunamadı' };
    }

    const uniqueTokens = [...new Set(allTokens)];

    const message = {
        notification: {
            title: sanitizedTitle,
            body: sanitizedBody,
        },
        android: {
            notification: {
                imageUrl: imageUrl
            }
        },
        apns: {
            payload: {
                aps: {
                    'mutable-content': 1
                }
            },
            fcm_options: {
                image: imageUrl
            }
        },
        data: {
            route: route || '/home',
        },
        tokens: uniqueTokens,
    };

    const response = await messaging.sendEachForMulticast(message);

    const successCount = response.successCount;
    const failureCount = response.failureCount;

    console.log(`Push sent. Success: ${successCount}, Failure: ${failureCount}`);

  await logAdminAction(request.auth.uid, "ADMIN_SEND_PUSH", {
    title: sanitizedTitle,
    body: sanitizedBody,
    route,
    imageUrl: imageUrl || null,
    audience,
    successCount,
    failureCount,
  });

    return { ok: true, totalSent: successCount, totalUsers: totalUsers };
});

exports.findUserByEmail = onCall({
  region: 'us-central1',
  rateLimits: {
    maxCalls: 30,
    timeFrameSeconds: 60,
  },
}, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
    const isSuper = await isSuperAdmin(request.auth.uid);
    const isAdmin = request.auth.token && request.auth.token.admin === true;
    if (!isSuper && !isAdmin) throw new HttpsError('permission-denied', 'Admin yetkisi gerekli');

    const email = request.data?.email;
    if (!email) {
        throw new HttpsError('invalid-argument', 'Email adresi gerekli');
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
        if (error.code === 'auth/user-not-found') {
            return null;
        }
        throw new HttpsError('internal', 'Kullanıcı aranırken bir hata oluştu.');
    }
});

exports.isCurrentUserSuperAdmin = onCall({
  region: 'us-central1',
  rateLimits: {
    maxCalls: 30,
    timeFrameSeconds: 60,
  },
}, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
    return { isSuperAdmin: await isSuperAdmin(request.auth.uid) };
});
