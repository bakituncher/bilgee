// lib/core/safety/ai_content_safety.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI İçerik Güvenlik ve Uyarı Sistemi
/// Google Play ve App Store politikalarına uyum için
class AiContentSafety {
  static const String _acceptanceKey = 'ai_content_safety_accepted';
  static const String _acceptanceVersion = 'v1.0';

  /// Kullanıcı AI içerik kullanımını onaylamış mı?
  static Future<bool> hasUserAcceptedTerms() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getString(_acceptanceKey);
    return accepted == _acceptanceVersion;
  }

  /// Kullanıcı onayını kaydet
  static Future<void> recordUserAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_acceptanceKey, _acceptanceVersion);
  }

  /// Kullanıcı onayını sıfırla (test için)
  static Future<void> resetUserAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_acceptanceKey);
  }

  /// AI içerik güvenlik uyarısı göster - Modern ve Compact
  static Future<bool> showSafetyDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 620),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      colorScheme.surface,
                      colorScheme.surface.withOpacity(0.95),
                    ]
                  : [
                      Colors.white,
                      colorScheme.primaryContainer.withOpacity(0.05),
                    ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header - Compact ve şık
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer.withOpacity(0.3),
                      colorScheme.secondaryContainer.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI İçerik Kullanımı',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Önemli bilgilendirme',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content - Scrollable ve compact
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Compact info cards
                      _buildCompactInfoCard(
                        context,
                        icon: Icons.psychology_outlined,
                        title: 'AI Destekli',
                        description: 'İçerikler yapay zeka ile üretilir ve hatalı olabilir.',
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 10),
                      _buildCompactInfoCard(
                        context,
                        icon: Icons.shield_outlined,
                        title: '13+ Yaş',
                        description: 'Ebeveyn gözetimi önerilir.',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 10),
                      _buildCompactInfoCard(
                        context,
                        icon: Icons.health_and_safety_outlined,
                        title: 'Profesyonel Değil',
                        description: 'Tıbbi/psikolojik danışmanlık sunmaz.',
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 10),
                      _buildCompactInfoCard(
                        context,
                        icon: Icons.report_problem_outlined,
                        title: 'Sorun Bildir',
                        description: 'Uygunsuz içerik görürseniz bildirin.',
                        color: Colors.red,
                      ),

                      const SizedBox(height: 16),

                      // Compact disclaimer
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Devam ederek AI içeriğin sınırlamalarını kabul etmiş olursunuz.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  height: 1.3,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Actions - Compact ve modern
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Vazgeç'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text(
                          'Anladım, Kabul Ediyorum',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      await recordUserAcceptance();
      return true;
    }
    return false;
  }

  /// Compact bilgi kartı widget'ı - Modern tasarım
  static Widget _buildCompactInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    height: 1.3,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bilgi noktası widget'ı (eski stil - artık kullanılmıyor ama geriye dönük uyumluluk için bırakıldı)
  static Widget _buildInfoPoint(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// AI içerik disclaimer banner
  static Widget buildDisclaimerBanner(BuildContext context, {String? customMessage}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              customMessage ??
                  'Bu içerik yapay zeka tarafından üretilmiştir. Bilgilerin doğruluğu garanti edilmez.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.blue.shade900,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kompakt AI rozeti (ekranlara eklenecek)
  static Widget buildAiBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade100, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.shade200, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 14, color: Colors.purple.shade700),
          const SizedBox(width: 4),
          Text(
            'AI İçerik',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.purple.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// İçerik moderasyon fonksiyonu (basit kelime filtreleme)
  static bool containsInappropriateContent(String content) {
    final lowerContent = content.toLowerCase();

    // Yasaklı kelime listesi (temel seviye)
    final blockedWords = [
      // Şiddet içerikli
      'öldür', 'intihar', 'zarar ver',
      // Cinsel içerik
      'seks', 'porno', 'cinsel',
      // Nefret söylemi
      'ırk', 'din', 'etnik',
      // Diğer uygunsuz
      'kumar', 'alkol', 'uyuşturucu', 'silah',
    ];

    for (final word in blockedWords) {
      if (lowerContent.contains(word)) {
        return true;
      }
    }

    return false;
  }

  /// İçerik temizleme - hassas bilgileri maskeleme
  static String sanitizeContent(String content) {
    // Telefon numaralarını maskele
    var sanitized = content.replaceAllMapped(
      RegExp(r'\b(\d{3})\s*\d{3}\s*\d{2}\s*\d{2}\b'),
      (match) => '***-***-**-**',
    );

    // E-posta adreslerini maskele
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w{2,4}\b'),
      (match) => '***@***.***',
    );

    // TC kimlik numarası gibi 11 haneli sayıları maskele
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b\d{11}\b'),
      (match) => '***********',
    );

    return sanitized;
  }

  /// Güvenlik raporu widget'ı (ayarlar ekranına eklenecek)
  static Widget buildSafetyReportButton(BuildContext context, {required VoidCallback onTap}) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.report_problem, color: Colors.red.shade700),
      ),
      title: const Text('Uygunsuz İçerik Bildir'),
      subtitle: const Text('AI içeriğinde sorun tespit ettiyseniz bildirin'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}

