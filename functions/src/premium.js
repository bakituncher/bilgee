const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { admin, db } = require('./init');
const { GoogleAuth } = require('google-auth-library');

// Günlük kota ve işlem maliyeti
const DAILY_STAR_ALLOCATION = 100; // Premium kullanıcı başına günlük kota
const STAR_COST_PER_GENERATION = 1; // Tek işlem maliyeti

// İstanbul (Europe/Istanbul) gün anahtarı üretimi
function getIstanbulDayKey(date = new Date()) {
  // en-CA => YYYY-MM-DD sıralamasını kolaylaştırır
  const fmt = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Istanbul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const parts = fmt.formatToParts(date);
  const y = parts.find((p) => p.type === 'year').value;
  const m = parts.find((p) => p.type === 'month').value;
  const d = parts.find((p) => p.type === 'day').value;
  return `${y}-${m}-${d}`;
}

// Kullanıcı belgesi üzerinde günlük kota gerekirse sıfırla (İstanbul gününe göre)
async function ensureDailyResetInTxn(transaction, userRef, userData) {
  const now = admin.firestore.Timestamp.now();
  const todayKey = getIstanbulDayKey(now.toDate());
  const lastResetAt = userData.starsLastResetAt; // Firestore Timestamp olabilir

  // Yeni premium kullanıcı veya hiç alan yoksa başlangıç ataması yap
  if (userData.stars === undefined || userData.stars === null || !lastResetAt) {
    transaction.update(userRef, {
      stars: DAILY_STAR_ALLOCATION,
      starsLastResetAt: now,
    });
    return { stars: DAILY_STAR_ALLOCATION, reset: true };
  }

  const lastKey = getIstanbulDayKey(lastResetAt.toDate());
  if (lastKey !== todayKey) {
    transaction.update(userRef, {
      stars: DAILY_STAR_ALLOCATION,
      starsLastResetAt: now,
    });
    return { stars: DAILY_STAR_ALLOCATION, reset: true };
  }

  return { stars: userData.stars, reset: false };
}

// Google Play satın alma doğrulaması ve premium verme
exports.verifyPurchase = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const { productId, purchaseToken, packageName } = request.data || {};
  const userId = request.auth.uid;

  if (!productId || !purchaseToken || !packageName) {
    throw new HttpsError('invalid-argument', 'Missing required parameters: productId, purchaseToken, or packageName.');
  }

  try {
    const auth = new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
    const authClient = await auth.getClient();

    // Abonelik doğrulama endpointi
    const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/subscriptions/${productId}/tokens/${purchaseToken}`;
    const response = await authClient.request({ url });
    const subscription = response.data || {};

    const expiryMs = Number(subscription.expiryTimeMillis || 0);
    const isActive = Number.isFinite(expiryMs) && expiryMs > Date.now();

    if (!isActive) {
      console.warn(`Subscription not active for user ${userId}. Data:`, subscription);
      throw new HttpsError('failed-precondition', 'The subscription is not active or could not be verified.');
    }

    // Mümkünse acknowledge etmeyi dene (idempotent)
    try {
      if (subscription.acknowledgementState === 0) {
        const ackUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/subscriptions/${productId}/tokens/${purchaseToken}:acknowledge`;
        await authClient.request({ url: ackUrl, method: 'POST', data: { developerPayload: userId } });
      }
    } catch (ackErr) {
      console.warn('Acknowledge attempt failed (ignored):', ackErr?.message || ackErr);
    }

    // Premium ver
    await db.collection('users').doc(userId).update({
      isPremium: true,
      premiumUntil: new Date(expiryMs),
      lastPurchaseToken: purchaseToken,
    });

    console.log(`Successfully verified purchase for user ${userId}. Granted premium status until ${new Date(expiryMs).toISOString()}.`);
    return { status: 'success', message: 'Premium status granted.' };
  } catch (error) {
    console.error(`Error verifying purchase for user ${userId}:`, error);
    if (error.response && error.response.data && error.response.data.error) {
      const apiError = error.response.data.error;
      console.error('Google Play API Error:', apiError);
      throw new HttpsError('internal', `Google Play API Error: ${apiError.message}`, apiError.details);
    }
    throw new HttpsError('internal', 'An unexpected error occurred while verifying the purchase.');
  }
});

// İstanbul saatine göre her gece 00:00'da tüm premium kullanıcıların kotasını 100'e sıfırlar
exports.dailyStarAllocation = onSchedule({ schedule: '0 0 * * *', timeZone: 'Europe/Istanbul' }, async () => {
  const usersRef = db.collection('users');
  const premiumUsersSnapshot = await usersRef.where('isPremium', '==', true).get();

  if (premiumUsersSnapshot.empty) {
    console.log('No premium users found to allocate stars.');
    return null;
  }

  const batch = db.batch();
  const now = admin.firestore.Timestamp.now();
  premiumUsersSnapshot.forEach((doc) => {
    const userRef = usersRef.doc(doc.id);
    batch.update(userRef, { stars: DAILY_STAR_ALLOCATION, starsLastResetAt: now });
  });

  try {
    await batch.commit();
    console.log(`Successfully allocated ${DAILY_STAR_ALLOCATION} stars to ${premiumUsersSnapshot.size} premium users.`);
  } catch (error) {
    console.error('Error allocating daily stars:', error);
  }
  return null;
});

// Genel amaçlı kullanım düşümü (adil kullanım kotası)
exports.chargeUsage = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const userId = request.auth.uid;
  const amount = Math.max(1, parseInt((request.data && request.data.amount) || 1, 10));
  const userRef = db.collection('users').doc(userId);

  try {
    let remainingAfter;
    await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) {
        throw new HttpsError('not-found', 'User document not found.');
      }
      const userData = userDoc.data();
      if (!userData.isPremium) {
        throw new HttpsError('failed-precondition', 'This feature is only available to premium users.');
      }

      const { stars: ensuredStars } = await ensureDailyResetInTxn(transaction, userRef, userData);
      const current = ensuredStars;

      if (current < amount) {
        throw new HttpsError('resource-exhausted', 'You do not have enough daily quota for this action.');
      }

      remainingAfter = current - amount;
      transaction.update(userRef, { stars: remainingAfter });
    });

    console.log(`Charged ${amount} from user ${userId}. Remaining: ${remainingAfter}`);
    return { status: 'success', remaining: remainingAfter };
  } catch (error) {
    console.error(`Error in chargeUsage for user ${userId}:`, error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError('internal', 'An unexpected error occurred.');
  }
});

// AI üretimi için özel uç nokta (geriye dönük uyumluluk)
exports.generateGemini = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const userId = request.auth.uid;
  const userRef = db.collection('users').doc(userId);

  try {
    await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) {
        throw new HttpsError('not-found', 'User document not found.');
      }
      const userData = userDoc.data();
      if (!userData.isPremium) {
        throw new HttpsError('failed-precondition', 'This feature is only available to premium users.');
      }

      const { stars: ensuredStars } = await ensureDailyResetInTxn(transaction, userRef, userData);

      if (ensuredStars < STAR_COST_PER_GENERATION) {
        throw new HttpsError('resource-exhausted', 'You do not have enough daily quota for this action.');
      }

      const newStars = ensuredStars - STAR_COST_PER_GENERATION;
      transaction.update(userRef, { stars: newStars });
    });

    console.log(`Successfully deducted ${STAR_COST_PER_GENERATION} stars from user ${userId}.`);
    return { status: 'success', message: 'Stars deducted successfully.' };
  } catch (error) {
    console.error(`Error in generateGemini for user ${userId}:`, error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError('internal', 'An unexpected error occurred.');
  }
});