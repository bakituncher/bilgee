// lib/features/home/screens/user_guide_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    // Tab sayısını ve etiketleri kısalttık
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Kompakt App Bar
          SliverAppBar(
            expandedHeight: 120, // Yüksekliği azalttık
            pinned: true,
            backgroundColor: theme.colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: const Text(
                'Hızlı Başlangıç',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                  ),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 30, top: 30),
                child: Icon(Icons.school_rounded, size: 60, color: Colors.white.withOpacity(0.15)),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // 2. Motivasyon Banner'ı (Daha sade)
                _buildCompactWelcome(context),

                const SizedBox(height: 16),

                // 3. Modern Tab Bar
                Container(
                  height: 45,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.white,
                    unselectedLabelColor: theme.colorScheme.primary,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: theme.colorScheme.primary,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    dividerColor: Colors.transparent,
                    // Emoji + Kısa Metin
                    tabs: const [
                      Tab(text: '🚀 Başla'),
                      Tab(text: '📅 Plan'),
                      Tab(text: '📚 Arşiv'),
                      Tab(text: '💎 Cevher'),
                      Tab(text: '🎮 Arena'),
                      Tab(text: '📊 Analiz'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 4. İçerik Alanı
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75, // Dinamik yükseklik
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

  Widget _buildCompactWelcome(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '10 Dakikada Ustalaş',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  'Bu rehberi tamamla, rakiplerinin önüne geç.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2, end: 0);
  }

  // --- REUSABLE COMPACT CARD ---
  // Bu widget tekrarlayan kodları önler ve tasarımı sıkılaştırır.
  Widget _buildCompactCard(
      BuildContext context, {
        required bool isDark,
        required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        String? proTip,
        bool isPremium = false,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isPremium ? Colors.amber.withOpacity(0.5) : Colors.transparent,
            width: 1.5
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('PRO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                          )
                        ]
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (proTip != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      proTip,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  }

  // --- SECTIONS ---

  Widget _buildStartingGuide(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.rocket_launch_rounded,
          title: 'İlk Adım: Hedefini Seç',
          subtitle: 'YKS, LGS veya KPSS... Hedef puanını ve boş vakitlerini gir, yapay zeka sana özel rotayı hemen çizsin.',
          color: Colors.blue,
          proTip: 'Dürüst ol! Müsait saatlerini doğru girersen planın şaşmaz.',
        ),
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.timer_rounded,
          title: '10 Dakika Kuralı',
          subtitle: 'Günde sadece 10 dakika ayırıp deneme sonuçlarını gir. Gerisini "Taktik" halleder.',
          color: Colors.green,
          proTip: 'Her gün aynı saatte giriş yaparsan XP bonusu kazanırsın!',
        ),
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.workspace_premium_rounded,
          title: 'Premium Avantajı',
          subtitle: 'Sınırsız yapay zeka analizi ile başarı şansını %67 artır. İlk hafta ücretsiz.',
          color: Colors.purple,
          isPremium: true,
        ),
      ],
    );
  }

  Widget _buildWeeklyPlanGuide(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.psychology_alt_rounded,
          title: 'Akıllı Planlama',
          subtitle: 'Yapay zeka; eksiklerine, kalan zamana ve okul programına göre her hafta dinamik bir plan oluşturur.',
          color: Colors.teal,
          proTip: 'Planı pazartesi sabahı yenilemek en iyisidir.',
        ),
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.speed_rounded,
          title: 'Temponu Sen Belirle',
          subtitle: '🟢 Rahat: Temel at.\n🟡 Orta: Dengeli git.\n🔴 Yoğun: Son düzlük, gaza bas!',
          color: Colors.orange,
        ),
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.tune_rounded,
          title: 'Sınırsız Düzenleme',
          subtitle: 'Plan uymadı mı? Premium ile anında revize et ve yeni duruma adapte ol.',
          color: Colors.purple,
          isPremium: true,
        ),
      ],
    );
  }

  Widget _buildLibraryGuide(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.qr_code_scanner_rounded,
          title: 'Kayıt = Zafer',
          subtitle: 'Çözdüğün her denemeyi kaydet. Unutma, ölçmediğin şeyi geliştiremezsin.',
          color: Colors.red,
          proTip: 'Deneme biter bitmez netlerini gir, erteleme!',
        ),
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.analytics_outlined,
          title: 'Savaş Raporu',
          subtitle: 'Hangi konuda kaçtın, hangisinde kralsın? Deneme sonrası anında analiz raporunu gör.',
          color: Colors.deepOrange,
        ),
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.history_edu_rounded,
          title: 'Gelişim Grafiği',
          subtitle: 'Netlerin yükseliyor mu? Haftalık ve aylık grafiklerle ilerlemeni takip et.',
          color: Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildWorkshopGuide(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.purple.withOpacity(0.2), Colors.deepPurple.withOpacity(0.1)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.diamond_rounded, color: Colors.purple),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '"Cevher Atölyesi" en önemli silahın. Zayıf konuları tespit edip altına dönüştürür.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.search_rounded,
          title: 'Otomatik Tespit',
          subtitle: 'Sürekli yanlış yaptığın konuları yapay zeka bulur ve "Cevher" olarak önüne getirir.',
          color: Colors.deepPurple,
        ),
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.fitness_center_rounded,
          title: '3 Adımda Yok Et',
          subtitle: '1. Konu Çalış\n2. Soru Çöz\n3. Pekiştir\nBu reçeteyi uygula, o konuyu bir daha yanlış yapma.',
          color: Colors.pink,
          proTip: 'Haftada en az 2 cevher bitirenler 8 net artırıyor.',
        ),
      ],
    );
  }

  Widget _buildArenaGuide(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.gamepad_rounded,
          title: 'Oyunlaştırma',
          subtitle: 'Sıkıcı çalışmayı bırak. Görev yap, XP topla, seviye atla. Çalışmak artık bir RPG oyunu.',
          color: Colors.orange,
        ),
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.military_tech_rounded,
          title: 'Rozet Avcısı',
          subtitle: '"Seri Katil" (7 gün üst üste), "Deneme Canavarı" (100 deneme)... Koleksiyonu tamamla!',
          color: Colors.amber,
        ),
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.leaderboard_rounded,
          title: 'Liderlik Tablosu',
          subtitle: 'Arkadaşlarınla yarış. Haftanın en çalışkanı ol, zirveye adını yazdır.',
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildStatsGuide(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.insights_rounded,
          title: 'Sayılar Yalan Söylemez',
          subtitle: 'Net gelişimi, ders başarısı, zaman yönetimi... Her şey grafiklerle elinin altında.',
          color: Colors.teal,
        ),
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.calendar_month_rounded,
          title: 'Zinciri Kırma',
          subtitle: 'Her gün giriş yap, seriyi bozma. 21 gün serisi alışkanlık yaratır.',
          color: Colors.green,
          proTip: 'Ana ekrandaki alev simgesi serini gösterir 🔥',
        ),
        _buildCompactCard(
          context, isDark: isDark,
          icon: Icons.auto_graph_rounded,
          title: 'Gelecek Tahmini',
          subtitle: 'Yapay zeka, mevcut hızınla sınavda kaç yapacağını tahmin eder. Rota oluşturur.',
          color: Colors.purple,
          isPremium: true,
        ),
      ],
    );
  }
}