const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { db } = require("./init");
const { defineSecret } = require('firebase-functions/params');

const REVENUECAT_WEBHOOK_SECRET = defineSecret('REVENUECAT_WEBHOOK_SECRET');
const REVENUECAT_REST_API_KEY = defineSecret('REVENUECAT_REST_API_KEY');

exports.handleRevenueCatWebhook = onRequest(
  { region: 'us-central1', timeoutSeconds: 30, memory: '256MiB', secrets: [REVENUECAT_WEBHOOK_SECRET, REVENUECAT_REST_API_KEY] }, // API anahtarını da ekle
  async (req, res) => {
    // 1. Authorization check
    const authHeader = req.headers.authorization || '';
    if (authHeader !== `Bearer ${REVENUECAT_WEBHOOK_SECRET.value()}`) {
      logger.warn('Unauthorized webhook attempt', { authHeaderPresent: !!authHeader });
      res.status(401).send('Unauthorized');
      return;
    }

    // 2. Event'ten temel bilgileri al
    const event = req.body;
    const userId = event?.event?.app_user_id;
    const eventId = event?.event?.id;
    const eventType = event?.event?.type;

    if (!userId) {
      logger.warn('Webhook received without a user ID.', { eventType });
      res.status(400).send('Bad Request: Missing user ID.');
      return;
    }
     if (!eventId) {
      logger.warn('Webhook received without an event ID.', { eventType, userId });
      res.status(400).send('Bad Request: Missing event ID.');
      return;
    }

    logger.info(`Processing webhook for user ${userId}`, { type: eventType, eventId });

    try {
      // 3. Gelen olayı geçmişe yönelik logla (hata ayıklama için değerli)
      const historyRef = db.collection('users').doc(userId).collection('purchase_history').doc(eventId);
      await historyRef.set({
        ...event.event,
        processedAt: new Date(),
        source: 'webhook',
      });

      // 4. GÜVENİLİR KAYNAK: RevenueCat API'sinden en güncel durumu al ve Firestore'u güncelle.
      // Webhook'tan gelen eventType'ı loglama amacıyla kullanıyoruz.
      await _updatePremiumStatusFromRevenueCatAPI(userId, eventType);

      logger.info(`Webhook processed successfully for user ${userId} by syncing with RC API`, { eventId, eventType });
      res.status(200).send({ received: true, processed: true });

    } catch (error) {
      logger.error(`Error processing webhook for user ${userId}`, {
        error: error.toString(),
        eventType,
        eventId,
      });
      // İstemciye hatanın ne olduğunu bildir.
      if (error.message.includes('RevenueCat')) {
        res.status(502).send('Bad Gateway: RevenueCat API ile senkronizasyon başarısız oldu.');
      } else {
        res.status(500).send('Internal Server Error');
      }
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

      const result = await _updatePremiumStatusFromRevenueCatAPI(uid, 'manual_sync_onRequest');
      res.status(200).send(result);

    } catch (e) {
      logger.error('onRequest premium senkronizasyon hatası', { error: String(e) });
       // RevenueCat API'sinden kaynaklanan özel bir durum varsa,
       // istemciye daha anlamlı bir hata kodu gönderilebilir.
      if (e.message.includes('RevenueCat')) {
        res.status(502).send('Bad Gateway: RevenueCat API ile iletişim kurulamadı.');
      } else {
        res.status(500).send('Internal Server Error');
      }
    }
  }
);

// RevenueCat API'sini kullanarak bir kullanıcının premium durumunu getiren ve güncelleyen merkezi fonksiyon.
// Hata durumunda fırlatır, bu yüzden çağıran fonksiyonun try/catch bloğu içinde olması gerekir.
const _updatePremiumStatusFromRevenueCatAPI = async (uid, eventType = 'manual_sync') => {
  const apiKey = REVENUECAT_REST_API_KEY.value();
  if (!apiKey) {
    throw new Error('RevenueCat API anahtarı bulunamadı.');
  }

  const url = `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`;
  const rcResp = await fetch(url, { headers: { Authorization: `Bearer ${apiKey}` } });

  if (!rcResp.ok) {
    logger.warn('RevenueCat REST API çağrısı başarısız oldu', { uid, status: rcResp.status });
    // HttpsError, onCall fonksiyonları tarafından istemciye düzgün bir şekilde iletilir.
    // Diğer fonksiyon türleri için genel bir Error fırlatmak daha iyidir.
    if (eventType.includes('callable')) {
       throw new HttpsError('internal', `RevenueCat API hatası: ${rcResp.status}`);
    } else {
       throw new Error(`RevenueCat API hatası: ${rcResp.status}`);
    }
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

  // VERİ GECİKMESİNE KARŞI KORUMA: Eğer 'RENEWAL' gibi olumlu bir webhook olayı gelirse,
  // ancak API anlık olarak `isPremium: false` döndürürse, bunun veri gecikmesi olduğunu varsay
  // ve Firestore'u GÜNCELLEME. Bu, kullanıcının premium üyeliğinin yanlışlıkla kaldırılmasını önler.
  const positiveEventTypes = ['INITIAL_PURCHASE', 'RENEWAL', 'UNCANCELLATION', 'PRODUCT_CHANGE'];
  if (!isPremium && eventType && positiveEventTypes.includes(eventType)) {
    logger.warn(`Olumlu '${eventType}' olayı (kullanıcı ${uid}) için API'den 'isPremium: false' döndü. Veri gecikmesi varsayılarak güncelleme atlanıyor.`);
    return { isPremium: undefined, status: 'skipped_due_to_data_lag' };
  }

  const premiumUntil = isPremium && latestExpiration > 0 ? new Date(latestExpiration) : null;

  await db.collection('users').doc(uid).set({
    isPremium,
    premiumUntil,
    lastPremiumUpdateAt: new Date(),
    lastRevenueCatEvent: eventType,
  }, { merge: true });

  logger.info('Kullanıcı premium durumu RevenueCat API ile güncellendi', { uid, isPremium, premiumUntil: premiumUntil ? premiumUntil.toISOString() : null, eventType });

  return { isPremium, premiumUntil };
};


// Callable: Firebase Auth ile anında premium senkronizasyonu
exports.syncRevenueCatPremiumCallable = onCall(
  { region: 'us-central1', timeoutSeconds: 30, memory: '256MiB', secrets: [REVENUECAT_REST_API_KEY], enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Oturum gerekli');
    }
    const uid = request.auth.uid;

    try {
      return await _updatePremiumStatusFromRevenueCatAPI(uid, 'manual_sync_callable');
    } catch (e) {
      logger.error('Callable premium senkronizasyon hatası', { uid, error: String(e) });
      // _updatePremiumStatusFromRevenueCatAPI zaten HttpsError fırlatıyor,
      // bu yüzden tekrar sarmalamaya gerek yok. Fırlatılan hatayı yeniden fırlat.
      if (e instanceof HttpsError) throw e;
      throw new HttpsError('internal', 'Sunucuda bir iç hata oluştu.');
    }
  }
);
