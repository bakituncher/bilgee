function _selectRandom(arr) {
  if (!arr || arr.length === 0) return "";
  return arr[Math.floor(Math.random() * arr.length)];
}

/**
   * Kullanıcı verilerine dayanarak akıllı ve kişiselleştirilmiş bir bildirim şablonu oluşturur.
   * Öncelik sırası:
   * 1. En zayıf dersi hedefleme (en yüksek öncelik).
   * 2. Aktif seriyi koruma motivasyonu.
   * 3. Premium olmayanlar için premium tanıtımı.
   * 4. Kaybedilmiş seriyi yeniden başlatma teşviki.
   * 5. Genel hareketsizlik hatırlatmaları (en düşük öncelik).
   * @param {{isPremium: boolean, selectedExam?: string}} userProfile Kullanıcı profili.
   * @param {{weakestSubject?: string}} userPerformance Kullanıcı performansı.
   * @param {{streak?: number, lostStreak?: boolean}} userStats Kullanıcı istatistikleri.
   * @param {number} inactivityHours Son aktiviteden bu yana geçen saat.
   * @returns {{title: string, body: string, route: string}|null} Bildirim objesi veya null.
   */
function buildPersonalizedTemplate(userProfile, userPerformance, userStats, inactivityHours) {
  const { isPremium = false, selectedExam } = userProfile || {};
  const { weakestSubject } = userPerformance || {};
  const { streak = 0, lostStreak = false } = userStats || {};

  const exam = selectedExam ? selectedExam.toUpperCase() : "sınav";
  const safeWeakestSubject = weakestSubject || "zayıf bir konunu";

  // --- Öncelik 1: En Zayıf Ders Üzerine Gitme ---
  // Kullanıcı aktifse (son 3 gün içinde) ve zayıf bir dersi varsa, bu en değerli bildirimdir.
  if (inactivityHours < 72 && weakestSubject) {
    const titles = [
      `Bu konuyu halletme zamanı: ${weakestSubject}! 💪`,
      `${weakestSubject} konusuna bir şans daha ver! 🚀`,
      `Zayıf halkanı güçlendir: ${weakestSubject} 🧠`,
    ];
    const bodies = [
      `Hadi, ${exam} öncesi ${safeWeakestSubject} güçlendirelim. Sadece 15 dakikalık bir testle fark yarat!`,
      `Bugün ${safeWeakestSubject} üzerine odaklanmaya ne dersin? Kısa bir tekrarla netlerini uçurabilirsin!`,
      `Potansiyelini keşfet! ${safeWeakestSubject} bir sonraki başarın olabilir. Ufak bir adımla başla.`,
    ];
    return {
      title: _selectRandom(titles),
      body: _selectRandom(bodies),
      route: "/home/add-test", // Kullanıcıyı direkt test çözmeye yönlendir
    };
  }

  // --- Öncelik 2: Aktif Seriyi Koruma ---
  // Serisi olan ve aktif olan kullanıcıları motive et
  if (inactivityHours < 48 && streak > 1) {
    const titles = [
      `Serin harika gidiyor: ${streak}. gün! 🔥`,
      `Alev alevsin! ${streak} günlük seri! ✨`,
      `${streak} gündür durdurulamazsın!  devam et! 🏆`,
    ];
    const bodies = [
      `Bugün de hedefine bir adım daha yaklaş. Serini bozma, ${exam} yolunda emin adımlarla ilerle!`,
      "Bu seri bozulmaz! Bugün de küçük bir görevle serini koru ve motive kal.",
      `Disiplinin konuşuyor! Serini devam ettirerek ${exam} için ne kadar ciddi olduğunu göster.`,
    ];
    return {
      title: _selectRandom(titles),
      body: _selectRandom(bodies),
      route: "/home/quests",
    };
  }

  // --- Öncelik 3: Premium Olmayanlara Özel Teklifler ---
  // Premium değilse ve bir süredir aktif değilse (ama tamamen kaybolmadıysa)
  if (!isPremium && inactivityHours >= 24 && inactivityHours < 120) {
    const titles = [
      "Sınırsız potansiyelini keşfet! ✨",
      "Çalışmalarını bir üst seviyeye taşı! 🚀",
      "Daha akıllı çalış, daha hızlı ilerle! 🧠",
    ];
    const bodies = [
      "Premium ile kişiselleştirilmiş çalışma planları ve sınırsız test çözme imkanı seni bekliyor. Hedefine giden yolda sana özel bir koç gibi!",
      "Takıldığın konuları anında çözen yapay zeka koçuyla tanıştın mı? Premium ile tüm kilitleri aç.",
      `${exam} hazırlığında fark yaratmak için Premium özelliklerine göz at. İlk adımı at, potansiyelini serbest bırak!`,
    ];
    return {
      title: _selectRandom(titles),
      body: _selectRandom(bodies),
      route: "/premium", // Premium sayfasına yönlendir
    };
  }

  // --- Öncelik 4: Kaybedilmiş Seriyi Geri Kazanma ---
  if (lostStreak && inactivityHours < 72) {
    return {
      title: "Hey, serin bozuldu ama sorun değil!  yeniden başla! 💪",
      body: `Herkes tökezleyebilir. Önemli olan yeniden başlamak! Bugün yeni bir seri başlatarak ${exam} hedefine bir adım daha at.`,
      route: "/home/quests",
    };
  }


  // --- Öncelik 5: Genel Hareketsizlik Hatırlatmaları (Fallback) ---
  if (inactivityHours >= 72) { // 3+ gün
    return {
      title: "Gözlerimiz seni arıyor! 👀",
      body: `${exam} hedefin için küçük bir adım atmanın tam zamanı. 10 dakikalık bir görevle yeniden başla!`,
      route: "/home/quests",
    };
  }
  if (inactivityHours >= 24) { // 1+ gün
    return {
      title: "Bir gündür yoksun, özlettin! 👋",
      body: `Bugün ${exam} için ne yapıyoruz? Kısa bir testle ısınmaya ne dersin? Hadi ama!`,
      route: "/home/add-test",
    };
  }
  if (inactivityHours >= 4) { // 4+ saat (daha sık)
    return {
      title: "Enerjini topladıysan, devam edelim mi? ⚡️",
      body: "Kısa bir mola harikalar yaratır. Şimdi 15 dakikalık bir pomodoro ile hedefine odaklan!",
      route: "/home/pomodoro",
    };
  }

  return null; // Eğer hiçbir koşul eşleşmezse bildirim gönderme
}

module.exports = {
  buildPersonalizedTemplate,
};
