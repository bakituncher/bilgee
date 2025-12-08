const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const { db, admin, messaging } = require("./init");
const { dayKeyIstanbul } = require("./utils");
const { computeInactivityHours, processAudienceInBatches } = require("./users");

// ---- FCM TOKEN KAYDI ----
exports.registerFcmToken = onCall({region: 'us-central1'}, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
    const uid = request.auth.uid;
    const token = String(request.data?.token || '');
    const platform = String(request.data?.platform || 'unknown');
    const lang = String(request.data?.lang || 'tr');
    if (!token || token.length < 10) throw new HttpsError('invalid-argument', 'Geçerli token gerekli');
    const deviceId = token.replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 140);
    const appVersion = request.data?.appVersion ? String(request.data.appVersion) : null;
    const appBuild = request.data?.appBuild != null ? Number(request.data.appBuild) : null;
    const ref = db.collection('users').doc(uid).collection('devices').doc(deviceId);
    await ref.set({
      uid,
      token,
      platform,
      lang,
      disabled: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(appVersion ? { appVersion } : {}),
      ...(Number.isFinite(appBuild) ? { appBuild } : {}),
    }, {merge: true});
    return {ok: true};
  });

// ---- FCM TOKEN TEMİZLEME ----
exports.unregisterFcmToken = onCall({region: 'us-central1'}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Oturum gerekli');
  const uid = request.auth.uid;
  const token = String(request.data?.token || '');
  if (!token || token.length < 10) throw new HttpsError('invalid-argument', 'Geçerli token gerekli');

  try {
    // Token'a sahip tüm cihaz kayıtlarını bul ve devre dışı bırak
    const devicesRef = db.collection('users').doc(uid).collection('devices');
    const snapshot = await devicesRef.where('token', '==', token).get();

    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.update(doc.ref, {
        disabled: true,
        unregisteredAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    if (!snapshot.empty) {
      await batch.commit();
      logger.info('FCM token unregistered', { uid, tokenLength: token.length, devicesUpdated: snapshot.size });
    }

    return { ok: true, devicesUpdated: snapshot.size };
  } catch (error) {
    logger.error('FCM token unregister failed', { uid, error: String(error) });
    throw new HttpsError('internal', 'Token temizleme işlemi başarısız');
  }
});

  async function getActiveTokens(uid) {
    const snap = await db.collection('users').doc(uid).collection('devices').where('disabled','==', false).limit(50).get();
    if (snap.empty) return [];
    const list = snap.docs.map((d)=> (d.data()||{}).token).filter(Boolean);
    return Array.from(new Set(list));
  }

  async function getActiveTokensFiltered(uid, filters = {}) {
    try {
      const platforms = Array.isArray(filters.platforms) ? filters.platforms.filter((x)=> typeof x === 'string' && x).map((s)=> s.toLowerCase()) : [];
      // Firestore'da sadece basit filtre: disabled ve (opsiyonel) platform in
      let q = db.collection('users').doc(uid).collection('devices').where('disabled','==', false);
      if (platforms.length > 0 && platforms.length <= 10) q = q.where('platform','in', platforms);

      // Limit makul bir değerde tutulur; kullanıcı başına çok az cihaz vardır.
      const snap = await q.limit(200).get();
      if (snap.empty) return [];

      const buildMin = Number.isFinite(filters.buildMin) ? Number(filters.buildMin) : null;
      const buildMax = Number.isFinite(filters.buildMax) ? Number(filters.buildMax) : null;

      const list = [];
      for (const d of snap.docs) {
        const it = d.data() || {};
        const build = typeof it.appBuild === 'number' ? it.appBuild : (typeof it.appBuild === 'string' ? Number(it.appBuild) : null);
        // Build filtrelerini bellek içinde uygula; alan yoksa 0 varsayalım
        const b = Number.isFinite(build) ? Number(build) : 0;
        if (buildMin !== null && !(b >= buildMin)) continue;
        if (buildMax !== null && !(b <= buildMax)) continue;
        if (it.token) list.push(it.token);
      }
      return Array.from(new Set(list));
    } catch (e) {
      // Aşırı durumlarda güvenli geri dönüş
      logger.error('getActiveTokensFiltered failed, fallback to unfiltered', { error: String(e) });
      const all = await db.collection('users').doc(uid).collection('devices').where('disabled','==', false).limit(200).get();
      if (all.empty) return [];
      const buildMin = Number.isFinite(filters.buildMin) ? Number(filters.buildMin) : null;
      const buildMax = Number.isFinite(filters.buildMax) ? Number(filters.buildMax) : null;
      const platforms = Array.isArray(filters.platforms) ? filters.platforms.filter((x)=> typeof x === 'string' && x).map((s)=> s.toLowerCase()) : [];
      const list = [];
      for (const d of all.docs) {
        const it = d.data() || {};
        if (platforms.length > 0 && !platforms.includes(String(it.platform || '').toLowerCase())) continue;
        const build = typeof it.appBuild === 'number' ? it.appBuild : (typeof it.appBuild === 'string' ? Number(it.appBuild) : null);
        const b = Number.isFinite(build) ? Number(build) : 0;
        if (buildMin !== null && !(b >= buildMin)) continue;
        if (buildMax !== null && !(b <= buildMax)) continue;
        if (it.token) list.push(it.token);
      }
      return Array.from(new Set(list));
    }
  }

  async function canSendMoreToday(uid, maxPerDay = 3) {
    const countersRef = db.collection('users').doc(uid).collection('state').doc('notification_counters');
    let allowed = false;
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(countersRef);
      const today = dayKeyIstanbul();
      if (!snap.exists) {
        // İlk kez: bu çağrıda bir gönderim yapılacağından sent=1
        tx.set(countersRef, {day: today, sent: 1, updatedAt: admin.firestore.FieldValue.serverTimestamp()});
        allowed = true;
        return;
      }
      const d = snap.data() || {};
      let sent = Number(d.sent || 0);
      let day = String(d.day || '');
      if (day !== today) { day = today; sent = 0; }
      if (sent < maxPerDay) {
        tx.set(countersRef, {day, sent: sent + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
        allowed = true;
      } else {
        allowed = false;
      }
    });
    return allowed;
  }

  // Sınav adını formatla (büyük harf)
  function formatExamName(examType) {
    if (!examType) return null;
    return String(examType).toUpperCase();
  }

  // Çeşitli bildirim şablonları - samimi, motive edici ve gençlere hitap eden
  function buildInactivityTemplate(inactHours, examType) {
    const exam = formatExamName(examType);

    // 72+ saat (3+ gün) - Uzun süre inaktif - 15 farklı mesaj
    if (inactHours >= 72) {
      const templates = [
        {
          title: 'Özledin mi? Biz seni çok özledik! 💙',
          body: exam ? `${exam} yolculuğunda 3 gün ara verdin. Küçük bir adımla geri dön, momentum kaybetme!` : 'Uzun bir mola verdin. Bugün sadece 10 dakika ayır, rutin yeniden gelsin! 🔥',
          route: '/home/quests',
        },
        {
          title: 'Hadi dostum, bu kadar ara fazla! 😅',
          body: exam ? `${exam} hedefin için her gün değerli. Kaldığın yerden devam et, 1 küçük görevle başla!` : 'Uzun süredir görüşemedik. Bugün bir deneme gir veya mini bir görev tamamla! 💪',
          route: '/home/add-test',
        },
        {
          title: 'Streak\'in tehlikede! ⚠️',
          body: exam ? `${exam} için çalışma serisini kaybetme. Şimdi geri dön, bir günlük görevini tamamla!` : 'Günlük çalışma alışkanlığın kopmak üzere. Hemen 15 dakikalık bir Pomodoro ile başla! ⏱️',
          route: '/home/pomodoro',
        },
        {
          title: 'Geri gelme zamanı! 🚀',
          body: exam ? `${exam} rotanda 3 gün duraksadın. Bugün yeniden gaza bas, TaktikAI koçun seni bekliyor!` : 'Uzun aradan sonra en iyi açılış: kısa bir görevle başla, ritmi yakala! 🎯',
          route: '/ai-hub',
        },
        {
          title: 'Hedefinden uzaklaşma! 🎯',
          body: exam ? `${exam} için her gün önemli. 3 günlük aradan sonra bugün küçük bir zaferle dön!` : 'Başarı düzenli çalışmadan gelir. Bugün sadece 1 görevle ritme geri dön! 💫',
          route: '/home/quests',
        },
        {
          title: 'Seni bekliyoruz! 🌟',
          body: exam ? `${exam} için hazırladığın stratejiler duruyor. Planını hayata geçirme vakti geldi!` : '3 gün bize uğramadın. Acaba bugün ne kadar çalışacaksın? Hedefini belirle! 📋',
          route: '/home/weekly-plan',
        },
        {
          title: 'Rakipler seni geçiyor! 🏃',
          body: exam ? `${exam} Arena'sında liderlik yarışı devam ediyor. Sen de yarışa katıl, yerini al!` : 'Zafer Panteonu\'nda yeni şampiyonlar belirleniyor. Geri dön, mücadele et! 🏆',
          route: '/arena',
        },
        {
          title: 'Cevher Atölyesi seni çağırıyor! 💎',
          body: exam ? `${exam} konularında eksik kalan yerler var mı? Atölyeye gel, zayıf konuları güçlendir!` : 'Zayıf konularını güçlendirmek için 3 gündür bekliyoruz. Hadi gel! ⚒️',
          route: '/ai-hub/weakness-workshop',
        },
        {
          title: 'Haftalık planın kaybolmasın! 📆',
          body: exam ? `${exam} için haftalık stratejini kontrol et. Bu hafta hangi konuları bitirmeliydin?` : 'Planladığın çalışmaları gözden geçir, ne kadar ilerlediğini gör! 📊',
          route: '/home/weekly-plan',
        },
        {
          title: 'AI Koçun merak ediyor! 🤖',
          body: exam ? `${exam} hazırlığında nasıl gidiyor? Koçunla stratejini güncelle, yeni hedefler koy!` : 'Çalışma planını gözden geçirme zamanı. TaktikAI koçunla yeniden buluş! 🎓',
          route: '/ai-hub',
        },
        {
          title: 'Motivasyon düşüklüğü mü? 💪',
          body: exam ? `${exam} yolunda bazen motivasyon düşer, bu normal. Ama 3 gün çok uzun! Geri gel!` : 'Sıkıldın mı? AI koçunla konuş, yeniden enerjilendir kendini! ✨',
          route: '/ai-hub/motivation-chat',
        },
        {
          title: 'Test sonuçların bekliyor! 📈',
          body: exam ? `${exam} denemeni girmeyi unutma. İstatistiklerin güncel olsun, ilerlemeni takip et!` : 'Son denemen ne zaman? Test sonuçlarını kaydet, grafiklerini incele! 📉',
          route: '/home/add-test',
        },
        {
          title: 'Günlük görevler birikti! 📝',
          body: exam ? `${exam} için günlük görevlerin 3 gündür bekliyor. Bugün hepsini temizle, XP kazan!` : 'Görev listesi doldu. Kolaylardan başla, ritmi yakala! 🎯',
          route: '/home/quests',
        },
        {
          title: 'Pomodoro tekniğini özledin mi? 🍅',
          body: exam ? `${exam} çalışmalarında Pomodoro tekniğiyle odaklanmaya ne dersin? 25 dakika yeter!` : 'Uzun araları Pomodoro ile böl. 25 dakika odaklan, 5 dakika dinlen! ⏱️',
          route: '/home/pomodoro',
        },
        {
          title: 'Başarı seninle başlar! 🌈',
          body: exam ? `${exam} hedefine ulaşmak için her gün bir adım atmalısın. Bugün geri dön, devam et!` : '3 günlük ara bitti. Şimdi yeniden başla, hedefe odaklan! 🎯',
          route: '/home',
        },
      ];
      return templates[Math.floor(Math.random() * templates.length)];
    }

    // 24-72 saat arası (1-3 gün) - 18 farklı mesaj
    if (inactHours >= 24) {
      const templates = [
        {
          title: 'Bir gün ara verdin, şimdi gaza gel! ⚡',
          body: exam ? `${exam} planında bugün yeni bir sayfa aç. Kısa bir deneme veya görevle hızlan!` : 'Dünü geride bırak, bugün en az 1 görev tamamla. Momentum sende! 🔥',
          route: '/home/quests',
        },
        {
          title: 'Bugün senin günün! 🌟',
          body: exam ? `${exam} yolculuğunda 1 gün boşluk oluştu. Şimdi test gir veya zayıf konunu çalış!` : 'Dün yok, yarın yok. Sadece bugün var. 15 dakikalık odakla başla! 💪',
          route: '/home/add-test',
        },
        {
          title: 'Koçun seni çağırıyor! 🎓',
          body: exam ? `${exam} için TaktikAI koçunla stratejini güncelle. 1 günlük ara yeter, devam et!` : 'Yeni bir strateji mi lazım? Koçunla konuş, planını tazele! 🗣️',
          route: '/ai-hub',
        },
        {
          title: 'Streak kırılmasın! 🔥',
          body: exam ? `${exam} serini korumak için bugün küçük bir görev yeter. Hadi başla!` : 'Günlük çalışma alışkanlığını kaybetme. Şimdi 1 Pomodoro seansı yap! ⏱️',
          route: '/home/pomodoro',
        },
        {
          title: 'Motivasyon düştü mü? 💬',
          body: exam ? `${exam} yolunda bazen mola gerekir ama çok uzatma. Koçunla konuş, moralini topla!` : 'Sıkıldın mı? AI koçunla sohbet et, yeni bir bakış açısı kazan! 🌈',
          route: '/ai-hub/motivation-chat',
        },
        {
          title: 'Rakiplerin çalışıyor! 👀',
          body: exam ? `${exam} için Arena'da liderlik yarışı kızışıyor. Sen de bugün katıl, sıralamaya gir!` : 'Zafer Panteonu\'nda yeni rekorlar kırılıyor. Sen neredesin? 🏆',
          route: '/arena',
        },
        {
          title: 'Haftalık strateji zamanı! 📅',
          body: exam ? `${exam} planını gözden geçir. Bu hafta hangi konuları bitirmelisin?` : 'Haftalık hedeflerini kontrol et. Planında ilerleme kaydet! 📊',
          route: '/home/weekly-plan',
        },
        {
          title: 'Zayıf konularını yok et! 💎',
          body: exam ? `${exam} için Cevher Atölyesi'nde en zor konunu seç, ustalaş!` : 'Hangi konu seni en çok zorluyor? Atölyeye gel, o konuyu fethet! ⚒️',
          route: '/ai-hub/weakness-workshop',
        },
        {
          title: 'Test istatistiklerin eksik! 📊',
          body: exam ? `${exam} denemeni gir, netlerini takip et. İlerlemen grafikte görünsün!` : 'Son test sonucunu kaydet, performansını analiz et! 📈',
          route: '/home/add-test',
        },
        {
          title: 'Günlük görevler seni bekliyor! 📋',
          body: exam ? `${exam} için bugünkü görevlerini tamamla, XP kazan, sıralamada yüksel!` : 'Görev listene göz at. Her görev tamamlandıkça daha güçleneceksin! 💪',
          route: '/home/quests',
        },
        {
          title: 'AI analizi hazır! 🔍',
          body: exam ? `${exam} için güçlü ve zayıf yanlarını gör, stratejini optimize et!` : 'Son performansını analiz ettik. Sonuçlara bakmaya ne dersin? 📉',
          route: '/ai-hub/analysis-strategy',
        },
        {
          title: 'Odaklanma zamanı! 🧘',
          body: exam ? `${exam} çalışması için bugün 1 Pomodoro yap, dikkatini topla!` : 'Dağılmış zihnini topla. 25 dakikalık Pomodoro ile başla! 🍅',
          route: '/home/pomodoro',
        },
        {
          title: 'Yeni hafta, yeni hedefler! 🌅',
          body: exam ? `${exam} için bu hafta neleri başaracaksın? Planını yeniden düzenle!` : 'Haftalık çalışma programını kontrol et, güncelle! 📆',
          route: '/home/weekly-plan',
        },
        {
          title: 'Koçun seninle gurur duymak istiyor! 🏅',
          body: exam ? `${exam} yolculuğunda duraklamak yok. Bugün küçük bir adım at!` : 'Her gün küçük bir ilerleme büyük başarı getirir. Başla! 🚀',
          route: '/home',
        },
        {
          title: 'Arena liderlik tablosu güncellendi! 📊',
          body: exam ? `${exam} için yeni liderler belirlendi. Sen kaçıncı sıradasın?` : 'Zafer Panteonu\'nda sıralaman değişti mi? Kontrol et! 🏆',
          route: '/arena',
        },
        {
          title: 'Strateji güncellemesi gerekli! 🗺️',
          body: exam ? `${exam} için strateji danışmanına git, yeni yol haritası çiz!` : 'Çalışma stratejini yenile, daha verimli ol! 💡',
          route: '/ai-hub/strategic-planning',
        },
        {
          title: 'Konularında ustalaş! 🎯',
          body: exam ? `${exam} konularını tek tek fethet. Bugün hangisine odaklanacaksın?` : 'Her konu bir beceri. Bugün yeni bir konuyu öğren! 📚',
          route: '/coach',
        },
        {
          title: 'Deneme analizi bekliyor! 📝',
          body: exam ? `${exam} denemeni gir, AI koçun analiz etsin, eksiklerini bul!` : 'Test sonuçlarını kaydet, detaylı analiz al! 🔍',
          route: '/ai-hub/analysis-strategy',
        },
      ];
      return templates[Math.floor(Math.random() * templates.length)];
    }

    // 3-24 saat arası - Hafif hatırlatma - 24 farklı mesaj
    if (inactHours >= 3) {
      const templates = [
        {
          title: 'Kısa bir mola verdik, devam edelim! 😊',
          body: exam ? `${exam} için bugün ne yapmıştık? Hadi küçük bir görevle devam et!` : 'Birkaç saattir görüşemedik. 15 dakikalık mini bir çalışma ile açılış yap! ☕',
          route: '/home/quests',
        },
        {
          title: 'Pomodoro zamanı! 🍅',
          body: exam ? `${exam} planında bugün 1 Pomodoro seansı kaldı. Sadece 25 dakika, hadi başla!` : 'Odaklanma vakti! 25 dakikalık bir Pomodoro ile zihnini açacaksın. 🧠',
          route: '/home/pomodoro',
        },
        {
          title: 'Günlük görevlerin bekliyor! 📋',
          body: exam ? `${exam} için bugünkü görevlerini kontrol ettin mi? Hepsini tamamla, XP kazan!` : 'Görev listene bak, kolaylardan başla. Her tamamlanan görev bir adım! 🎯',
          route: '/home/quests',
        },
        {
          title: 'Zayıf konunu yok et! 💎',
          body: exam ? `${exam} konularında Cevher Atölyesi seni bekliyor. En zor konuyu seç, öğren!` : 'Bugün hangi konuyu ustalık seviyesine çıkaracaksın? Atölyeye gel! ⚒️',
          route: '/ai-hub/weakness-workshop',
        },
        {
          title: 'Haftalık planını kontrol et! 📅',
          body: exam ? `${exam} için bu haftaki stratejine baktın mı? Bugün ne çalışmalısın?` : 'Haftalık planında bugün hangi konular var? Planını takip et, başarı gelsin! 🗓️',
          route: '/home/weekly-plan',
        },
        {
          title: 'Test gir, netlerini yükselt! 📊',
          body: exam ? `${exam} için bugün deneme girdin mi? Test sonuçlarını takip et, eksiklerini gör!` : 'Yeni bir deneme sonucunu kaydet, istatistiklerini incele, ilerlemeyi gör! 📈',
          route: '/home/add-test',
        },
        {
          title: 'Koçunla sohbet et! 💭',
          body: exam ? `${exam} stratejini koçunla konuş. Yeni bir bakış açısı edinmek ister misin?` : 'Takıldığın bir konu mu var? AI koçuna sor, anında cevap al! 🤖',
          route: '/ai-hub',
        },
        {
          title: 'Mini motivasyon dozu! ✨',
          body: exam ? `${exam} yolculuğunda her küçük adım sayılır. Bugün ne yapacaksın?` : 'Bugün kendine bir görev ver ve onu tamamla. Küçük zaferler büyük başarı getirir! 🌟',
          route: '/home',
        },
        {
          title: 'Streak devam ediyor! 🔥',
          body: exam ? `${exam} için günlük serini koru. Bugün en az 1 görev tamamla!` : 'Günlük çalışma alışkanlığını sürdür, başarı yakın! 💪',
          route: '/home/quests',
        },
        {
          title: 'Arena\'da yüksel! 🏆',
          body: exam ? `${exam} liderlik tablosunda yerini koru. Bugün puan kazan!` : 'Zafer Panteonu\'nda sıralaman nasıl? Kontrol et, rakiplerini geç! 🥇',
          route: '/arena',
        },
        {
          title: 'Stratejik planlama vakti! 🗺️',
          body: exam ? `${exam} için haftalık çalışma planını oluştur, hedeflerini belirle!` : 'AI ile kişisel haftalık planını hazırla, verimli çalış! 📊',
          route: '/ai-hub/strategic-planning',
        },
        {
          title: 'Konu performansını yükselt! 📚',
          body: exam ? `${exam} konularında hangileri zayıf? Onlara bugün odaklan!` : 'Zayıf konularını güçlendir, ustalaşmış konularını pekiştir! 💡',
          route: '/coach',
        },
        {
          title: 'Deneme analizi al! 🔍',
          body: exam ? `${exam} için AI ile deneme analizi yap, güçlü/zayıf yanlarını gör!` : 'Test sonuçlarını analiz et, neleri geliştirmelisin öğren! 📉',
          route: '/ai-hub/analysis-strategy',
        },
        {
          title: 'Odaklanma gücünü artır! 🎯',
          body: exam ? `${exam} çalışması için Pomodoro tekniğini dene, dikkatini topla!` : '25 dakikalık derin odaklanma ile maksimum verim al! 🍅',
          route: '/home/pomodoro',
        },
        {
          title: 'Bugünün kazananı sen ol! 🏅',
          body: exam ? `${exam} için bugün kendine küçük bir hedef koy ve onu tamamla!` : 'Günlük hedefini belirle, akşam mutlu uyu! 😴',
          route: '/home/quests',
        },
        {
          title: 'Motivasyon yükleniyor... 💪',
          body: exam ? `${exam} yolunda motivasyona ihtiyacın var mı? AI koçunla konuş!` : 'Moralsiz hissediyorsan sohbet et, enerjilendir kendini! 🌈',
          route: '/ai-hub/motivation-chat',
        },
        {
          title: 'Haftalık hedeflerini gözden geçir! 📆',
          body: exam ? `${exam} için bu hafta ne kadar çalıştın? Planı kontrol et!` : 'Haftalık ilerlemeni takip et, eksik kalan konuları tamamla! 📊',
          route: '/home/weekly-plan',
        },
        {
          title: 'Atölye çağrısı! 🔨',
          body: exam ? `${exam} için Cevher Atölyesi'nde yeni çalışma kartları hazır!` : 'Zayıf konuların için özel çalışma materyalleri seni bekliyor! 💎',
          route: '/ai-hub/weakness-workshop',
        },
        {
          title: 'Test sonuçları eksik! 📝',
          body: exam ? `${exam} son denemeni ne zaman girdin? Performansını takip et!` : 'Test sonuçlarını düzenli kaydet, ilerlemeyi gör! 📈',
          route: '/home/add-test',
        },
        {
          title: 'Günlük rutin devam! 🔄',
          body: exam ? `${exam} için günlük çalışma rutinini sürdür, başarı yakın!` : 'Her gün biraz çalışmak, ara sıra çok çalışmaktan iyidir! 🎯',
          route: '/home',
        },
        {
          title: 'Liderlik yarışı! 🏃‍♂️',
          body: exam ? `${exam} Arena'sında kim önde? Sıralamayı kontrol et, yarışa katıl!` : 'Zafer Panteonu güncellendi. Sıralaman değişti mi? 🏆',
          route: '/arena',
        },
        {
          title: 'AI koçundan öneriler! 🤖',
          body: exam ? `${exam} stratejini AI koçunla konuş, kişisel önerilerin hazır!` : 'Çalışma planını optimize et, AI koçun yardımcı olsun! 💡',
          route: '/ai-hub',
        },
        {
          title: 'Kısa ve verimli çalışma! ⚡',
          body: exam ? `${exam} için bugün 15 dakika yeter. Bir görev tamamla, ilerle!` : 'Zamanın az mı? 15 dakikalık odaklanmayla büyük fark yarat! ⏱️',
          route: '/home/quests',
        },
        {
          title: 'Konular seni bekliyor! 📖',
          body: exam ? `${exam} müfredatında hangi konuyu bugün çalışacaksın?` : 'Konu havuzunda yüzlerce konu var. Bugün hangisine dalacaksın? 🤿',
          route: '/coach',
        },
      ];
      return templates[Math.floor(Math.random() * templates.length)];
    }

    return null;
  }

  async function sendPushToTokens(tokens, payload) {
    if (!tokens || tokens.length === 0) return {successCount: 0, failureCount: 0};
    const uniq = Array.from(new Set(tokens.filter(Boolean)));
    logger.info('sendPushToTokens', { tokenCount: uniq.length, hasImage: !!payload.imageUrl, type: payload.type || 'unknown' });
    const collapseId = payload.campaignId || (payload.route || 'bilge_general');
    const message = {
      notification: { title: payload.title, body: payload.body, ...(payload.imageUrl ? { imageUrl: payload.imageUrl } : {}) },
      data: { route: payload.route || '/home', campaignId: payload.campaignId || '', type: payload.type || 'inactivity', ...(payload.imageUrl ? { imageUrl: payload.imageUrl } : {}) },
      android: {
        collapseKey: collapseId,
        notification: {
          channelId: 'bilge_general',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          priority: 'HIGH',
          ...(payload.imageUrl ? { imageUrl: payload.imageUrl } : {}),
        },
      },
      apns: {
        headers: { 'apns-collapse-id': collapseId },
        payload: { aps: { sound: 'default', 'mutable-content': 1 } },
        fcmOptions: payload.imageUrl ? { imageUrl: payload.imageUrl } : undefined,
      },
      tokens: uniq,
    };
    try {
      const resp = await messaging.sendEachForMulticast(message);
      return {successCount: resp.successCount, failureCount: resp.failureCount};
    } catch (e) {
      logger.error('FCM send failed', { error: String(e) });
      return {successCount: 0, failureCount: uniq.length};
    }
  }

  async function dispatchInactivityPushBatch(limitUsers = 500) {
    const usersSnap = await db.collection('users').limit(5000).get();
    let processed = 0, sent = 0;
    for (const doc of usersSnap.docs) {
      if (processed >= limitUsers) break;
      const uid = doc.id;
      const userRef = doc.ref;
      const inact = await computeInactivityHours(userRef);
      const examType = (doc.data()||{}).selectedExam || null;
      const tpl = buildInactivityTemplate(inact, examType);
      if (!tpl) { processed++; continue; }
      const allowed = await canSendMoreToday(uid, 3);
      if (!allowed) { processed++; continue; }
      const tokens = await getActiveTokens(uid);
      if (tokens.length === 0) { processed++; continue; }
      await sendPushToTokens(tokens, { ...tpl, type: 'inactivity' });
      sent++;
      processed++;
    }
    logger.info('dispatchInactivityPushBatch done', {processed, sent});
    return {processed, sent};
  }

function scheduleSpecAt(hour, minute = 0) {
    return {
      schedule: `${minute} ${hour} * * *`,
      timeZone: 'Europe/Istanbul',
      timeoutSeconds: 540  // Sadece bunu ekledik (9 dakika süre)
    };
  }

  // ---- ZAMANLANMIŞ BİLDİRİM FONKSİYONLARI ----
  exports.dispatchInactivityMorning = onSchedule(scheduleSpecAt(9, 0), async () => {
    logger.info('🌅 Morning inactivity push started');
    await dispatchInactivityPushBatch(1500);
  });

  exports.dispatchInactivityAfternoon = onSchedule(scheduleSpecAt(15, 0), async () => {
    logger.info('☀️ Afternoon inactivity push started');
    await dispatchInactivityPushBatch(1500);
  });

  exports.dispatchInactivityEvening = onSchedule(scheduleSpecAt(20, 30), async () => {
    logger.info('🌙 Evening inactivity push started');
    await dispatchInactivityPushBatch(1500);
  });

  // ---- ADMIN KAMPANYA SİSTEMİ ----
  exports.adminEstimateAudience = onCall({ region: "us-central1", timeoutSeconds: 300 }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
    const isAdmin = request.auth.token && request.auth.token.admin === true;
    if (!isAdmin) throw new HttpsError("permission-denied", "Admin gerekli");
    const audience = request.data?.audience || { type: "all" };

    let baseUsers = 0;
    let tokenHolders = 0;
    const filters = { buildMin: audience.buildMin, buildMax: audience.buildMax, platforms: audience.platforms };
    const hasDeviceFilters = (Array.isArray(filters.platforms) && filters.platforms.length > 0) ||
      Number.isFinite(filters.buildMin) ||
      Number.isFinite(filters.buildMax);

    await processAudienceInBatches(audience, async (uidBatch) => {
      baseUsers += uidBatch.length;
      if (!hasDeviceFilters) {
        return; // Cihaz filtresi yoksa sadece kullanıcı saymak yeterli
      }
      const batchSize = 50;
      for (let i = 0; i < uidBatch.length; i += batchSize) {
        const batch = uidBatch.slice(i, i + batchSize);
        const results = await Promise.all(
          batch.map(async (uid) => {
            const tokens = await getActiveTokensFiltered(uid, filters);
            return tokens.length > 0 ? 1 : 0;
          })
        );
        tokenHolders += results.reduce((a, b) => a + b, 0);
        if (i > 0 && i % 5000 === 0) await new Promise((r) => setTimeout(r, 50));
      }
    });

    const users = hasDeviceFilters ? tokenHolders : baseUsers;
    return { users, baseUsers, tokenHolders };
  });

  exports.adminSendPush = onCall({ region: "us-central1", timeoutSeconds: 540 }, async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
    const isAdmin = request.auth.token && request.auth.token.admin === true;
    if (!isAdmin) throw new HttpsError("permission-denied", "Admin gerekli");

    const title = String(request.data?.title || "").trim();
    const body = String(request.data?.body || "").trim();
    const imageUrl = request.data?.imageUrl ? String(request.data.imageUrl) : "";
    const route = String(request.data?.route || "/home");
    const audience = request.data?.audience || { type: "all" };
    const scheduledAt = typeof request.data?.scheduledAt === "number" ? request.data.scheduledAt : null;
    const sendTypeRaw = String(request.data?.sendType || "push").toLowerCase();
    const sendType = ["push", "inapp", "both"].includes(sendTypeRaw) ? sendTypeRaw : "push";

    if (!title || !body) throw new HttpsError("invalid-argument", "title ve body zorunludur");

    const campaignRef = db.collection("push_campaigns").doc();
    const baseDoc = {
      title,
      body,
      imageUrl,
      route,
      audience,
      createdBy: request.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      sendType,
    };

    if (scheduledAt && scheduledAt > Date.now() + 15000) {
      await campaignRef.set({ ...baseDoc, status: "scheduled", scheduledAt });
      return { ok: true, campaignId: campaignRef.id, scheduled: true };
    }

    await campaignRef.set({ ...baseDoc, status: "sending" });

    const filters = { buildMin: audience.buildMin, buildMax: audience.buildMax, platforms: audience.platforms };
    let totalUsers = 0;
    let totalInApp = 0;
    let totalSent = 0;
    let totalFail = 0;

    await processAudienceInBatches(audience, async (uidBatch) => {
      totalUsers += uidBatch.length;

      // In-app bildirimler
      if (sendType === "inapp" || sendType === "both") {
        const inAppPromises = uidBatch.map((uid) =>
          createInAppForUser(uid, { title, body, imageUrl, route, type: "campaign", campaignId: campaignRef.id })
        );
        const results = await Promise.all(inAppPromises);
        totalInApp += results.filter(Boolean).length;
      }

      // Push bildirimler
      if (sendType === "push" || sendType === "both") {
        const allTokens = [];
        const batchSize = 100;
        for (let i = 0; i < uidBatch.length; i += batchSize) {
          const batchUids = uidBatch.slice(i, i + batchSize);
          const tokenPromises = batchUids.map((uid) => getActiveTokensFiltered(uid, filters));
          const tokenBatches = await Promise.all(tokenPromises);
          tokenBatches.forEach((tokens) => allTokens.push(...tokens));
        }

        const uniqueTokens = [...new Set(allTokens)];

        if (uniqueTokens.length > 0) {
          const pushPayload = {
            title,
            body,
            imageUrl,
            route,
            type: "campaign",
            campaignId: campaignRef.id,
          };
          const result = await sendPushToTokens(uniqueTokens, pushPayload);
          totalSent += result.successCount;
          totalFail += result.failureCount;
        }
      }
    });

    await campaignRef.set(
      {
        status: "completed",
        totalUsers,
        totalSent,
        totalFail,
        totalInApp,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return { ok: true, campaignId: campaignRef.id, totalUsers, totalSent, totalFail, totalInApp };
  });

  exports.processScheduledCampaigns = onSchedule({ schedule: "*/5 * * * *", timeZone: "Europe/Istanbul" }, async () => {
    const now = Date.now();
    const snap = await db
      .collection("push_campaigns")
      .where("status", "==", "scheduled")
      .where("scheduledAt", "<=", now)
      .limit(10)
      .get();
    if (snap.empty) return;
    for (const doc of snap.docs) {
      const d = doc.data() || {};
      try {
        await doc.ref.set({ status: "sending" }, { merge: true });
        const { title, body, imageUrl, route, audience } = d;
        const sendTypeRaw = String(d.sendType || "push").toLowerCase();
        const sendType = ["push", "inapp", "both"].includes(sendTypeRaw) ? sendTypeRaw : "push";

        const filters = {
          buildMin: audience?.buildMin,
          buildMax: audience?.buildMax,
          platforms: audience?.platforms,
        };
        let totalSent = 0,
          totalFail = 0,
          totalUsers = 0,
          totalInApp = 0;

        await processAudienceInBatches(audience, async (uidBatch) => {
          totalUsers += uidBatch.length;
          for (const uid of uidBatch) {
            if (sendType === "inapp" || sendType === "both") {
              const ok = await createInAppForUser(uid, {
                title,
                body,
                imageUrl,
                route,
                type: "campaign",
                campaignId: doc.id,
              });
              if (ok) totalInApp++;
            }
            if (sendType === "push" || sendType === "both") {
              const tokens = await getActiveTokensFiltered(uid, filters);
              if (tokens.length === 0) continue;
              const r = await sendPushToTokens(tokens, {
                title,
                body,
                imageUrl,
                route,
                type: "campaign",
                campaignId: doc.id,
              });
              totalSent += r.successCount;
              totalFail += r.failureCount;
              await doc.ref.collection("logs").add({
                uid,
                success: r.successCount,
                failed: r.failureCount,
                ts: admin.firestore.FieldValue.serverTimestamp(),
              });
            }
          }
        });

        await doc.ref.set(
          {
            status: "completed",
            totalUsers,
            totalSent,
            totalFail,
            totalInApp,
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      } catch (e) {
        logger.error("Scheduled campaign failed", { id: doc.id, error: String(e) });
        await doc.ref.set(
          { status: "failed", error: String(e), failedAt: admin.firestore.FieldValue.serverTimestamp() },
          { merge: true }
        );
      }
    }
  });

  // Uygulama içi bildirim oluşturucu
  async function createInAppForUser(uid, payload) {
    try {
      const ref = db.collection('users').doc(uid).collection('in_app_notifications');
      const doc = {
        title: payload.title || '',
        body: payload.body || '',
        route: payload.route || '/home',
        imageUrl: payload.imageUrl || '',
        type: payload.type || 'campaign',
        campaignId: payload.campaignId || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
        readAt: null,
      };
      await ref.add(doc);
      return true;
    } catch (e) {
      logger.error('createInAppForUser failed', { uid, error: String(e) });
      return false;
    }
  }
