const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { db } = require("./init");
const { defineSecret } = require('firebase-functions/params');

const REVENUECAT_WEBHOOK_SECRET = defineSecret('REVENUECAT_WEBHOOK_SECRET');
const REVENUECAT_REST_API_KEY = defineSecret('REVENUECAT_REST_API_KEY');

exports.handleRevenueCatWebhook = onRequest(
  { region: 'us-central1', timeoutSeconds: 30, memory: '256MiB', secrets: [REVENUECAT_WEBHOOK_SECRET] },
  async (req, res) => {
    // 1. Authorization check
    const authHeader = req.headers.authorization || '';
    if (authHeader !== `Bearer ${REVENUECAT_WEBHOOK_SECRET.value()}`) {
      logger.warn('Unauthorized webhook attempt', { authHeaderPresent: !!authHeader });
      res.status(401).send('Unauthorized');
      return;
    }

    // 2. Event processing
    const event = req.body;
    const userId = event?.event?.app_user_id;

    if (!userId) {
      logger.warn('Webhook received without a user ID.', { eventType: event?.event?.type });
      res.status(400).send('Bad Request: Missing user ID.');
      return;
    }

    const eventType = event?.event?.type;
    logger.info(`Processing webhook for user ${userId}`, { type: eventType });

    try {
      // Gelen event'i logla - debug için çok yararlı
      logger.info('Received RevenueCat event body:', { event: event.event });

      const entitlements = event?.event?.entitlements || {};
      let isPremium = false;
      let latestExpiration = 0;
      const now = Date.now();
      const entitlementKeys = Object.keys(entitlements);

      for (const key of entitlementKeys) {
        const e = entitlements[key] || {};
        let expMs = 0;

        // expires_date (string, ISO 8601) veya expires_date_ms (number) olabilir
        if (typeof e.expires_date_ms === 'number') {
          expMs = e.expires_date_ms;
        } else if (typeof e.expires_date === 'string') {
          const p = Date.parse(e.expires_date);
          if (!Number.isNaN(p)) expMs = p;
        }

        const periodType = e.period_type || e.periodType;

        let active = false;
        // Son kullanma tarihi gelecekteyse veya abonelik ömür boyu ise aktiftir.
        if (expMs > now) {
          active = true;
        } else if (periodType === 'lifetime') {
          active = true;
        }

        if (active) {
          isPremium = true;
          if (expMs > latestExpiration) {
            latestExpiration = expMs;
          }
        }
         logger.debug('Entitlement evaluated', {
          userId,
          key,
          expiresMs: expMs,
          periodType,
          resolvedActive: active,
        });
      }

      const premiumUntil = isPremium && latestExpiration > 0 ? new Date(latestExpiration) : null;

      const userRef = db.collection('users').doc(userId);
      const historyRef = userRef.collection('purchase_history').doc(event.event.id); // idempotency

      const batch = db.batch();

      // 1. Update the main user document
      batch.set(
        userRef,
        {
          isPremium: isPremium,
          premiumUntil: premiumUntil,
          lastRevenueCatEvent: eventType,
          lastPremiumUpdateAt: new Date(),
        },
        { merge: true }
      );

      // 2. Log the historical event
      batch.set(historyRef, {
        ...event.event,
        processedAt: new Date(),
      });

      await batch.commit();

      logger.info(`Updated premium status and logged event for user ${userId}` , {
        isPremium,
        premiumUntil: premiumUntil ? premiumUntil.toISOString() : null,
        eventId: event.event.id,
        entitlementKeys,
      });

      res.status(200).send({ received: true, processed: true });
    } catch (error) {
      logger.error(`Error processing webhook for user ${userId}`, { error: error.toString(), eventType });
      res.status(500).send('Internal Server Error');
    }
  }
);

// İSTEMCİDEN ELLE TETİKLENEN: RevenueCat REST API ile premium durumu senkronize et
exports.syncRevenueCatPremium = onRequest(
  { region: 'us-central1', timeoutSeconds: 30, memory: '256MiB', secrets: [REVENUECAT_REST_API_KEY] },
  async (req, res) => {
    try {
      // Sadece Firebase Auth ile gelen istekler
      const uid = req.headers['x-firebase-uid'] || req.query.uid || null;
      if (!uid) {
        res.status(401).send('Unauthorized');
        return;
      }

      const apiKey = REVENUECAT_REST_API_KEY.value();
      const url = `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`;
      const rcResp = await fetch(url, {
        headers: {
          Authorization: `Bearer ${apiKey}`,
        },
      });
      if (!rcResp.ok) {
        logger.warn('RevenueCat REST call failed', { status: rcResp.status });
        res.status(502).send('RevenueCat error');
        return;
      }
      const data = await rcResp.json();
      const ents = data?.subscriber?.entitlements || {};

      let isPremium = false;
      let latestExpiration = 0;
      const now = Date.now();

      for (const key of Object.keys(ents)) {
        const e = ents[key] || {};
        let expMs = 0;
        if (typeof e.expires_date_ms === 'number') expMs = e.expires_date_ms;
        else if (typeof e.expires_date === 'string') {
          const p = Date.parse(e.expires_date);
          if (!Number.isNaN(p)) expMs = p;
        }
        const periodType = e.period_type || e.periodType;
        let active = false;
        if (expMs > now) active = true;
        if (!active && (periodType === 'lifetime')) active = true;
        if (active) {
          isPremium = true;
          if (expMs > latestExpiration) latestExpiration = expMs;
        }
      }

      const premiumUntil = isPremium && latestExpiration > 0 ? new Date(latestExpiration) : null;

      await db.collection('users').doc(uid).set({
        isPremium,
        premiumUntil,
        lastPremiumUpdateAt: new Date(),
        lastRevenueCatEvent: 'manual_sync',
      }, { merge: true });

      logger.info('Manual premium sync completed', { uid, isPremium, premiumUntil: premiumUntil ? premiumUntil.toISOString() : null });
      res.status(200).send({ isPremium, premiumUntil: premiumUntil ? premiumUntil.toISOString() : null });
    } catch (e) {
      logger.error('Manual premium sync error', { error: String(e) });
      res.status(500).send('Internal Server Error');
    }
  }
);

// Callable: Firebase Auth ile anında premium senkronizasyonu
exports.syncRevenueCatPremiumCallable = onCall(
  { region: 'us-central1', timeoutSeconds: 30, memory: '256MiB', secrets: [REVENUECAT_REST_API_KEY], enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Oturum gerekli');
    }
    const uid = request.auth.uid;

    try {
      const apiKey = REVENUECAT_REST_API_KEY.value();
      const url = `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`;
      const rcResp = await fetch(url, { headers: { Authorization: `Bearer ${apiKey}` } });
      if (!rcResp.ok) {
        logger.warn('RevenueCat REST call failed (callable)', { status: rcResp.status });
        throw new HttpsError('internal', 'RevenueCat hatası');
      }
      const data = await rcResp.json();
      const ents = data?.subscriber?.entitlements || {};

      let isPremium = false;
      let latestExpiration = 0;
      const now = Date.now();

      for (const key of Object.keys(ents)) {
        const e = ents[key] || {};
        let expMs = 0;
        if (typeof e.expires_date_ms === 'number') expMs = e.expires_date_ms;
        else if (typeof e.expires_date === 'string') {
          const p = Date.parse(e.expires_date);
          if (!Number.isNaN(p)) expMs = p;
        }
        const periodType = e.period_type || e.periodType;
        let active = false;
        if (expMs > now) active = true;
        if (!active && (periodType === 'lifetime')) active = true;
        if (active) {
          isPremium = true;
          if (expMs > latestExpiration) latestExpiration = expMs;
        }
      }

      const premiumUntil = isPremium && latestExpiration > 0 ? new Date(latestExpiration) : null;

      await db.collection('users').doc(uid).set({
        isPremium,
        premiumUntil,
        lastPremiumUpdateAt: new Date(),
        lastRevenueCatEvent: 'manual_sync_callable',
      }, { merge: true });

      logger.info('Manual premium sync (callable) completed', { uid, isPremium, premiumUntil: premiumUntil ? premiumUntil.toISOString() : null });
      return { isPremium, premiumUntil: premiumUntil ? premiumUntil.toISOString() : null };
    } catch (e) {
      logger.error('Manual premium sync (callable) error', { error: String(e) });
      if (e instanceof HttpsError) throw e;
      throw new HttpsError('internal', 'İç hata');
    }
  }
);
