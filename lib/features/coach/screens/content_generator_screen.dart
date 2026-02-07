import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:taktik/features/coach/services/content_generator_service.dart';
import 'package:taktik/features/coach/providers/content_generator_state_provider.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/core/theme/app_theme.dart';

class ContentGeneratorScreen extends ConsumerStatefulWidget {
  const ContentGeneratorScreen({super.key});

  @override
  ConsumerState<ContentGeneratorScreen> createState() => _ContentGeneratorScreenState();
}

class _ContentGeneratorScreenState extends ConsumerState<ContentGeneratorScreen> {
  // Çoklu görsel seçimi için maksimum limit
  static const int _maxCapturedImages = 5;

  // Image picker
  final ImagePicker _picker = ImagePicker();

  // Provider notifier getter
  ContentGeneratorNotifier get _notifier => ref.read(contentGeneratorStateProvider.notifier);

  @override
  Widget build(BuildContext context) {
    // Provider'ı watch et - değişikliklerde rebuild olsun
    final state = ref.watch(contentGeneratorStateProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPremium = ref.watch(premiumStatusProvider);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
              color: colorScheme.onSurface,
              size: 16,
            ),
          ),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/bunnyy.png',
              width: 26,
              height: 26,
              errorBuilder: (_, __, ___) => Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.secondaryBrandColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'İçerik Üretici',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (state.result != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryBrandColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add_rounded,
                    color: AppTheme.secondaryBrandColor,
                    size: 18,
                  ),
                ),
                tooltip: 'Yeni İçerik',
                onPressed: _createNewContent,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: state.isLoading
            ? _buildLoadingState(theme, isDark)
            : state.result != null
                ? _buildResultState(theme, isDark)
                : _buildInitialState(theme, isDark, isPremium),
      ),
    );
  }

  /// Başlangıç ekranı - dosya seçimi ve içerik türü
  Widget _buildInitialState(ThemeData theme, bool isDark, bool isPremium) {
    final state = ref.watch(contentGeneratorStateProvider);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Card - Taktik Tavşan tanıtımı
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppTheme.primaryBrandColor, const Color(0xFF1E293B)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.secondaryBrandColor.withOpacity(isDark ? 0.2 : 0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Tavşan emoji/avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryBrandColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/bunnyy.png',
                      width: 40,
                      height: 40,
                      errorBuilder: (_, __, ___) => Text(
                        '🐰',
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Taktik Tavşan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryBrandColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'AI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dosyanı yükle, sana özel içerik üreteyim!',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withOpacity(0.6),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),

          const SizedBox(height: 28),

          // Dosya Yükleme Alanı
          _buildFileSelector(theme, isDark),

          const SizedBox(height: 24),

          // İçerik Türü Başlığı
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'İçerik Türü',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withOpacity(0.5),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // İçerik türü seçici
          _buildContentTypeSelector(theme, isDark),

          // Hata mesajı
          if (state.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentBrandColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                    color: AppTheme.accentBrandColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: AppTheme.accentBrandColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().shake(hz: 2, offset: const Offset(2, 0)),
          ],

          const SizedBox(height: 32),

          // Üret butonu - Gradient style
          Builder(
            builder: (context) {
              final hasContent = state.selectedFile != null || state.capturedImages.isNotEmpty;

              return Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: hasContent
                      ? LinearGradient(
                          colors: [
                            AppTheme.secondaryBrandColor,
                            AppTheme.secondaryBrandColor.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: !hasContent ? colorScheme.onSurface.withOpacity(0.08) : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: hasContent
                      ? [
                          BoxShadow(
                            color: AppTheme.secondaryBrandColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: hasContent ? _generateContent : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 22,
                          color: hasContent
                              ? Colors.black
                              : colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          state.capturedImages.isNotEmpty
                              ? '${state.capturedImages.length} Sayfadan Üret'
                              : 'İçerik Üret',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: hasContent
                                ? Colors.black
                                : colorScheme.onSurface.withOpacity(0.3),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Dosya seçici widget
  Widget _buildFileSelector(ThemeData theme, bool isDark) {
    final state = ref.watch(contentGeneratorStateProvider);
    final colorScheme = theme.colorScheme;
    final hasFile = state.selectedFile != null || state.capturedImages.isNotEmpty;
    final fileCount = state.capturedImages.isNotEmpty ? state.capturedImages.length : (state.selectedFile != null ? 1 : 0);

    return GestureDetector(
      onTap: hasFile ? null : _showUploadOptions,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: hasFile
            ? const EdgeInsets.all(16)
            : const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: hasFile
              ? (isDark ? AppTheme.secondaryBrandColor.withOpacity(0.08) : AppTheme.secondaryBrandColor.withOpacity(0.05))
              : (isDark ? Colors.white.withOpacity(0.03) : colorScheme.onSurface.withOpacity(0.02)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile
                ? AppTheme.secondaryBrandColor.withOpacity(0.3)
                : colorScheme.onSurface.withOpacity(0.08),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: hasFile
            ? _buildSelectedFileContent(colorScheme, fileCount)
            : _buildEmptyFileSelector(colorScheme),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  /// Dosya seçildikten sonraki görünüm
  Widget _buildSelectedFileContent(ColorScheme colorScheme, int fileCount) {
    final state = ref.watch(contentGeneratorStateProvider);
    final isCaptured = state.capturedImages.isNotEmpty;

    return Row(
      children: [
        // Dosya ikonu veya önizleme
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _getFileIconColor(state.mimeType).withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: isCaptured && state.capturedImages.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    state.capturedImages.first,
                    fit: BoxFit.cover,
                  ),
                )
              : Icon(
                  _getFileIcon(state.mimeType),
                  color: _getFileIconColor(state.mimeType),
                  size: 26,
                ),
        ),
        const SizedBox(width: 14),
        // Dosya bilgileri
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCaptured
                    ? '$fileCount Sayfa Çekildi'
                    : state.fileName ?? 'Dosya',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getFileIconColor(state.mimeType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCaptured ? Icons.photo_library_rounded : Icons.insert_drive_file_rounded,
                          size: 12,
                          color: _getFileIconColor(state.mimeType),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCaptured ? 'GÖRSEL' : state.mimeType?.split('/').last.toUpperCase() ?? 'DOSYA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _getFileIconColor(state.mimeType),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppTheme.successBrandColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Hazır',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.successBrandColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Kaldır butonu
        _buildActionButton(
          icon: Icons.close_rounded,
          onTap: _clearSelection,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  /// Boş dosya seçici görünümü
  Widget _buildEmptyFileSelector(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // İkon container
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.secondaryBrandColor.withOpacity(0.12),
                AppTheme.secondaryBrandColor.withOpacity(0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.secondaryBrandColor.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.add_photo_alternate_rounded,
            size: 32,
            color: AppTheme.secondaryBrandColor,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'İçerik Yükle',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kamera ile çek veya dosyalardan seç',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 14,
              color: AppTheme.secondaryBrandColor.withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Text(
              'Dokunarak başla',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryBrandColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Aksiyon butonu (kaldır, düzenle vb.)
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: colorScheme.onSurface.withOpacity(0.5),
          size: 20,
        ),
      ),
    );
  }

  /// İçerik türü seçici
  Widget _buildContentTypeSelector(ThemeData theme, bool isDark) {
    final state = ref.watch(contentGeneratorStateProvider);
    final colorScheme = theme.colorScheme;

    return Row(
      children: ContentType.values.map((type) {
        final isSelected = state.selectedContentType == type;
        final index = ContentType.values.indexOf(type);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index > 0 ? 6 : 0,
              right: index < ContentType.values.length - 1 ? 6 : 0,
            ),
            child: GestureDetector(
              onTap: () => _notifier.setContentType(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            AppTheme.secondaryBrandColor.withOpacity(0.15),
                            AppTheme.secondaryBrandColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: isSelected ? null : colorScheme.onSurface.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.secondaryBrandColor.withOpacity(0.4)
                        : colorScheme.onSurface.withOpacity(0.06),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.secondaryBrandColor.withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    // İkon container
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.secondaryBrandColor.withOpacity(0.15)
                            : colorScheme.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getContentTypeIcon(type),
                        size: 22,
                        color: isSelected
                            ? AppTheme.secondaryBrandColor
                            : colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _getContentTypeShortName(type),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.secondaryBrandColor
                            : colorScheme.onSurface.withOpacity(0.6),
                        letterSpacing: isSelected ? 0.3 : 0,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: 24,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryBrandColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms);
  }

  /// İçerik türüne göre ikon döndürür
  IconData _getContentTypeIcon(ContentType type) {
    switch (type) {
      case ContentType.infoCards:
        return Icons.style_rounded;
      case ContentType.questionCards:
        return Icons.quiz_rounded;
      case ContentType.summary:
        return Icons.summarize_rounded;
    }
  }

  String _getContentTypeShortName(ContentType type) {
    switch (type) {
      case ContentType.infoCards:
        return 'Bilgi';
      case ContentType.questionCards:
        return 'Test';
      case ContentType.summary:
        return 'Özet';
    }
  }

  String _getContentTypeDescription(ContentType type) {
    switch (type) {
      case ContentType.infoCards:
        return 'Konuyu öğrenmek için kartlar';
      case ContentType.questionCards:
        return 'Çoktan seçmeli test';
      case ContentType.summary:
        return 'Hızlı tekrar için özet';
    }
  }

  /// Yükleniyor ekranı
  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    final state = ref.watch(contentGeneratorStateProvider);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Tavşan avatar ile animasyon
          Stack(
            alignment: Alignment.center,
            children: [
              // Dış halka animasyonu
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.secondaryBrandColor.withOpacity(0.15),
                    width: 3,
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat())
                  .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1000.ms)
                  .then()
                  .scale(begin: const Offset(1.05, 1.05), end: const Offset(0.95, 0.95), duration: 1000.ms),
              // İç container
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryBrandColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/bunnyy.png',
                    width: 60,
                    height: 60,
                    errorBuilder: (_, __, ___) => Text(
                      '🐰',
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 1500.ms, color: AppTheme.secondaryBrandColor.withOpacity(0.3)),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Taktik Tavşan Çalışıyor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getContentTypeIcon(state.selectedContentType),
                size: 18,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Text(
                '${state.selectedContentType.displayName} üretiliyor',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 20,
                child: Text(
                  '...',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ).animate(onPlay: (c) => c.repeat())
                    .fadeIn(duration: 600.ms)
                    .then()
                    .fadeOut(duration: 600.ms),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sonuç ekranı
  Widget _buildResultState(ThemeData theme, bool isDark) {
    final state = ref.watch(contentGeneratorStateProvider);
    if (state.result == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // İçerik görüntüleme
          if (state.result!.type == ContentType.summary)
            _buildSummaryView(theme, isDark)
          else if (state.result!.type == ContentType.questionCards)
            _buildQuizView(theme, isDark)
          else
            _buildCardsView(theme, isDark),
        ],
      ),
    );
  }

  /// Quiz görünümü (çoktan seçmeli test) - Sektör seviyesi tasarım
  Widget _buildQuizView(ThemeData theme, bool isDark) {
    final state = ref.watch(contentGeneratorStateProvider);
    final cards = state.result!.cards ?? [];
    final colorScheme = theme.colorScheme;

    if (cards.isEmpty) {
      return Center(
        child: Text(
          'Soru oluşturulamadı.',
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
        ),
      );
    }

    // İlerleme hesapla
    final answeredCount = state.selectedAnswers.length;
    final correctCount = state.selectedAnswers.entries
        .where((e) => cards.length > e.key && cards[e.key].correctIndex == e.value)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Üst başlık ve ilerleme
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.secondaryBrandColor.withOpacity(0.12),
                AppTheme.secondaryBrandColor.withOpacity(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryBrandColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.quiz_rounded,
                      color: AppTheme.secondaryBrandColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${cards.length} Test Sorusu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Şıklara tıklayarak cevapla',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (answeredCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.successBrandColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$correctCount/$answeredCount doğru',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.successBrandColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // İlerleme çubuğu
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: answeredCount / cards.length,
                  backgroundColor: colorScheme.onSurface.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(AppTheme.secondaryBrandColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 20),

        // Sorular
        ...cards.asMap().entries.map((entry) {
          final index = entry.key;
          final card = entry.value;
          final selectedAnswer = state.selectedAnswers[index];
          final isAnswered = selectedAnswer != null;
          final hasOptions = card.options != null && card.options!.isNotEmpty;

          if (!hasOptions) {
            return _buildOldQuestionCard(theme, isDark, index, card);
          }

          final isCorrect = isAnswered && selectedAnswer == card.correctIndex;

          // Soru rengi
          final questionColor = isAnswered
              ? (isCorrect ? AppTheme.successBrandColor : AppTheme.accentBrandColor)
              : AppTheme.secondaryBrandColor;

          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: questionColor.withOpacity(isAnswered ? 0.1 : 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Soru header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          questionColor.withOpacity(0.12),
                          questionColor.withOpacity(0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: questionColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Soru ${index + 1}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: questionColor,
                            ),
                          ),
                        ),
                        if (isAnswered)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isCorrect ? AppTheme.successBrandColor : AppTheme.accentBrandColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isCorrect ? Icons.check_rounded : Icons.close_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isCorrect ? 'Doğru' : 'Yanlış',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Soru metni
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      card.content,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),

                  // Şıklar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: card.options!.asMap().entries.map((optEntry) {
                        final optIndex = optEntry.key;
                        final optText = optEntry.value;
                        final isSelected = selectedAnswer == optIndex;
                        final isCorrectOption = card.correctIndex == optIndex;
                        final optionLetter = String.fromCharCode(65 + optIndex);

                        Color bgColor = colorScheme.onSurface.withOpacity(0.03);
                        Color borderColor = colorScheme.onSurface.withOpacity(0.08);
                        Color letterBg = colorScheme.onSurface.withOpacity(0.08);
                        Color letterColor = colorScheme.onSurface.withOpacity(0.6);
                        Color textColor = colorScheme.onSurface.withOpacity(0.85);

                        if (isAnswered) {
                          if (isCorrectOption) {
                            bgColor = AppTheme.successBrandColor.withOpacity(0.08);
                            borderColor = AppTheme.successBrandColor.withOpacity(0.3);
                            letterBg = AppTheme.successBrandColor;
                            letterColor = Colors.white;
                            textColor = AppTheme.successBrandColor;
                          } else if (isSelected) {
                            bgColor = AppTheme.accentBrandColor.withOpacity(0.08);
                            borderColor = AppTheme.accentBrandColor.withOpacity(0.3);
                            letterBg = AppTheme.accentBrandColor;
                            letterColor = Colors.white;
                            textColor = AppTheme.accentBrandColor;
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: isAnswered ? null : () {
                              _notifier.setSelectedAnswer(index, optIndex);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: letterBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: isAnswered && (isCorrectOption || isSelected)
                                          ? Icon(
                                              isCorrectOption ? Icons.check_rounded : Icons.close_rounded,
                                              color: letterColor,
                                              size: 18,
                                            )
                                          : Text(
                                              optionLetter,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: letterColor,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      optText,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                        color: textColor,
                                        fontWeight: isAnswered && isCorrectOption
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Açıklama
                  if (isAnswered && card.answer != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryBrandColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.secondaryBrandColor.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryBrandColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.lightbulb_rounded,
                              color: AppTheme.secondaryBrandColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Açıklama',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.secondaryBrandColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  card.answer!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: colorScheme.onSurface.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
                ],
              ),
            ),
          ).animate(delay: Duration(milliseconds: 80 * index)).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
        }),
      ],
    );
  }

  /// Eski format soru kartı (şıksız)
  Widget _buildOldQuestionCard(ThemeData theme, bool isDark, int index, ContentCard card) {
    final state = ref.watch(contentGeneratorStateProvider);
    final isRevealed = state.revealedAnswers[index] ?? false;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.onSurface.withOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryBrandColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Soru ${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.secondaryBrandColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    card.content,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (card.hint != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.goldBrandColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, color: AppTheme.goldBrandColor, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              card.hint!,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (card.answer != null) ...[
                    const SizedBox(height: 12),
                    if (!isRevealed)
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            _notifier.toggleRevealedAnswer(index, true);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.secondaryBrandColor,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('Cevabı Göster'),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.successBrandColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppTheme.successBrandColor, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                card.answer!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 80 * index)).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
  }

  /// Özet görünümü - Sektör seviyesi tasarım
  Widget _buildSummaryView(ThemeData theme, bool isDark) {
    final state = ref.watch(contentGeneratorStateProvider);
    final colorScheme = theme.colorScheme;
    final summaryText = state.result!.summary ?? state.result!.rawContent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Üst başlık
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF8B5CF6).withOpacity(0.15),
                const Color(0xFF8B5CF6).withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.article_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Konu Özeti',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'İçerik analiz edildi ve özetlendi',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: const Color(0xFF8B5CF6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI Özet',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 16),

        // Özet içeriği
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: MarkdownBody(
            data: summaryText,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              // Ana başlık
              h1: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                height: 1.3,
                letterSpacing: -0.5,
              ),
              h1Padding: const EdgeInsets.only(bottom: 16, top: 8),

              // Alt başlık
              h2: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8B5CF6),
                height: 1.4,
              ),
              h2Padding: const EdgeInsets.only(bottom: 10, top: 20),

              // Küçük başlık
              h3: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.9),
                height: 1.4,
              ),
              h3Padding: const EdgeInsets.only(bottom: 8, top: 16),

              // Paragraf
              p: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: colorScheme.onSurface.withOpacity(0.85),
              ),
              pPadding: const EdgeInsets.only(bottom: 12),

              // Liste maddeleri
              listBullet: const TextStyle(
                color: Color(0xFF8B5CF6),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              listIndent: 20,
              listBulletPadding: const EdgeInsets.only(right: 8),

              // Kalın metin
              strong: TextStyle(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),

              // İtalik metin
              em: TextStyle(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurface.withOpacity(0.8),
              ),

              // Alıntı bloğu
              blockquote: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.75),
                fontStyle: FontStyle.italic,
                fontSize: 13,
                height: 1.6,
              ),
              blockquoteDecoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(
                    color: Color(0xFF8B5CF6),
                    width: 4,
                  ),
                ),
              ),
              blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

              // Yatay çizgi
              horizontalRuleDecoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.onSurface.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),

              // Kod bloğu
              codeblockDecoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              codeblockPadding: const EdgeInsets.all(14),
              code: TextStyle(
                backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                fontFamily: 'monospace',
                fontSize: 12,
                color: colorScheme.onSurface,
              ),

          // Tablo
          tableBorder: TableBorder.all(
            color: colorScheme.onSurface.withOpacity(0.1),
            width: 1,
          ),
          tableHead: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          tableBody: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.85),
          ),
          tableCellsPadding: const EdgeInsets.all(10),
            ),
            builders: {
              'latex': _LatexElementBuilder(
                textStyle: TextStyle(color: colorScheme.onSurface),
              ),
            },
            extensionSet: md.ExtensionSet(
              [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
              [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, _LatexInlineSyntax()],
            ),
          ),
        ).animate().fadeIn(delay: 150.ms, duration: 350.ms),
      ],
    );
  }

  /// Kartlar görünümü (Bilgi kartları için) - Sektör seviyesi tasarım
  Widget _buildCardsView(ThemeData theme, bool isDark) {
    final state = ref.watch(contentGeneratorStateProvider);
    final cards = state.result!.cards ?? [];
    final colorScheme = theme.colorScheme;

    if (cards.isEmpty) {
      return Center(
        child: Text(
          'Kart oluşturulamadı.',
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
        ),
      );
    }

    // Kartlar için renk paleti
    final cardColors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFFEC4899), // Pink
      const Color(0xFF14B8A6), // Teal
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Emerald
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEF4444), // Red
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Üst başlık alanı
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryBrandColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.style_rounded,
                  color: AppTheme.secondaryBrandColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cards.length} Bilgi Kartı',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Yatay kaydırarak kartları incele',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Swipe ikonu
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swipe_rounded,
                      size: 14,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Kaydır',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Kartlar - Tam genişlik PageView
        SizedBox(
          height: 420,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.88),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              final cardColor = cardColors[index % cardColors.length];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: cardColor.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kart üst kısım - Gradient header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              cardColor,
                              cardColor.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Üst satır - numara ve sayfa
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Kart numarası
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Kart ${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Sayfa göstergesi
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${index + 1} / ${cards.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Başlık
                            Text(
                              card.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.3,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Kart içeriği
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          physics: const BouncingScrollPhysics(),
                          child: MarkdownBody(
                            data: card.content,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                fontSize: 15,
                                height: 1.7,
                                color: colorScheme.onSurface.withOpacity(0.85),
                              ),
                              strong: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cardColor,
                              ),
                              listBullet: TextStyle(
                                color: cardColor,
                                fontWeight: FontWeight.w600,
                              ),
                              listIndent: 16,
                              h3: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            builders: {
                              'latex': _LatexElementBuilder(
                                textStyle: TextStyle(color: colorScheme.onSurface),
                              ),
                            },
                            extensionSet: md.ExtensionSet(
                              [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                              [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, _LatexInlineSyntax()],
                            ),
                          ),
                        ),
                      ),

                      // Alt kısım - mini indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withOpacity(0.03),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            cards.length,
                            (i) => Container(
                              width: i == index ? 20 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: i == index
                                    ? cardColor
                                    : colorScheme.onSurface.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
      ],
    );
  }


  // --- İşlevler ---

  /// Yükleme seçeneklerini gösteren bottom sheet
  void _showUploadOptions() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Başlık
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryBrandColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_rounded,
                    color: AppTheme.secondaryBrandColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İçerik Yükle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kamera ile çek veya dosyalardan seç',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Seçenekler
            Row(
              children: [
                // Kamera seçeneği
                Expanded(
                  child: _buildUploadOptionCard(
                    icon: Icons.camera_alt_rounded,
                    title: 'Kamera',
                    subtitle: '5 sayfaya kadar',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _showCameraOptions();
                    },
                    colorScheme: colorScheme,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                // Dosya seçeneği
                Expanded(
                  child: _buildUploadOptionCard(
                    icon: Icons.folder_rounded,
                    title: 'Dosyalar',
                    subtitle: 'PDF, PNG, JPG',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _pickFromFiles();
                    },
                    colorScheme: colorScheme,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Yükleme seçeneği kartı
  Widget _buildUploadOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kamera seçeneklerini gösteren bottom sheet
  void _showCameraOptions() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Başlık
            Text(
              'Kaç Sayfa Çekmek İstersin?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Birden fazla sayfa çekersen AI tümünü birleştirir',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),

            const SizedBox(height: 24),

            // Tek sayfa seçeneği
            _buildCameraOptionTile(
              icon: Icons.looks_one_rounded,
              title: 'Tek Sayfa',
              subtitle: 'Hızlı tarama',
              onTap: () {
                Navigator.pop(context);
                _captureImage();
              },
              colorScheme: colorScheme,
              isDark: isDark,
            ),

            const SizedBox(height: 12),

            // Çoklu sayfa seçeneği
            _buildCameraOptionTile(
              icon: Icons.auto_awesome_motion_rounded,
              title: 'Çoklu Sayfa',
              subtitle: '5 sayfaya kadar çek ve birleştir',
              onTap: () {
                Navigator.pop(context);
                _startMultiPageCapture();
              },
              colorScheme: colorScheme,
              isDark: isDark,
              isPrimary: true,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Kamera seçeneği tile'ı
  Widget _buildCameraOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required bool isDark,
    bool isPrimary = false,
  }) {
    final color = isPrimary ? AppTheme.secondaryBrandColor : colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isPrimary
                ? AppTheme.secondaryBrandColor.withOpacity(isDark ? 0.15 : 0.08)
                : colorScheme.onSurface.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? AppTheme.secondaryBrandColor.withOpacity(0.3)
                  : colorScheme.onSurface.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color.withOpacity(isPrimary ? 1 : 0.7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tek görsel çekme
  Future<void> _captureImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        _notifier.setSelectedFile(
          File(image.path),
          'Kamera Görseli',
          ContentGeneratorService.getMimeType(image.path),
        );
      }
    } catch (e) {
      _notifier.setError('Görsel çekilemedi: $e');
    }
  }

  /// Çoklu sayfa çekme başlat
  Future<void> _startMultiPageCapture() async {
    _notifier.clearSelection();
    await _captureNextPage();
  }

  /// Sonraki sayfayı çek
  Future<void> _captureNextPage() async {
    final currentImages = ref.read(contentGeneratorStateProvider).capturedImages;
    if (currentImages.length >= _maxCapturedImages) {
      _showMaxPagesReached();
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null && mounted) {
        _notifier.addCapturedImage(File(image.path));

        // Devam etmek isteyip istemediğini sor
        final updatedImages = ref.read(contentGeneratorStateProvider).capturedImages;
        if (updatedImages.length < _maxCapturedImages && mounted) {
          _showContinueCaptureDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        _notifier.setError('Görsel çekilemedi: $e');
      }
    }
  }

  /// Devam etmek isteyip istemediğini soran dialog
  void _showContinueCaptureDialog() {
    if (!mounted) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentState = ref.read(contentGeneratorStateProvider);
    final remaining = _maxCapturedImages - currentState.capturedImages.length;
    final capturedCount = currentState.capturedImages.length;

    // Güvenli kopya oluştur
    final imagesCopy = List<File>.from(currentState.capturedImages);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık satırı
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.successBrandColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.successBrandColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$capturedCount. Sayfa Eklendi',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$remaining sayfa daha ekleyebilirsin',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Önizleme görselleri - yatay kaydırılabilir
              if (imagesCopy.isNotEmpty)
                SizedBox(
                  height: 70,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: imagesCopy.map((file) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.successBrandColor.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                file,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.image_rounded,
                                    size: 24,
                                    color: colorScheme.onSurface.withOpacity(0.3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: colorScheme.onSurface.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        'Tamamla',
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        // Kısa gecikme ile kamera aç
                        Future.delayed(const Duration(milliseconds: 200), () {
                          if (mounted) _captureNextPage();
                        });
                      },
                      icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                      label: const Text('Devam Et'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryBrandColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Maksimum sayfa sayısına ulaşıldı
  void _showMaxPagesReached() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Maksimum 5 sayfa ekleyebilirsiniz.'),
            ),
          ],
        ),
        backgroundColor: AppTheme.secondaryBrandColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Dosyalardan seç
  Future<void> _pickFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.first.path;
      if (path == null) return;

      _notifier.setSelectedFile(
        File(path),
        result.files.first.name,
        ContentGeneratorService.getMimeType(path),
      );
    } catch (e) {
      _notifier.setError('Dosya seçilemedi: $e');
    }
  }

  /// Seçimi temizle
  void _clearSelection() {
    _notifier.clearSelection();
  }

  /// İçerik üretimi
  Future<void> _generateContent() async {
    final state = ref.read(contentGeneratorStateProvider);
    // En az bir dosya veya görsel olmalı
    if (state.selectedFile == null && state.capturedImages.isEmpty) return;

    _notifier.setLoading(true);
    _notifier.setError(null);

    try {
      // Sınav türünü al
      final user = ref.read(userProfileProvider).value;
      final examType = user?.selectedExam;

      final service = ref.read(contentGeneratorServiceProvider);
      GeneratedContent result;

      if (state.capturedImages.isNotEmpty) {
        // Çoklu görsel ile içerik üret
        result = await service.generateContentFromMultipleImages(
          files: state.capturedImages,
          contentType: state.selectedContentType,
          examType: examType,
        );
      } else {
        // Tekli dosya ile içerik üret
        result = await service.generateContent(
          file: state.selectedFile!,
          contentType: state.selectedContentType,
          mimeType: state.mimeType!,
          examType: examType,
        );
      }

      _notifier.setResult(result);
    } catch (e) {
      _notifier.setError(e.toString().replaceAll('Exception: ', ''));
      _notifier.setLoading(false);
    }
  }

  /// Sıfırla
  void _reset() {
    _notifier.reset();
  }

  /// Yeni içerik oluştur - dosyayı koru
  void _createNewContent() {
    _notifier.clearResult();
  }

  /// Dosya ikonu
  IconData _getFileIcon(String? mimeType) {
    if (mimeType == 'application/pdf') {
      return Icons.picture_as_pdf_rounded;
    }
    return Icons.image_rounded;
  }

  /// Dosya ikon rengi
  Color _getFileIconColor(String? mimeType) {
    if (mimeType == 'application/pdf') {
      return Colors.red;
    }
    return Colors.blue;
  }
}

// --- LaTeX Syntax Sınıfları ---

/// LaTeX inline syntax parser - $...$ ve $$...$$ formatlarını yakalar
class _LatexInlineSyntax extends md.InlineSyntax {
  _LatexInlineSyntax() : super(r'(\$\$[\s\S]*?\$\$)|(\$[^$]*\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final match0 = match.group(0)!;
    final isDisplay = match0.startsWith(r'$$');
    final raw = isDisplay
        ? match0.substring(2, match0.length - 2)
        : match0.substring(1, match0.length - 1);
    final el = md.Element.text('latex', raw);
    el.attributes['mathStyle'] = isDisplay ? 'display' : 'text';
    parser.addNode(el);
    return true;
  }
}

/// LaTeX element builder - matematik ifadelerini render eder
class _LatexElementBuilder extends MarkdownElementBuilder {
  final TextStyle? textStyle;
  _LatexElementBuilder({this.textStyle});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final bool isDisplay = element.attributes['mathStyle'] == 'display';
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: isDisplay ? Alignment.center : Alignment.centerLeft,
      child: Math.tex(
        element.textContent,
        textStyle: textStyle ?? preferredStyle,
        mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
        onErrorFallback: (err) => Text(
          element.textContent,
          style: (textStyle ?? preferredStyle)?.copyWith(color: Colors.red),
        ),
      ),
    );
  }
}
