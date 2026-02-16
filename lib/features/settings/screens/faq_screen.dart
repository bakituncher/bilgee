// lib/features/settings/screens/faq_screen.dart
import 'package:flutter/material.dart';
import 'package:taktik/shared/widgets/custom_back_button.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final List<FAQItem> _faqItems = [
    // Ücretlendirme
    FAQItem(
      question: "Taktik neden ücretli?",
      answer:
          "Taktik, size özel bir yapay zeka koçu sunuyor. Genel AI araçlarının aksine, sizin sınav türünüze, hedeflerinize ve öğrenme tarzınıza özel olarak tasarlanmış bir deneyim yaşıyorsunuz. Her gün güncellenen kişisel planlamalar, sınava özel içerik üretimi, zayıf konu analizi gibi özellikler, standart uygulamaların çok ötesinde bir hizmet gerektiriyor.\n\nAyrıca, sürekli geliştirilen yapay zeka altyapımız, sunucu maliyetleri ve içerik üretimi ciddi yatırım gerektiriyor. Ücretli model sayesinde size en kaliteli ve sürdürülebilir hizmeti sunabiliyoruz.",
    ),
    FAQItem(
      question: "Bir özel ders yerine Taktik'i neden tercih etmeliyim?",
      answer:
          "Özel ders saati başına 500-2000₺ arasında değişiyor ve genelde haftada 1-2 saat ile sınırlı. Taktik ise 7/24 yanınızda, tüm dersler için destek veriyor ve her gün size özel plan hazırlıyor.\n\nZayıf konu analizi, soru çözümleri, içerik üretimi ve daha fazlası... Aylık maliyeti sadece 1-2 özel ders ücreti kadar. Yani aslında özel ders almaya devam ederken Taktik'i de kullanarak çok daha kapsamlı bir destek alıyorsunuz.",
    ),
    FAQItem(
      question: "Ücretsiz deneme süresi var mı?",
      answer:
          "Evet! Taktik'e kaydolduğunuzda PRO özelliklerimizi ücretsiz deneyebilirsiniz. Bu süre zarfında tüm yapay zeka araçlarına, kişisel koçluk özelliklerine ve içerik üretimine tam erişim sağlayabilirsiniz. Böylece Taktik'in size ne kadar değer katacağını kendiniz deneyimleyebilirsiniz.",
    ),
    FAQItem(
      question: "PRO iptali sonrası ne olur?",
      answer:
          "Aboneliğinizi iptal ettiğinizde, mevcut abonelik döneminizin sonuna kadar tüm PRO özellikleri kullanmaya devam edebilirsiniz. Abonelik döneminiz sona erdiğinde PRO özelliklere erişiminiz kısıtlanır. Test geçmişiniz ve performans verileriniz korunur. İstediğiniz zaman tekrar PRO'ya geçerek tüm özelliklere erişebilirsiniz.",
    ),
    FAQItem(
      question: "Öğrenci indirimi var mı?",
      answer:
          "Taktik zaten öğrenciler için geliştirilmiş bir platform! Fiyatlandırmamız, öğrencilerin bütçesine uygun ve alternatif eğitim hizmetlerine göre çok daha ekonomik olarak tasarlanmıştır. Ayrıca periyodik olarak kampanyalar düzenliyoruz.",
    ),
    FAQItem(
      question: "\"Sınırsız\" gerçekten sınırsız mı?",
      answer:
          "Adil Kullanım Kotası gereği sistem güvenliği için oldukça yüksek bir üst sınırımız var. Korkma! Bu sınıra ulaşmak neredeyse imkansız.\n\nEğer ulaşmayı başarırsan, sen bizim için bir \"Derece Öğrencisi\" adayısın demektir. Destek ekibimize ulaş, bu başarını kutlayalım ve hesabına hemen ücretsiz ek hak yükleyelim. Biz çalışanın her zaman yanındayız! 🏆",
    ),

    // Genel
    FAQItem(
      question: "Hangi sınavlar destekleniyor?",
      answer:
          "Taktik şu anda YKS, LGS, KPSS ve AGS sınavları için tam destek veriyor. Her sınav için özel içerikler, konu analizleri ve strateji önerileri bulunuyor.",
    ),
    FAQItem(
      question: "İnternet olmadan kullanabilir miyim?",
      answer:
          "Hayır. Taktik'in tüm özellikleri internet bağlantısı gerektirir çünkü yapay zeka destekli analiz ve içerik üretimi gerçek zamanlı olarak bulut üzerinde çalışır.",
    ),

    // AI Özellikleri
    FAQItem(
      question: "Taktik beni nasıl tanıyor?",
      answer:
          "Taktik, girdiğiniz test sonuçlarını, çalışma alışkanlıklarınızı ve hedeflerinizi analiz ederek size özel öneriler sunuyor. Her test sonucu, her sohbet ve her etkileşimle sizi daha iyi tanıyor. Güçlü ve zayıf konularınızı, çalışma ritminizi öğreniyor ve zamanla daha isabetli tavsiyelerde bulunuyor.",
    ),
    FAQItem(
      question: "Üretilen içeriklere güvenebilir miyim?",
      answer:
          "Taktik, gelişmiş yapay zeka modellerini sınav müfredatları ve akademik kaynaklarla destekleyerek çalışır. İçerikler düzenli olarak gözden geçirilir ve optimize edilir. Yine de AI'nın bir yardımcı araç olduğunu, ana kaynağınızın ders kitaplarınız ve öğretmenleriniz olması gerektiğini unutmayın.",
    ),

    FAQItem(
      question: "İstatistikler nasıl hesaplanıyor?",
      answer:
          "Taktik, tüm test sonuçlarınızı analiz ederek ders bazlı ortalamalarınızı, ilerleme grafiklerinizi, güçlü/zayıf konu dağılımınızı ve hedef karşılaştırmanızı gerçek zamanlı olarak hesaplıyor. Bu veriler AI koçunuzun size özel plan yapmasında kullanılıyor.",
    ),

    // Teknik
    FAQItem(
      question: "Verilerim güvende mi?",
      answer:
          "Tüm verileriniz güvenli sunucularda saklanır. Kişisel bilgileriniz hiçbir şekilde üçüncü şahıslarla paylaşılmaz.",
    ),
    FAQItem(
      question: "Hesabımı nasıl silebilirim?",
      answer:
          "Ayarlar > Tehlikeli Bölge > Hesabı Sil yoluyla hesabınızı tamamen silebilirsiniz. Bu işlem geri alınamaz ve tüm verileriniz kalıcı olarak silinir.",
    ),
    FAQItem(
      question: "Hangi cihazlarda çalışır?",
      answer:
          "Taktik; iOS 13.0 ve üzeri iPhone/iPad ve Silicon çipli Mac cihazlarda, Android 7.0 ve üzeri Android cihazlarda sorunsuz çalışır.",
    ),
  ];

  String _searchQuery = '';

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
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Ara...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
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
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
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

// Model
class FAQItem {
  final String question;
  final String answer;

  FAQItem({
    required this.question,
    required this.answer,
  });
}





