// lib/features/settings/screens/faq_screen.dart
import 'package:flutter/material.dart';
import 'package:taktik/shared/widgets/custom_back_button.dart';
import 'package:taktik/shared/widgets/pro_badge.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late final List<FAQItem> _faqItems;

  @override
  void initState() {
    super.initState();
    _faqItems = [
      // --- ÜCRETLENDİRME & PRO ---
      FAQItem(
        question: "Taktik ücretli mi?",
        answer:
        "Hayır, Taktik'i indirmek ve kullanmak ücretsizdir. Sınav sayaçları, konu takip çizelgeleri, pomodoro, deneme analizleri ve soru kutusu gibi daha sayamadığımız temel özelliklerin tamamı herkese açıktır. Ayrıca her gün yenilenen belirli sayıda ücretsiz 'Soru Çözücü' ve 'Dönüştürücü' kullanım hakkınız bulunur.",
      ),

      // --- TABLOLU SORU ---
      FAQItem(
        question: "PRO üyelerin farkı ne?",
        answer: "PRO üyelik farkları tablosu: Soru çözümü, planlama, analiz özellikleri karşılaştırması.", // Arama için anahtar kelimeler
        customContent: const _ProComparisonTable(), // Özel Tablo Widget'ı
      ),

      FAQItem(
        question: "Neden PRO üyelik var?",
        answer:
        "Taktik, standart test uygulamalarından farklı olarak, her öğrenci için anlık çalışan, maliyetli ve gelişmiş Yapay Zeka (AI) modelleri kullanır. Bu akıllı sistemin sürekliliğini sağlamak, yüksek sunucu maliyetlerini karşılamak ve size reklamsız, sınırsız bir deneyim sunabilmek için PRO üyelik modeline ihtiyaç duyuyoruz.",
      ),
      FAQItem(
        question: "Bir özel ders yerine Taktik'i neden tercih etmeliyim?",
        answer:
        "Taktik, özel dersin yerini almaktan ziyade, onu tamamlayan çok daha ekonomik ve ulaşılabilir bir 'Dijital Koç'tur. Bir saatlik özel ders ücretine, bir yıl boyunca PRO özelliklere sınırsız erişim kazanırsınız. Taktik, hocanızın yanınızda olmadığı her an size destek olmak için oradadır.",
      ),
      FAQItem(
        question: "PRO'yu ücretsiz deneyebilir miyim?",
        answer:
        "Evet! PRO özelliklerin tümünü 1 hafta ücretsiz deneyebilirsiniz. Bu sürede Taktik PRO araçlarının çalışma veriminizi nasıl artırdığını bizzat test edebilirsiniz.",
      ),
      FAQItem(
        question: "PRO iptali sonrası ne olur?",
        answer:
        "Aboneliğinizi iptal ettiğinizde, mevcut döneminizin sonuna kadar haklarınız devam eder. Dönem bittiğinde hesabınız 'Ücretsiz' plana geçer. Hiçbir veriniz, test geçmişiniz veya konu takibiniz silinmez; sadece PRO özelliklere (sınırsız AI kullanımı gibi) erişiminiz kısıtlanır.",
      ),
      FAQItem(
        question: "Öğrenci indirimi var mı?",
        answer:
        "Taktik zaten öğrenciler ve mesleğe yeni adım atacak kullanıcılarımız için geliştirildiğinden, fiyatlandırmamız piyasa koşullarının çok altında, harçlıkla karşılanabilecek en ekonomik seviyede tutulmuştur.",
      ),
      FAQItem(
        question: "\"Sınırsız\" gerçekten sınırsız mı?",
        answer:
        "Adil Kullanım Kotası gereği sistem güvenliği için oldukça yüksek bir üst sınırımız var. Korkma! Bu sınıra ulaşmak neredeyse imkansız.\n\nEğer ulaşmayı başarırsan, sen bizim için bir \"Derece Öğrencisi\" adayısın demektir. Destek ekibimize ulaş, bu başarını kutlayalım ve hesabına hemen ücretsiz ek hak yükleyelim. Biz çalışanın her zaman yanındayız! 🏆",
      ),

      // --- GENEL ---
      FAQItem(
        question: "Hangi sınavlar destekleniyor?",
        answer:
        "Taktik şu anda YKS (TYT-AYT), LGS, KPSS, AGS, ALES ve DGS için tam destek vermektedir. Müfredat ve konular düzenli olarak güncellenir.",
      ),
      FAQItem(
        question: "İnternet olmadan kullanabilir miyim?",
        answer:
        "Hayır. Taktik'in yapay zeka destekli analiz yapabilmesi ve verilerinizi bulutta güvenle saklayabilmesi için internet bağlantısı gereklidir.",
      ),

      // --- AI ÖZELLİKLERİ ---
      FAQItem(
        question: "Taktik beni nasıl tanıyor?",
        answer:
        "Taktik, senin başarı yolculuğundaki en yakın çalışma arkadaşın ve dijital koçundur. Seni tanımak için sisteme girdiğin her deneme sonucunu, ders bazlı net verilerini ve konu performanslarını titizlikle analiz eder. Sen veri girdikçe Taktik; hangi konularda parladığını, hangi konularda ise biraz daha desteğe ihtiyacın olduğunu öğrenir. Kısacası; sen hedeflerine doğru ilerlerken, Taktik de senin verilerinle gelişimini takip eder ve tamamen sana özel bir çalışma stratejisi geliştirir.",
      ),
      FAQItem(
        question: "Üretilen içeriklere güvenebilir miyim?",
        answer:
        "Taktik, akademik kaynaklar ve güncel MEB/ÖSYM müfredatıyla sınırlandırılmış güvenli AI modelleri kullanır. İçerikler sürekli optimize edilse de, yapay zekanın bir yardımcı araç olduğunu ve ana kaynağınızın ders kitaplarınız olması gerektiğini unutmayın.",
      ),
      FAQItem(
        question: "İstatistikler nasıl hesaplanıyor?",
        answer:
        "Girdiğiniz tüm deneme ve test sonuçları, gerçek zamanlı olarak işlenir. Ders bazlı ortalamalarınız, konu dağılımınız ve ilerleme grafikleriniz bu verilerle oluşturulur.",
      ),

      // --- TEKNİK ---
      FAQItem(
        question: "Verilerim güvende mi?",
        answer:
        "Kesinlikle. Tüm verileriniz güvenli sunucularda saklanır. Verileriniz üçüncü şahıslarla asla paylaşılmaz.",
      ),
      FAQItem(
        question: "Hesabımı nasıl silebilirim?",
        answer:
        "Ayarlar > Tehlikeli Bölge > Hesabı Sil yoluyla hesabınızı silebilirsiniz. Bu işlem geri alınamaz ve tüm verileriniz kalıcı olarak silinir.",
      ),
      FAQItem(
        question: "Hangi cihazlarda çalışır?",
        answer:
        "Taktik; iOS 13.0 ve üzeri iPhone/iPad cihazlarda (ve Silicon Mac'lerde), Android 7.0 ve üzeri tüm Android cihazlarda sorunsuz çalışır.",
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FAQItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _faqItems;

    return _faqItems
        .where((item) =>
    item.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        item.answer.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          "Sıkça Sorulan Sorular",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: CustomBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Arama çubuğu
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Sorularda ara...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // FAQ listesi
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
              child: Text(
                'Sonuç bulunamadı',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
                : ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
              itemCount: _filteredItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _FAQItemWidget(item: _filteredItems[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- MODELLER VE WIDGETLAR ---

// FAQ Item Widget
class _FAQItemWidget extends StatefulWidget {
  final FAQItem item;

  const _FAQItemWidget({required this.item});

  @override
  State<_FAQItemWidget> createState() => _FAQItemWidgetState();
}

class _FAQItemWidgetState extends State<_FAQItemWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
          },
          title: Text(
            widget.item.question,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          trailing: Icon(
            _isExpanded ? Icons.remove : Icons.add,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          children: [
            // Eğer özel içerik (Tablo vb.) varsa onu göster, yoksa düz yazıyı göster
            Align(
              alignment: Alignment.centerLeft,
              child: widget.item.customContent ??
                  Text(
                    widget.item.answer,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// Model - customContent eklendi
class FAQItem {
  final String question;
  final String answer;
  final Widget? customContent; // Özel tablo widget'ı için opsiyonel alan

  FAQItem({
    required this.question,
    required this.answer,
    this.customContent,
  });
}

// --- ÖZEL TABLO WIDGET'I ---
class _ProComparisonTable extends StatelessWidget {
  const _ProComparisonTable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Başlık - Şık Kutu
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 16),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1565C0).withValues(alpha: 0.1),
                const Color(0xFF1976D2).withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF1565C0).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Text(
            "Tüm ücretsiz özelliklere ek, 1 kahve fiyatına sınırları kaldırır",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              letterSpacing: 0.5,
            ),
          ),
        ),
        // Tablo
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    "Özellikler",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Ücretsiz",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: ProBadge(
                      fontSize: 9,
                      horizontalPadding: 6,
                      verticalPadding: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          _buildRow(theme, "Soru Çözücü", "3 soru/gün", "Sınırsız"),
          _buildRow(theme, "Not Defteri", "3 hak/gün", "Sınırsız"),
          _buildRow(theme, "Haftalık Plan", false, true),
          _buildRow(theme, "Zihin Haritaları", false, true),
          _buildRow(theme, "Etüt Odası", false, true),
          _buildRow(theme, "Koçun Taktik Tavşan", false, true),
          _buildRow(theme, "Reklamlar", "Var", "Yok", isLast: true),
        ],
      ),
        ),
      ],
    );
  }

  Widget _buildRow(ThemeData theme, String feature, dynamic free, dynamic pro,
      {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Feature Name
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          // Free Value
          Expanded(
            child: Center(child: _buildCellContent(free, theme, isPro: false)),
          ),
          // Pro Value
          Expanded(
            child: Center(child: _buildCellContent(pro, theme, isPro: true)),
          ),
        ],
      ),
    );
  }

  Widget _buildCellContent(dynamic value, ThemeData theme, {required bool isPro}) {
    if (value is bool) {
      return Icon(
        value ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
        color: value
            ? (isPro ? const Color(0xFF1565C0) : const Color(0xFF4CAF50))
            : theme.colorScheme.outlineVariant,
        size: 18,
      );
    } else if (value is String) {
      // "Sınırsız" veya "Yok" gibi özel vurgular
      final isPositive = value == "Sınırsız" || (isPro && value == "Yok");
      return Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isPro ? FontWeight.bold : FontWeight.normal,
          color: isPositive
              ? (isPro ? const Color(0xFF1565C0) : theme.colorScheme.onSurface)
              : theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return const SizedBox();
  }
}

