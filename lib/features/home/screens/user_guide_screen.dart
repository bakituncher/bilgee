// lib/features/home/screens/user_guide_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, {required this.isDark});

  final TabBar _tabBar;
  final bool isDark;

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF4F6F8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF4F6F8),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // PREMIUM APP BAR
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              floating: false,
              backgroundColor: const Color(0xFF1A1A1A),
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 60, right: 16, bottom: 16),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎯 Taktik Rehberi',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Akıllı çalış, başarıyı yakala',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withBlue(180),
                            const Color(0xFF1E3A8A),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                    // Animated particles effect
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Icon(
                        Icons.stars_rounded,
                        size: 150,
                        color: Colors.amber.withOpacity(0.08),
                      ),
                    ),
                    Positioned(
                      left: -20,
                      bottom: -20,
                      child: Icon(
                        Icons.rocket_launch_rounded,
                        size: 100,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    // Close button positioned safely
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 8,
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        ),
                        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // TAB BAR
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.secondary],
                    ),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(3),
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: const [
                    Tab(text: 'Başlangıç 🚀'),
                    Tab(text: 'Plan 📅'),
                    Tab(text: 'Arşiv 📚'),
                    Tab(text: 'Cevher 💎'),
                    Tab(text: 'Arena 🎮'),
                    Tab(text: 'İstatistik 📊'),
                  ],
                ),
                isDark: isDark,
              ),
            ),
          ];
        },
        body: TabBarView(
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
    );
  }

  // ---------------------------------------------------------------------------
  // SECTOR-LEVEL WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title, String subtitle, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildInfoCard(
      BuildContext context, {
        required bool isDark,
        required IconData icon,
        required String title,
        required String content,
        required Color accentColor,
        Widget? bottomContent,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF2D3436),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        content,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? Colors.grey[400] : const Color(0xFF636E72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (bottomContent != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: bottomContent,
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildTipRow(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB CONTENTS
  // ---------------------------------------------------------------------------

  Widget _buildStartingGuide(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // Clean Hero Banner
        Container(
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Column(
            children: [
              Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 36),
              SizedBox(height: 10),
              Text(
                'Hoş Geldin!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Yapay zeka destekli çalışma sistemi ile\nhedefine daha hızlı ulaş',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).scale(delay: 100.ms),

        _buildSectionHeader(
          '🚀 3 Adımda Başla',
          'Hemen kullanmaya başla, farkı hisset.',
          color: Colors.blue,
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.psychology_alt_rounded,
          title: '1. Yapay Zeka Seni Öğrensin',
          content: 'Sınav türün, hedef puanın, güçlü/zayıf konuların... AI her şeyi analiz edip sana özel strateji oluşturur.',
          accentColor: Colors.blue,
          bottomContent: Column(
            children: [
              _buildTipRow('🎯 Gerçekçi hedefler = Sürdürülebilir başarı', isDark),
              _buildTipRow('⏰ Dürüst zaman planı = Etkili çalışma', isDark),
              _buildTipRow('📊 İlk verin kalitesi = AI doğruluğu', isDark),
            ],
          ),
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.schedule_rounded,
          title: '2. Günde Sadece 2 Dakika Ayır',
          content: 'Karmaşık sisteme elveda! Deneme çözdün mü? Netlerini gir, gerisini AI halleder. Saat değil, verimlilik önemli.',
          accentColor: Colors.orange,
          bottomContent: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMicroStat('⚡', '2 dk', 'Veri Girişi'),
              _buildMicroStat('🧠', '10 sn', 'AI Analiz'),
              _buildMicroStat('📈', 'Anında', 'Sonuç'),
            ],
          ),
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.auto_graph_rounded,
          title: '3. Sonuçları İzle, Motive Ol',
          content: 'Her hafta gelişimini grafiklerle gör. Motivasyon kaybetmek imkansız hale geliyor. Rakiplerini geç, liderler tablosuna çık!',
          accentColor: Colors.green,
        ),

        const SizedBox(height: 12),

        // Helpful Tip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.blue.shade900.withOpacity(0.2) : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade700.withOpacity(0.3), width: 2),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '💡 İpucu: Ana sayfadaki rehber görevlerini takip ederek sistemi öğren!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyPlanGuide(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // Value Proposition Header
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade600, Colors.teal.shade600],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Column(
            children: [
              Icon(Icons.military_tech, color: Colors.amber, size: 36),
              SizedBox(height: 8),
              Text(
                '📅 Haftalık Planın Gücü',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6),
              Text(
                '"Başarılı öğrenciler planlı çalışır.\nSen de aralarına katıl!"',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // AI Logic Visualization - Improved
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Text(
                '🤖 AI Nasıl Çalışır?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildProcessStep(Icons.analytics_rounded, 'Analiz', isDark),
                  const Icon(Icons.arrow_forward, color: Colors.green, size: 20),
                  _buildProcessStep(Icons.warning_amber_rounded, 'Eksik\nTespiti', isDark),
                  const Icon(Icons.arrow_forward, color: Colors.green, size: 20),
                  _buildProcessStep(Icons.auto_fix_high, 'Özel\nPlan', isDark),
                ],
              ),
            ],
          ),
        ),

        _buildSectionHeader(
          '⚡ Özellikler',
          'Senin için çalışan, seninle gelişen akıllı planlama.',
          color: Colors.green,
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.tune_rounded,
          title: 'Yoğunluk Kontrolü Sende',
          content: 'Sınav haftası mı? Tatilde misin? Her hafta farklı mod seç, plan otomatik ayarlansın.',
          accentColor: Colors.teal,
          bottomContent: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTag('🟢 Rahat', Colors.green),
                  _buildTag('🟡 Orta', Colors.orange),
                  _buildTag('🔴 Yoğun', Colors.red),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '💡 Her mod farklı görev yoğunluğu ve zorluk seviyesi sunar',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.timeline_rounded,
          title: 'Dinamik & Esnek Planlama',
          content: 'Planı tamamlayamadın mı? Sorun değil! Görevleri haftaya taşı ya da planı yenile. Hayat olduğu gibi devam eder.',
          accentColor: Colors.purple,
          bottomContent: Column(
            children: [
              _buildTipRow('🔄 Tek tıkla plan yenileme', isDark),
              _buildTipRow('📆 Görevleri sonraki haftaya taşıma', isDark),
              _buildTipRow('✅ Tamamlanan görevler otomatik işaretlenir', isDark),
            ],
          ),
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.school_rounded,
          title: 'Okul Programı Entegrasyonu',
          content: 'Okul saatlerin, özel ders programın... Her şeyi hesaba kat. Plan, gerçek müsaitliğine göre oluşturulsun.',
          accentColor: Colors.indigo,
        ),

        // Success Metric
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.green.shade50.withOpacity(isDark ? 0.2 : 1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '💡 Planlı çalışmak, başarının en önemli anahtarıdır!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.green.shade200 : Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryGuide(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // Hero Banner
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.deepOrange.shade600],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Column(
            children: [
              Icon(Icons.library_books_rounded, color: Colors.white, size: 40),
              SizedBox(height: 8),
              Text(
                '📚 Deneme Arşivi',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 4),
              Text(
                '"Veri olmadan strateji olmaz!\nHer deneme bir altın madenidir."',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        _buildSectionHeader(
          '🎯 Sadece Kayıt Değil, Analiz',
          'Netlerini giriyorsun, AI her şeyi analiz ediyor.',
          color: Colors.redAccent,
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.radar_rounded,
          title: '⚡ Anlık Detaylı Rapor',
          content: 'Deneme bittiğinde sadece "Kaç net?" değil, "Neden bu kadar?" sorusuna da cevap al:',
          accentColor: Colors.red,
          bottomContent: Column(
            children: [
              _buildTipRow('📊 Konu bazlı başarı haritası', isDark),
              _buildTipRow('🎯 Doğru/Yanlış/Boş oranları', isDark),
              _buildTipRow('📈 Önceki denemelerle trend grafiği', isDark),
              _buildTipRow('🏆 Hedef puanına ne kadar yakınsın?', isDark),
            ],
          ),
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.gps_fixed_rounded,
          title: '🔴 Zayıf Nokta Tespit Sistemi',
          content: 'Sürekli aynı konularda mı takılıyorsun? AI bunu fark eder ve kırmızı alarm verir: "Türev\'e odaklan!"',
          accentColor: Colors.orange,
          bottomContent: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildColorBadge('🟢', 'Güçlü', Colors.green),
              const SizedBox(width: 8),
              _buildColorBadge('🟡', 'Orta', Colors.orange),
              const SizedBox(width: 8),
              _buildColorBadge('🔴', 'Zayıf', Colors.red),
            ],
          ),
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.history_rounded,
          title: '📊 Gelişim Grafiği',
          content: 'Her deneme sonrası grafiğini gör. Net artışın gerçek zamanlı olarak takip edilir. Motive olmak bu kadar kolaydı!',
          accentColor: Colors.blue,
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.compare_arrows_rounded,
          title: '🆚 Karşılaştırma Modu',
          content: 'İki denemeyi yan yana koy. Hangi konularda ilerleme var? Hangi derste düşüş? Hepsi net ve görsel.',
          accentColor: Colors.purple,
        ),

        // Motivation
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade50.withOpacity(isDark ? 0.2 : 1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.trending_up_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '📈 Her deneme bir adım, her analiz bir fırsat! Başarı veriye dayalıdır.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkshopGuide(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // Hero Banner
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade700, Colors.purple.shade600],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Column(
            children: [
              Icon(Icons.diamond_rounded, color: Colors.amber, size: 44),
              SizedBox(height: 10),
              Text(
                '💎 Cevher Atölyesi',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 6),
              Text(
                '"Zayıf noktalar = En büyük potansiyel!\nBurayı çalış, sıralamanda sıçra."',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Value Prop - Cevher tanımı
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber.shade600, Colors.orange.shade600],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.emoji_objects_rounded, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '💡 Cevher = Az çalışma, çok net!\nSana en fazla puan getirecek kritik konular.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),

        _buildSectionHeader(
          '🎯 Nasıl Çalışır?',
          'AI analiz eder, sen sadece takip et.',
          color: Colors.purple,
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.psychology_rounded,
          title: '🤖 AI Zayıf Noktayı Bulur',
          content: 'Deneme verilerine bakarak hangi konularda en çok hata yaptığını tespit eder. Sonra bunları "Cevher" olarak işaretler.',
          accentColor: Colors.deepPurple,
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.auto_fix_high_rounded,
          title: '📚 3 Aşamalı Özel Reçete',
          content: 'Her cevher için AI, sana özel 3 aşamalı çalışma planı hazırlar:',
          accentColor: Colors.purple,
          bottomContent: Column(
            children: [
              _buildStepRow('1', '📖 Konu Anlatımı', 'Temelden başla, eksikleri kapat'),
              _buildStepRow('2', '✏️ Soru Çözümü', 'Pratik yap, hızlan, güven kazan'),
              _buildStepRow('3', '🏆 Pekiştirme', 'Zor sorularla ustalaş, sınav hazır ol'),
            ],
          ),
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.check_circle_outline_rounded,
          title: '✅ İlerlemeyi Takip Et',
          content: 'Her adımı tamamladıkça cevher parlıyor. Tamamlandığında o konu artık "güçlü" kategorisine geçer.',
          accentColor: Colors.green,
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.rocket_launch_rounded,
          title: '🚀 Odaklanmış Çalışma',
          content: 'Zayıf konularına odaklanarak daha verimli çalış. Az ama etkili çalışma = Hızlı gelişim!',
          accentColor: Colors.orange,
        ),

        // Success Banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.purple.shade50.withOpacity(isDark ? 0.2 : 1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.diamond_rounded, color: Colors.purple, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '💎 Zayıf noktaların aslında en büyük potansiyelindir!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.purple.shade200 : Colors.purple.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArenaGuide(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // Hero Gaming Banner
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade700, Colors.deepOrange.shade600],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videogame_asset_rounded, color: Colors.white, size: 32),
                  SizedBox(width: 12),
                  Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 36),
                  SizedBox(width: 12),
                  Icon(Icons.military_tech_rounded, color: Colors.white, size: 32),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '🎮 Arena & Oyunlaştırma',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                '"Ders çalışmak artık bir oyun!\nRakiplerini geç, zirveye çık."',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              // TP & Rank badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickStatBadge('⚡', 'TP', 'Her eylem puan', Colors.amber),
                  _buildQuickStatBadge('🏆', 'Liderlik', 'Sıralamada çık', Colors.blue),
                  _buildQuickStatBadge('🎖️', 'Rozet', 'Başarı göster', Colors.purple),
                ],
              ),
            ],
          ),
        ),

        _buildSectionHeader(
          '🎯 Nasıl Çalışır?',
          'Çalış, kazan, yarış!',
          color: Colors.orange,
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.bolt_rounded,
          title: '⚡ Her Şey TP Kazandırır',
          content: 'Deneme çözme, cevher tamamlama, görev bitirme... Her başarılı eylem sana TP kazandırır. TP = Seviye atlama!',
          accentColor: Colors.amber,
          bottomContent: Column(
            children: [
              _buildTipRow('✅ Deneme çöz → +50 TP', isDark),
              _buildTipRow('💎 Cevher tamamla → +100 TP', isDark),
              _buildTipRow('🎯 Günlük görev → +25 TP', isDark),
              _buildTipRow('🔥 Seri bonus → +10 TP/gün', isDark),
            ],
          ),
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.task_alt_rounded,
          title: '📋 Günlük Görevler',
          content: 'Her gün sana özel 3-5 küçük görev verilir. Bunları tamamla, hem disiplinli çalış hem de ekstra TP kazan.',
          accentColor: Colors.blue,
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.leaderboard_rounded,
          title: '🏆 Liderlik Tablosu',
          content: 'Haftalık ve aylık liderlik tablolarında rakiplerini gör. Seni geçenler motivasyon, sen geçenler gurur kaynağın!',
          accentColor: Colors.green,
          bottomContent: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🥇 ', style: TextStyle(fontSize: 20)),
              Text('🥈 ', style: TextStyle(fontSize: 20)),
              Text('🥉 ', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('Top 3 = Özel ödüller!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.emoji_events_rounded,
          title: '🎖️ Rozet Koleksiyonu',
          content: 'Başarılarını göster! Her milestone\'da yeni rozet kazan:',
          accentColor: Colors.deepOrange,
          bottomContent: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildBadgeChip('🎯 Deneme Fatihi'),
              _buildBadgeChip('💎 Cevher Avcısı'),
              _buildBadgeChip('🔥 Alev Ustası'),
              _buildBadgeChip('⭐ Efsane'),
            ],
          ),
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.whatshot_rounded,
          title: '🔥 Streak (Seri) Sistemi',
          content: 'Art arda gün sayısını artır! 7 gün, 30 gün, 100 gün... Her milestone ekstra TP ve özel rozetler kazandırır.',
          accentColor: Colors.red,
        ),

        // Gamification CTA
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade700, Colors.pink.shade600],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.celebration_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🎊 Çalışmak hiç bu kadar eğlenceli olmamıştı!\nOyun oyna gibi başarıya ulaş.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGuide(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // Hero Analytics Banner
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade700, Colors.blue.shade600],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Column(
            children: [
              Icon(Icons.analytics_rounded, color: Colors.white, size: 42),
              SizedBox(height: 10),
              Text(
                '📊 İstatistik & Analiz',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 6),
              Text(
                '"Ölçemediğin şeyi geliştiremezsin.\nVeriye dayalı başarı burada!"',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        _buildSectionHeader(
          '📈 Gelişimini Gör, Motive Ol',
          'Her grafik bir başarı hikayesi anlatır.',
          color: Colors.indigo,
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.show_chart_rounded,
          title: '📊 Dinamik Gelişim Grafikleri',
          content: 'Netlerin artıyor mu? Hangi derste ilerleme var? Trend ne yönde? Hepsi görsel ve interaktif grafiklerle önünde.',
          accentColor: Colors.indigo,
          bottomContent: Column(
            children: [
              _buildTipRow('📈 Net artış trendleri (haftalık/aylık)', isDark),
              _buildTipRow('🎯 Ders bazlı performans analizi', isDark),
              _buildTipRow('📉 Düşüş tespiti ve erken uyarı', isDark),
              _buildTipRow('🏆 Hedefe kalan mesafe göstergesi', isDark),
            ],
          ),
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.compare_rounded,
          title: '🔄 Karşılaştırmalı Analiz',
          content: 'Geçen aya göre ne kadar ilerledin? Geçen haftaki performansınla bugünkü arasında fark var mı? Karşılaştır, öğren.',
          accentColor: Colors.blue,
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.radar_rounded,
          title: '🎯 Güç-Zayıf Haritası',
          content: 'Hangi konularda güçlüsün? Nerelerde eksiksin? Renkli ısı haritasıyla anlık durum analizi.',
          accentColor: Colors.purple,
          bottomContent: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildColorBadge('🟢', 'Güçlü', Colors.green),
              const SizedBox(width: 8),
              _buildColorBadge('🟡', 'Orta', Colors.orange),
              const SizedBox(width: 8),
              _buildColorBadge('🔴', 'Zayıf', Colors.red),
            ],
          ),
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.local_fire_department_rounded,
          title: '🔥 Streak (Seri) Takibi',
          content: 'İstikrar = Başarı! Her gün çalışarak serini uzat. Uzun seriler ekstra TP ve özel rozetler kazandırır.',
          accentColor: Colors.deepOrange,
          bottomContent: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStreakMilestone('7', 'gün', '🥉'),
              _buildStreakMilestone('30', 'gün', '🥈'),
              _buildStreakMilestone('100', 'gün', '🥇'),
            ],
          ),
        ),

        _buildInfoCard(
          context,
          isDark: isDark,
          icon: Icons.psychology_rounded,
          title: '🧠 AI Önerileri',
          content: 'İstatistiklerine bakarak AI, sana özel tavsiyeler verir: "Matematik\'te harikasın ama Türkçe\'ye biraz daha ağırlık ver!"',
          accentColor: Colors.teal,
        ),

        // Motivation Banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade600, Colors.teal.shade600],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.trending_up, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '📈 Grafikler yükselirken motivasyon da yükselir!\nİlerlemeyi görmek, devam etmenin en güçlü sebebidir.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildProcessStep(IconData icon, String label, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
          child: Icon(icon, size: 18, color: isDark ? Colors.white : Colors.black54),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildMicroStat(String icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.orange),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildColorBadge(String emoji, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatBadge(String emoji, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepOrange.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange),
      ),
    );
  }

  Widget _buildStreakMilestone(String days, String label, String medal) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medal, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          days,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.deepOrange),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStepRow(String step, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.deepPurple,
              shape: BoxShape.circle,
            ),
            child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                children: [
                  TextSpan(text: "$title: ", style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.deepPurple)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String title, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}