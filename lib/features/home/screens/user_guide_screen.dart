// lib/features/home/screens/user_guide_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';

class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            floating: false,
            backgroundColor: colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Kullanım Kılavuzu',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.8),
                      colorScheme.secondary,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.school_rounded,
                    size: 80,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Welcome Card
                _buildWelcomeCard(context, isDark),
                const SizedBox(height: 20),

                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                    indicatorColor: colorScheme.primary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: '🎯 Başlangıç'),
                      Tab(text: '📅 Haftalık Plan'),
                      Tab(text: '📚 Deneme Arşivi'),
                      Tab(text: '💎 Cevher Atölyesi'),
                      Tab(text: '🎮 Arena & Görevler'),
                      Tab(text: '📊 İstatistikler'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Tab Content
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStartingGuide(context, isDark),
                      _buildWeeklyPlanGuide(context, isDark),
                      _buildLibraryGuide(context, isDark),
                      _buildWorkshopGuide(context, isDark),
                      _buildArenaGuide(context, isDark),
                      _buildStatsGuide(context, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Başarıya Giden Yolun Haritası',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2, end: 0),
          const SizedBox(height: 18),
          const Text(
            'Taktik, binlerce öğrencinin sınav başarısını artıran yapay zeka destekli kişisel çalışma asistanıdır.',
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBenefitRow('📈', 'Net sayını ortalama %40 artır'),
                const SizedBox(height: 10),
                _buildBenefitRow('🎯', 'Zayıf konuları tespit et ve güçlendir'),
                const SizedBox(height: 10),
                _buildBenefitRow('⏱️', 'Günde sadece 10 dakika ile takip et'),
                const SizedBox(height: 10),
                _buildBenefitRow('🏆', 'Hedefine odaklanarak sınavı kazan'),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Her gün düzenli kullanım, başarı oranını 3 kat artırır!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 450.ms, duration: 400.ms).shimmer(delay: 1.seconds, duration: 2.seconds),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(String emoji, String text) {
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartingGuide(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSuccessStoryCard(context, isDark),
          const SizedBox(height: 20),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.rocket_launch_rounded,
            title: '1. Başlangıç: Başarıya İlk Adım',
            description: 'Taktik, sınav hedefine göre sana özel bir yol haritası oluşturur. YKS, LGS veya KPSS - hangi sınavı seçersen seç, yapay zeka destekli sistemimiz seni adım adım hedefe taşır.\n\n📊 Neden Önemli?\n• Doğru başlangıç, başarının %50\'sidir\n• Hedef belirleme, motivasyonu 3 kat artırır\n• Kişisel strateji, verimli çalışma demektir',
            tips: [
              '🎯 Hedef puanını gerçekçi ama hırslı belirle',
              '⏰ Müsait saatlerini detaylı gir - bu çok önemli!',
              '✅ Profilini eksiksiz doldur - daha iyi analiz için',
            ],
            color: Colors.blue,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.emoji_events_rounded,
            title: '2. Günlük Rutini Oluştur',
            description: 'Başarılı öğrencilerin ortak noktası: Düzenli takip! Her gün sadece 10 dakika ayırarak:\n\n✅ Çözdüğün soruları kaydet\n✅ Deneme netlerini gir\n✅ Zayıf konuları tespit et\n✅ Günlük görevleri tamamla\n\n💡 Sonuç: 90 günde ortalama %40 net artışı!',
            tips: [
              '📱 Her gün aynı saatte giriş yap (alışkanlık oluştur)',
              '📝 Deneme çözdüğünde hemen kaydet (unutma!)',
              '🎮 Günlük görevleri tamamla (XP kazan, rozet topla)',
            ],
            color: Colors.amber,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.workspace_premium_rounded,
            title: '3. Premium ile Farkı Yaşa',
            description: 'Premium üyeler %67 daha fazla başarı elde ediyor!\n\n🚀 Sınırsız Yapay Zeka Desteği\n📊 Detaylı İstatistik Analizi\n💎 Sınırsız Cevher Atölyesi\n📈 Gelişmiş Performans Takibi\n⚡ Öncelikli Destek\n\n💰 İlk hafta ÜCRETSİZ dene, farkı gör!',
            tips: [
              '🎁 Ücretsiz deneme süresi ile risk almadan dene',
              '📈 İlk 30 günde ortalama 15 net artışı gör',
              '🏆 Başarı garantisi: Memnun kalmazsan iade et',
            ],
            color: Colors.purple,
            isPremiumFeature: true,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildWeeklyPlanGuide(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.2),
                  Colors.teal.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.green.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.auto_fix_high_rounded, color: Colors.green, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Yapay Zeka Seni Tanıyor!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Her hafta performansını analiz ederek, tamamen SANA ÖZEL plan oluşturur. Zayıf konularına odaklanır, güçlü yanlarını geliştirir!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
          const SizedBox(height: 20),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.psychology_rounded,
            title: 'Akıllı Haftalık Plan',
            description: '🤖 YAPAY ZEKA NASIL ÇALIŞIR?\n\n1️⃣ Deneme sonuçlarını analiz eder\n2️⃣ Zayıf konuları tespit eder\n3️⃣ Müfredat sırasını takip eder\n4️⃣ Müsait saatlerine göre dağıtır\n5️⃣ Sınava kalan süreyi hesaplar\n6️⃣ SANA ÖZEL plan oluşturur!\n\n🎯 SONUÇ:\n• %100 Kişisel (Senin ihtiyaçlarına özel)\n• Verimli (Boş iş yok, her görev hedefli)\n• Esnek (İstersen değiştirebilirsin)\n• Etkili (Sonuç odaklı strateji)\n\n💡 Haftalık plan kullanan öğrenciler, %58 daha organize çalışıyor!',
            tips: [
              '📅 Her hafta YENİ plan oluştur (sürekli güncellenir)',
              '✅ Tamamladıklarını işaretle (AI öğrenir)',
              '🔄 Plan süresi dolunca yenile (gelişmeye devam)',
            ],
            color: Colors.green,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.speed_rounded,
            title: 'Yoğunluk: Sen Karar Ver!',
            description: '⚡ YOĞUNLUK SEVİYELERİ:\n\n🟢 RAHAT (%50-60 doluluk)\n• Okul yoğun, zamanın az\n• Temeli atıyorsun\n• İlk kez deneme çözüyorsun\n\n🟡 ORTA (%70-80 doluluk)\n• Dengeli çalışma temposu\n• Hem okul hem hazırlık\n• Düzenli ilerleme istiyorsun\n\n🔴 YOĞUN (%90 doluluk)\n• Sınav yaklaştı, tam gaz!\n• Boş vaktinin çoğunu ayırabilirsin\n• Hızlı net artışı istiyorsun\n\n💡 İPUCU: İlk 2 hafta RAHAT başla, alışınca yoğunluğu artır!',
            tips: [
              '🎯 Sınava 3+ ay varsa RAHAT/ORTA tercih et',
              '⚡ Sınava 1-2 ay kaldıysa YOĞUN seç',
              '🔄 Her hafta yoğunluğu değiştirebilirsin',
            ],
            color: Colors.indigo,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.workspace_premium_rounded,
            title: 'Premium: Sınırsız Planlama',
            description: '👑 PREMIUM ÖZELLİKLERİ:\n\n✨ Sınırsız Plan Oluşturma\n📊 Detaylı Performans Analizi\n🎯 Konu Bazlı Özel Görevler\n⏰ Akıllı Zaman Optimizasyonu\n🔄 Dinamik Plan Güncelleme\n💬 Yapay Zeka Motivasyon Koçu\n\n🚀 FARKI GÖR:\n\nÜcretsiz: Haftada 1 plan\nPremium: SINIRSIZ plan + Günlük güncelleme!\n\nÜcretsiz: Temel analiz\nPremium: Detaylı istatistik + Tahmin algoritması!\n\n💰 İlk 7 gün ÜCRETSİZ dene!',
            tips: [
              '🎁 Ücretsiz deneme ile tüm özellikleri test et',
              '📈 Premium kullananlar %45 daha hızlı gelişiyor',
              '🏆 30 gün memnuniyet garantisi var!',
            ],
            color: Colors.purple,
            isPremiumFeature: true,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildLibraryGuide(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withOpacity(0.15),
                  Colors.orange.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.trending_up_rounded, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Düzenli Kayıt = Başarı',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Her denemeyi kaydeden öğrenciler, ortalama 12 net daha fazla artış gösteriyor!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
          const SizedBox(height: 20),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.library_books_rounded,
            title: 'Deneme Arşivi: Başarının Anahtarı',
            description: '🎯 GÜNLÜK RUTIN:\n\n1️⃣ Deneme Çöz\n2️⃣ Netlerini Hemen Kaydet (2 dakika)\n3️⃣ Savaş Raporunu İncele (5 dakika)\n4️⃣ Zayıf Konuları Not Al\n\n📊 SONUÇLAR:\n• Haftalık gelişimini izle\n• Hangi derslerde ilerlediğini gör\n• Hangi konular sıkıntılı tespit et\n• Hedefine ne kadar yakınsın öğren\n\n💡 İPUCU: Deneme Gelişimi grafiğinde yükselişi izlemek, motivasyonu %80 artırıyor!',
            tips: [
              '📝 HER denemeyi kaydet - hiçbirini atlama!',
              '⏰ Deneme biter bitmez kaydet (unutma riski 0)',
              '📊 Haftalık karşılaştırma yap (ilerlemeyi gör)',
            ],
            color: Colors.red,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.analytics_rounded,
            title: 'Savaş Raporu: Zayıflıkları İmha Et',
            description: '🔍 NELER GÖRÜRSÜN?\n\n📌 Ders Bazlı Net Dağılımı\n📌 Doğru/Yanlış/Boş Analizi\n📌 Hangi Konulardan Hata Yaptın\n📌 Güçlü ve Zayıf Dersler\n📌 Zaman Yönetimi Analizi\n\n⚡ NASIL KULLANMALIYIM?\n\n1. Her denemeden sonra raporunu incele\n2. Tekrar eden hataları tespit et\n3. Bu konuları Cevher Atölyesi\'ne ekle\n4. Hedefli çalış ve başarını artır\n\n🎯 Başarı Formülü: Kaydet → Analiz Et → Güçlendir → Tekrarla',
            tips: [
              '🔥 Kırmızı işaretli konular = Acil çalışılmalı',
              '💎 Zayıf konuları Cevher Atölyesi\'ne ekle',
              '📈 Her hafta raporları karşılaştır (gelişim gör)',
            ],
            color: Colors.orange,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.show_chart_rounded,
            title: 'Genel Bakış: Tüm Veriler Tek Ekranda',
            description: '📊 GENEL BAKIŞ NELER SUNAR?\n\n🎯 Toplam Net Gelişimi (grafikli)\n📚 Ders Bazlı Performans\n📈 Haftalık/Aylık Karşılaştırma\n🏆 Hedef Takibi (ne kadar kaldı?)\n💪 Güçlü/Zayıf Konu Haritası\n\n💡 NEDEN ÖNEMLİ?\n\nBaşarılı öğrenciler sayılarla konuşur! Genel Bakış ekranı, tüm performansını tek ekranda gösterir. Nerelerde güçlendiğini, nerede çalışman gerektiğini açıkça görürsün.\n\n📱 HER GÜN KONTROL ET: Gelişimini takip etmek, motivasyonu diri tutar!',
            tips: [
              '📊 Her hafta sonu genel bakışa bak',
              '🎯 Hedef çizgine olan mesafeni kontrol et',
              '💪 Yükseliş gördüğünde kendini ödüllendir!',
            ],
            color: Colors.pink,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildWorkshopGuide(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.withOpacity(0.25),
                  Colors.deepPurple.withOpacity(0.25),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.purple.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.diamond_rounded, color: Colors.purple, size: 48),
                ),
                const SizedBox(height: 16),
                Text(
                  'En Değerli Özellik: Cevher Atölyesi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Zayıf konularını "Cevher"e dönüştür! Yapay zeka, tekrar ettiğin hataları bulur ve bunları kapatmak için özel çalışma programı oluşturur.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up_rounded, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Ortalama 8 net artış garantisi!',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
          const SizedBox(height: 20),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.search_rounded,
            title: 'Akıllı Konu Tespiti',
            description: '🔍 YAPAY ZEKA NASIL TESPİT EDER?\n\n1️⃣ Her deneme sonucunu analiz eder\n2️⃣ Hangi konulardan çok hata yaptığını bulur\n3️⃣ Tekrar eden hataları işaretler\n4️⃣ En kritik 5-10 konuyu "CEVHER" olarak belirler\n\n💎 CEVHER NEDİR?\n\n"Cevher" = Üzerinde çalışınca hızlıca net artışı sağlayan konular!\n\nÖrnek: Matematik\'te "Türev" konusundan sürekli 2-3 soru yanlış yapıyorsun. AI bunu tespit eder ve "Bu konuya 3 gün odaklan, 5 net artır" der.\n\n📊 SONUÇ: Boş yere tüm konuları çalışmak yerine, gerçekten sıkıntılı olanları kapat!',
            tips: [
              '🎯 Her hafta yeni cevherler eklenir (sürekli güncelleme)',
              '✅ Tamamladıkça yeni zayıflıklar tespit edilir',
              '💪 4-5 cevheri kapatınca net artışı garantili!',
            ],
            color: Colors.deepPurple,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.fitness_center_rounded,
            title: 'Hedefli Çalışma Programı',
            description: '💪 3 AŞAMALI SİSTEM:\n\n📚 AŞAMA 1: KONU ANLATIMI\n• Konuyu baştan öğren\n• Video/Kaynak önerileri\n• Temel kavramları pekiştir\n\n✏️ AŞAMA 2: SORU ÇÖZÜMÜ\n• Kolay → Orta → Zor sıralama\n• Adım adım çözüm teknikleri\n• Pratik yapmaya odaklan\n\n🔄 AŞAMA 3: PEKİŞTİRME\n• Benzer soruları tekrar çöz\n• Farklı kaynaklardan test\n• Konuyu tamamen kapat!\n\n🎯 HER CEVHER İÇİN: Ortalama 2-3 gün yeterli. Sonunda o konudan kesin doğru yaparsın!',
            tips: [
              '⏰ Günde 30-45 dakika cevher çalışması yap',
              '📝 Aşamaları atlama (sırayla ilerle)',
              '✅ Tamamladıktan sonra deneme çöz (test et)',
            ],
            color: Colors.cyan,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.workspace_premium_rounded,
            title: 'Premium: Sınırsız Cevher',
            description: '👑 PREMIUM AVANTAJLARI:\n\n💎 Sınırsız Cevher Oluşturma\n🎯 Tüm Derslerde Cevher Desteği\n📊 Detaylı İlerleme Grafikleri\n🤖 Yapay Zeka Konu Önerileri\n📚 Özel Kaynak Tavsiyeleri\n⚡ Hızlandırılmış Analiz\n\n🆚 FARK:\n\nÜcretsiz: 3 cevher/hafta\nPremium: SINIRSIZ cevher!\n\nÜcretsiz: Temel takip\nPremium: Detaylı analiz + Tahminler!\n\n📈 Cevher Atölyesi\'ni aktif kullananlar, ortalama 8 net daha fazla yapıyor!',
            tips: [
              '🎁 Premium ile her konuyu cevhere çevirebilirsin',
              '🚀 Sınırsız çalışma = Sınırsız gelişim',
              '💰 İlk 7 gün ücretsiz, risk yok!',
            ],
            color: Colors.purple,
            isPremiumFeature: true,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildArenaGuide(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.2),
                  Colors.deepOrange.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.orange.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.videogame_asset_rounded, color: Colors.orange, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Çalışmak Eğlenceli Olabilir!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Oyunlaştırma sistemi ile çalışma motivasyonunu %73 artır! Görevler, rozetler, XP ve liderlik tablosu ile rakiplerini geç.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
          const SizedBox(height: 20),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.task_alt_rounded,
            title: 'Günlük Görevler: Her Gün Yeni Hedef',
            description: '🎮 NEDEN GÖREVLER?\n\nÇalışma monotonlaştığında motivasyon düşer. Günlük görevler, her gün sana yeni hedefler sunarak çalışmayı oyun gibi yapar!\n\n📋 GÖREV ÖRNEKLERİ:\n\n✅ 50 soru çöz → 100 XP\n✅ 1 deneme kaydet → 200 XP\n✅ Cevher çalış → 150 XP\n✅ 5 konu tekrar et → 120 XP\n✅ Haftalık plan oluştur → 300 XP\n\n🏆 SEVIYE SİSTEMİ:\n• XP kazan, seviye atla!\n• Yüksek seviye = Prestij\n• Özel rozetler kazan\n• Liderlik tablosunda yüksel',
            tips: [
              '🌅 Her sabah görevleri kontrol et',
              '✅ Tüm görevleri tamamlamaya çalış (bonus XP)',
              '🔥 Seri yap: 7 gün üst üste = Özel rozet!',
            ],
            color: Colors.orange,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.military_tech_rounded,
            title: 'Rozet Koleksiyonu: Başarıları Sergile',
            description: '🏅 ROZET SİSTEMİ:\n\nBaşarıların ödüllendirilir! Her özel başarı için rozet kazan ve profilinde sergile.\n\n🎖️ ROZET KATEGORİLERİ:\n\n🥇 BAŞLANGIÇ: İlk deneme, ilk plan, ilk giriş\n🥈 GELİŞİM: 10 deneme, 50 deneme, 100 deneme\n🥉 DEDIKASYON: 7 gün seri, 30 gün seri, 100 gün seri\n💎 ÖZEL: Ayın öğrencisi, Yılın şampiyonu\n\n🎯 NEDEN ÖNEMLİ?\n• Psikolojik ödüllendirme motivasyonu artırır\n• İlerlemeyi somutlaştırır\n• Paylaşılabilir başarılar (arkadaşlarına göster)\n\n👑 PREMIUM: Özel premium rozetleri ve erken erişim!',
            tips: [
              '🎯 Tüm rozetleri toplamaya çalış (tam koleksiyon)',
              '🏆 Nadir rozetler için ekstra çaba göster',
              '📱 Rozetleri sosyal medyada paylaş (arkadaşlarını motive et)',
            ],
            color: Colors.amber,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.leaderboard_rounded,
            title: 'Liderlik Tablosu: Zirveye Tırman',
            description: '🏆 YARIŞMA RUHU:\n\nKendini başkalarıyla kıyasla ve zirveyi hedefle! Liderlik tablosu, sağlıklı rekabet ortamı yaratır.\n\n📊 3 LİDERLİK TABLOSU:\n\n🔥 HAFTALIK: Bu hafta en aktif kim?\n📅 AYLIK: Ayın şampiyonu sen ol!\n👑 TÜM ZAMANLAR: Efsaneler listesi\n\n💯 PUAN NASIL KAZANILIR?\n\n• Deneme kaydet: +50 puan\n• Görev tamamla: +30 puan\n• Cevher bitir: +100 puan\n• Düzenli giriş: +20 puan/gün\n• Plan oluştur: +80 puan\n\n🎯 Liderlikte olmak = Düzenli ve disiplinli çalışmak!\n\n👑 PREMIUM: Özel liderlik rozeti + Bonus puanlar',
            tips: [
              '🎯 İlk 10a girmeyi hedefle (motivasyon boost)',
              '⚡ Her gün aktif ol (puan kaybetme)',
              '🏆 Arkadaşlarını davet et (birlikte yarışın)',
            ],
            color: Colors.blue,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatsGuide(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.teal.withOpacity(0.2),
                  Colors.green.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.teal.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.insights_rounded, color: Colors.teal, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Ölç, Takip Et, Başar!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Performansını takip eden öğrenciler, %85 daha fazla başarı elde ediyor. Sayılar yalan söylemez!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
          const SizedBox(height: 20),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.analytics_rounded,
            title: 'Detaylı İstatistikler: Kendini Tanı',
            description: '📊 NELER ÖĞRENİRSİN?\n\n📈 NET GELİŞİMİ:\n• İlk deneme: 45 net\n• Son deneme: 68 net\n• Artış: +23 net (+51%)\n• Trend: Yükseliş ↗️\n\n📚 DERS ANALİZİ:\n• Matematik: Güçlü (18/20 doğru)\n• Fizik: Orta (12/14 doğru)\n• Kimya: Zayıf (8/13 doğru) → CEVHERLEŞTİR!\n\n⏱️ ZAMAN YÖNETİMİ:\n• Günlük ortalama: 3.5 saat\n• En verimli saat: 14:00-16:00\n• Haftalık trend: Düzenli\n\n🎯 HEDEF TAKİBİ:\n• Hedef: 85 net\n• Mevcut: 68 net\n• Kalan: 17 net\n• Tahmini: 45 gün\n\n💡 Bu bilgiler, stratejini optimize etmeni sağlar!',
            tips: [
              '📊 Her hafta sonu istatistiklerini incele',
              '🎯 Zayıf yönleri tespit et ve cevherleştir',
              '📈 Grafiklerdeki yükselişi gör (motivasyon boost)',
            ],
            color: Colors.indigo,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.calendar_today_rounded,
            title: 'Günlük Check-in: Disiplin Yarat',
            description: '✅ GÜNLÜK CHECK-IN SİSTEMİ:\n\nHer gün uygulamaya giriş yap = Seri yap!\n\n🔥 SERİ SİSTEMİ:\n• 7 gün: 🥉 Bronz Rozet\n• 30 gün: 🥈 Gümüş Rozet\n• 90 gün: 🥇 Altın Rozet\n• 365 gün: 💎 Elmas Rozet\n\n📈 NEDEN ÖNEMLİ?\n\nAraştırmalar gösteriyor ki:\n• Düzenli giriş = Düzenli çalışma\n• 21 gün seri = Alışkanlık oluşur\n• 90 gün seri = Yaşam tarzı olur\n\n💪 SONUÇ: Seri yaptıkça motivasyon artar, çalışma disiplini otomatikleşir!\n\n🎁 BONUS: Uzun serilerde özel ödüller ve XP kazanırsın!',
            tips: [
              '🌅 Her sabah ilk iş uygulamayı aç',
              '⏰ Alarm kur (unutma riski 0)',
              '🔥 Seriyi ASLA kırma (en az 1 dakika yeter)',
            ],
            color: Colors.green,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.trending_up_rounded,
            title: 'Gelişim Takibi: Görsel Motivasyon',
            description: '📈 GRAFİKLER GÜÇ VERİR!\n\nSayısal veriler grafiklere dönüştüğünde, gelişimini gözlerinle görürsün. Bu, motivasyonu korumada en etkili yöntemdir.\n\n📊 GRAFİK TÜRLERİ:\n\n1️⃣ NET GELİŞİM ÇIZGISI:\n• Zamanla net artışını gör\n• Trend analizi (yükseliyor mu?)\n• Hedef çizgisi ile karşılaştır\n\n2️⃣ DERS BAZLI RADAR:\n• Hangi derste güçlüsün?\n• Hangi ders zayıf?\n• Denge durumu nedir?\n\n3️⃣ ÇALIŞMA SAATLERİ:\n• Günlük/Haftalık toplam\n• En verimli zamanlar\n• Düzenlilik analizi\n\n4️⃣ BAŞARI HARİTASI:\n• Tamamlanan görevler\n• Kapatılan cevherler\n• Toplanan rozetler\n\n💡 Premium: Daha detaylı grafikler + Tahmin algoritması!',
            tips: [
              '📊 Grafikleri düzenli kontrol et (haftada 2-3 kez)',
              '📸 Gelişim grafiğinin ekran görüntüsünü al (arşivle)',
              '🎯 Düşük trend görürsen strateji değiştir',
            ],
            color: Colors.teal,
            isPremiumFeature: false,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            isDark,
            icon: Icons.workspace_premium_rounded,
            title: 'Premium: İstatistik Canavarı Ol',
            description: '👑 PREMIUM İSTATİSTİKLER:\n\n📊 Detaylı Analiz Raporları\n🔮 Gelecek Tahmini (AI destekli)\n📈 Karşılaştırmalı Grafikler\n💎 Konu Bazlı Performans\n⏱️ Zaman Optimizasyon Önerileri\n🎯 Kişisel Gelişim Planı\n📱 Haftalık İlerleme Raporu (e-posta)\n\n🆚 FARK:\n\nÜcretsiz: Temel istatistikler\nPremium: Profesyonel analiz!\n\nÜcretsiz: Genel grafikler\nPremium: Konu bazlı detay + Tahmin!\n\n🎁 ÖZEL: Premium ile "Sınav Simülasyonu" özelliği!\n• Mevcut performansınla sınavda kaç net yaparsın?\n• Hedefine ulaşmak için ne yapmalısın?\n• Hangi stratejiler işe yarar?\n\n💰 İlk 7 gün ÜCRETSİZ dene!',
            tips: [
              '📊 Premium ile her detayı gör',
              '🔮 Gelecek tahmini, hedef belirlemeye yardımcı olur',
              '🏆 Profesyonel analiz = Profesyonel sonuçlar',
            ],
            color: Colors.purple,
            isPremiumFeature: true,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
      BuildContext context,
      bool isDark, {
        required IconData icon,
        required String title,
        required String description,
        required List<String> tips,
        required Color color,
        bool isPremiumFeature = false,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isPremiumFeature
            ? Border.all(
          color: Colors.amber.withOpacity(0.5),
          width: 2,
        )
            : null,
        boxShadow: [
          BoxShadow(
            color: isPremiumFeature
                ? Colors.amber.withOpacity(0.2)
                : Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPremiumFeature
                    ? [
                  Colors.amber.withOpacity(0.2),
                  Colors.orange.withOpacity(0.15),
                ]
                    : [
                  color.withOpacity(0.2),
                  color.withOpacity(0.1),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPremiumFeature
                        ? Colors.amber.withOpacity(0.25)
                        : color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: isPremiumFeature ? Colors.amber : color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (isPremiumFeature) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'PREMIUM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_rounded, color: color, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'İpuçları',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...tips.map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tip.split(' ')[0], // Emoji
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tip.substring(tip.indexOf(' ') + 1), // Text without emoji
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSuccessStoryCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.withOpacity(0.2),
            Colors.teal.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_graph_rounded, color: Colors.green, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Başarı Hikayesi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '"İlk başta 45 net yapıyordum. Taktik\'i kullanmaya başladıktan 3 ay sonra 78 net\'e çıktım! Özellikle Deneme Arşivi ve Cevher Atölyesi çok işime yaradı."',
            style: TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              height: 1.6,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '📈 +33 Net Artış',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '⏱️ 90 Gün',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '- Ahmet K., YKS 2024',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }
}

