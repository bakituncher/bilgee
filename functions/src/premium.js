const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { admin, db } = require('./init');
const { GoogleAuth } = require('google-auth-library');

const DAILY_STAR_ALLOCATION = 100; // Default stars for premium users per day
const STAR_COST_PER_GENERATION = 10; // Example cost for a single AI generation

// This function verifies a Google Play subscription purchase and grants premium status.
exports.verifyPurchase = onCall(async (request) => {
  // Check if the user is authenticated.
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.',
    );
  }

  const { productId, purchaseToken, packageName } = request.data || {};
  const userId = request.auth.uid;

  if (!productId || !purchaseToken || !packageName) {
    throw new HttpsError(
      'invalid-argument',
      'Missing required parameters: productId, purchaseToken, or packageName.',
    );
  }

  try {
    // Initialize Google Auth client
    const auth = new GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    const authClient = await auth.getClient();

    // The Google Play Developer API endpoint for verifying subscriptions
    const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/subscriptions/${productId}/tokens/${purchaseToken}`;

    // Make the request to the Google Play Developer API
    const response = await authClient.request({ url });
    const subscription = response.data;

    // Check if the purchase was successful and the subscription is active
    if (subscription && subscription.purchaseState === 0) { // 0 indicates a purchased state
      // The subscription is valid. Grant premium status to the user.
      await db.collection('users').doc(userId).update({
        isPremium: true,
        premiumUntil: new Date(parseInt(subscription.expiryTimeMillis, 10)),
        lastPurchaseToken: purchaseToken,
      });

      console.log(`Successfully verified purchase for user ${userId}. Granted premium status.`);
      return { status: 'success', message: 'Premium status granted.' };
    } else {
      // The subscription is not valid (e.g., cancelled, expired).
      console.warn(`Failed to verify purchase for user ${userId}. Subscription not active.`);
      throw new HttpsError(
        'failed-precondition',
        'The subscription is not active or could not be verified.',
      );
    }
  } catch (error) {
    console.error(`Error verifying purchase for user ${userId}:`, error);
    // Determine if the error is from the Google API or another source
    if (error.response && error.response.data && error.response.data.error) {
      const apiError = error.response.data.error;
      console.error('Google Play API Error:', apiError);
      throw new HttpsError(
        'internal',
        `Google Play API Error: ${apiError.message}`,
        apiError.details,
      );
    }
    throw new HttpsError(
      'internal',
      'An unexpected error occurred while verifying the purchase.',
    );
  }
});

// Scheduled function to allocate daily stars to premium users.
exports.dailyStarAllocation = onSchedule('every 24 hours', async () => {
  const usersRef = db.collection('users');
  const premiumUsersSnapshot = await usersRef.where('isPremium', '==', true).get();

  if (premiumUsersSnapshot.empty) {
    console.log('No premium users found to allocate stars.');
    return null;
  }

  // Use a batched write to update all premium users at once.
  const batch = db.batch();
  premiumUsersSnapshot.forEach((doc) => {
    const userRef = usersRef.doc(doc.id);
    batch.update(userRef, { stars: DAILY_STAR_ALLOCATION });
  });

  try {
    await batch.commit();
    console.log(`Successfully allocated ${DAILY_STAR_ALLOCATION} stars to ${premiumUsersSnapshot.size} premium users.`);
  } catch (error) {
    console.error('Error allocating daily stars:', error);
  }
  return null;
});

// Callable function for AI generation that deducts stars.
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

      const currentStars = userData.stars || 0;
      if (currentStars < STAR_COST_PER_GENERATION) {
        throw new HttpsError('resource-exhausted', 'You do not have enough stars for this action.');
      }

      const newStars = currentStars - STAR_COST_PER_GENERATION;
      transaction.update(userRef, { stars: newStars });
    });

    console.log(`Successfully deducted ${STAR_COST_PER_GENERATION} stars from user ${userId}.`);
    return { status: 'success', message: 'Stars deducted successfully.' };
  } catch (error) {
    console.error(`Error in generateGemini for user ${userId}:`, error);
    // Re-throw HttpsError so the client gets a meaningful error.
    if (error instanceof HttpsError) {
      throw error;
    }
    // For other errors, throw a generic internal error.
    throw new HttpsError('internal', 'An unexpected error occurred.');
  }
});