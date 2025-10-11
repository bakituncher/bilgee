const { onRequest, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { db } = require("./init");
const { defineSecret } = require('firebase-functions/params');

const REVENUECAT_WEBHOOK_SECRET = defineSecret('REVENUECAT_WEBHOOK_SECRET');

exports.handleRevenueCatWebhook = onRequest(
  { region: 'us-central1', timeoutSeconds: 30, memory: '256MiB', secrets: [REVENUECAT_WEBHOOK_SECRET] },
  async (req, res) => {
    // 1. Authorization check
    const authHeader = req.headers.authorization || '';
    if (authHeader !== `Bearer ${REVENUECAT_WEBHOOK_SECRET.value()}`) {
      logger.warn('Unauthorized webhook attempt', { authHeader });
      res.status(401).send('Unauthorized');
      return;
    }

    // 2. Event processing
    const event = req.body;
    const userId = event?.event?.app_user_id;

    if (!userId) {
      logger.warn('Webhook received without a user ID.', { event });
      res.status(400).send('Bad Request: Missing user ID.');
      return;
    }

    logger.info(`Processing webhook for user ${userId}`, { type: event.event.type });

    try {
      // BEST PRACTICE: Fetch the latest subscriber info from RevenueCat REST API
      // This avoids complex logic for handling different event types and ensures data is always canonical.
      // For this exercise, we'll simulate this by directly using the webhook data, but a real implementation should call the API.

      const entitlements = event?.event?.entitlements || {};
      const premiumEntitlement = Object.values(entitlements).find(e => e.product_identifier.includes('premium')); // Adjust identifier as needed

      let isPremium = false;
      let premiumUntil = null;

      if (premiumEntitlement && premiumEntitlement.expires_date_ms) {
        const expiration = new Date(premiumEntitlement.expires_date_ms);
        if (expiration > new Date()) {
          isPremium = true;
          premiumUntil = expiration;
        }
      }

      const userRef = db.collection('users').doc(userId);
      const historyRef = userRef.collection('purchase_history').doc(event.event.id); // Use event ID for idempotency

      const batch = db.batch();

      // 1. Update the main user document
      batch.set(userRef, {
        isPremium: isPremium,
        premiumUntil: premiumUntil,
        lastRevenueCatEvent: event.event.type,
      }, { merge: true });

      // 2. Log the historical event
      batch.set(historyRef, {
        ...event.event,
        processedAt: new Date(),
      });

      await batch.commit();

      logger.info(`Updated premium status and logged event for user ${userId}`, { isPremium, premiumUntil: premiumUntil?.toISOString(), eventId: event.event.id });

      res.status(200).send({ received: true, processed: true });
    } catch (error) {
      logger.error(`Error processing webhook for user ${userId}`, { error: error.toString(), event });
      res.status(500).send('Internal Server Error');
    }
  }
);
