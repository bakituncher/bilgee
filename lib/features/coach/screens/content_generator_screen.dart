import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:taktik/features/coach/services/content_generator_service.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';

class ContentGeneratorScreen extends ConsumerStatefulWidget {
  const ContentGeneratorScreen({super.key});

  @override
  ConsumerState<ContentGeneratorScreen> createState() => _ContentGeneratorScreenState();
}

class _ContentGeneratorScreenState extends ConsumerState<ContentGeneratorScreen> {
  // Seçili dosya
  File? _selectedFile;
  String? _fileName;
  String? _mimeType;

  // Seçili içerik türü
  ContentType _selectedContentType = ContentType.infoCards;

  // State değişkenleri
  bool _isLoading = false;
  String? _error;
  GeneratedContent? _result;

  // Soru kartları için görünürlük kontrolü
  final Map<int, bool> _revealedAnswers = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPremium = ref.watch(premiumStatusProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'İçerik Üretici',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Yeniden Başla',
              onPressed: _reset,
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState(theme, isDark)
            : _result != null
                ? _buildResultState(theme, isDark)
                : _buildInitialState(theme, isDark, isPremium),
      ),
    );
  }

  /// Başlangıç ekranı - dosya seçimi ve içerik türü
  Widget _buildInitialState(ThemeData theme, bool isDark, bool isPremium) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve açıklama
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E3A5F), const Color(0xFF0D1B2A)]
                    : [const Color(0xFFE0F2FE), const Color(0xFFF0F9FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF0EA5E9),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PDF veya Görsel Yükle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Yapay zeka içeriğini analiz edip sana özel materyal üretsin.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),

          const SizedBox(height: 24),

          // Dosya seçim alanı
          Text(
            '1. Dosya Seç',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          _buildFileSelector(theme, isDark),

          const SizedBox(height: 28),

          // İçerik türü seçimi
          Text(
            '2. Ne Üreteyim?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          _buildContentTypeSelector(theme, isDark),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Üret butonu
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedFile != null ? _generateContent : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                disabledBackgroundColor: theme.colorScheme.onSurface.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'İçerik Üret',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _selectedFile != null ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
        ],
      ),
    );
  }

  /// Dosya seçici widget
  Widget _buildFileSelector(ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedFile != null
                ? const Color(0xFF0EA5E9).withOpacity(0.5)
                : theme.colorScheme.onSurface.withOpacity(0.1),
            width: _selectedFile != null ? 2 : 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: _selectedFile != null
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getFileIconColor().withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getFileIcon(),
                      color: _getFileIconColor(),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fileName ?? 'Dosya',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _mimeType?.split('/').last.toUpperCase() ?? 'DOSYA',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                        _fileName = null;
                        _mimeType = null;
                      });
                    },
                  ),
                ],
              )
            : Column(
                children: [
                  Icon(
                    Icons.cloud_upload_rounded,
                    size: 48,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Dosya seçmek için dokun',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PDF, PNG, JPG, WEBP',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  /// İçerik türü seçici
  Widget _buildContentTypeSelector(ThemeData theme, bool isDark) {
    return Column(
      children: ContentType.values.map((type) {
        final isSelected = _selectedContentType == type;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => setState(() => _selectedContentType = type),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0EA5E9).withOpacity(0.1)
                    : isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.grey.withOpacity(0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0EA5E9).withOpacity(0.5)
                      : theme.colorScheme.onSurface.withOpacity(0.08),
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    type.icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          _getContentTypeDescription(type),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0EA5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms);
  }

  String _getContentTypeDescription(ContentType type) {
    switch (type) {
      case ContentType.infoCards:
        return 'Konuyu öğrenmek için kartlar';
      case ContentType.questionCards:
        return 'Kendini test et';
      case ContentType.summary:
        return 'Hızlı tekrar için özet';
    }
  }

  /// Yükleniyor ekranı
  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/lotties/Brain.json',
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 24),
          Text(
            '${_selectedContentType.displayName} Üretiliyor...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yapay zeka içeriğini analiz ediyor',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// Sonuç ekranı
  Widget _buildResultState(ThemeData theme, bool isDark) {
    if (_result == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başarı göstergesi
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_result!.type.displayName} başarıyla oluşturuldu!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),

          const SizedBox(height: 24),

          // İçerik görüntüleme
          if (_result!.type == ContentType.summary)
            _buildSummaryView(theme, isDark)
          else
            _buildCardsView(theme, isDark),
        ],
      ),
    );
  }

  /// Özet görünümü
  Widget _buildSummaryView(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: MarkdownBody(
        data: _result!.summary ?? _result!.rawContent,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          h1: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            height: 1.4,
          ),
          h2: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
            height: 1.4,
          ),
          h3: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
            height: 1.4,
          ),
          p: TextStyle(
            fontSize: 15,
            height: 1.7,
            color: theme.colorScheme.onSurface.withOpacity(0.9),
          ),
          listBullet: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 15,
          ),
          listIndent: 20,
          strong: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
          em: TextStyle(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurface.withOpacity(0.85),
          ),
          blockquote: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.8),
            fontStyle: FontStyle.italic,
            fontSize: 14,
          ),
          blockquoteDecoration: BoxDecoration(
            color: const Color(0xFF0EA5E9).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: const Color(0xFF0EA5E9),
                width: 4,
              ),
            ),
          ),
          blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          codeblockDecoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          code: TextStyle(
            backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
            fontFamily: 'monospace',
            fontSize: 13,
            color: theme.colorScheme.onSurface,
          ),
        ),
        builders: {
          'latex': _LatexElementBuilder(
            textStyle: TextStyle(color: theme.colorScheme.onSurface),
          ),
        },
        extensionSet: md.ExtensionSet(
          [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
          [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, _LatexInlineSyntax()],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  /// Kartlar görünümü
  Widget _buildCardsView(ThemeData theme, bool isDark) {
    final cards = _result!.cards ?? [];

    if (cards.isEmpty) {
      return Center(
        child: Text(
          'Kart oluşturulamadı.',
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
        ),
      );
    }

    return Column(
      children: cards.asMap().entries.map((entry) {
        final index = entry.key;
        final card = entry.value;
        final isQuestion = _result!.type == ContentType.questionCards;
        final isRevealed = _revealedAnswers[index] ?? false;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kart başlığı
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          card.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Kart içeriği
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarkdownBody(
                        data: card.content,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: theme.colorScheme.onSurface.withOpacity(0.9),
                          ),
                          strong: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        builders: {
                          'latex': _LatexElementBuilder(
                            textStyle: TextStyle(color: theme.colorScheme.onSurface),
                          ),
                        },
                        extensionSet: md.ExtensionSet(
                          [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                          [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, _LatexInlineSyntax()],
                        ),
                      ),

                      // Soru kartları için ipucu ve cevap
                      if (isQuestion && card.hint != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'İpucu: ${card.hint}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (isQuestion && card.answer != null) ...[
                        const SizedBox(height: 12),
                        if (!isRevealed)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _revealedAnswers[index] = true;
                                });
                              },
                              icon: const Icon(Icons.visibility_rounded, size: 18),
                              label: const Text('Cevabı Göster'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0EA5E9),
                                side: const BorderSide(color: Color(0xFF0EA5E9)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Cevap',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                MarkdownBody(
                                  data: card.answer!,
                                  styleSheet: MarkdownStyleSheet(
                                    p: TextStyle(
                                      fontSize: 14,
                                      height: 1.6,
                                      color: theme.colorScheme.onSurface.withOpacity(0.9),
                                    ),
                                    strong: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  builders: {
                                    'latex': _LatexElementBuilder(
                                      textStyle: TextStyle(color: theme.colorScheme.onSurface),
                                    ),
                                  },
                                  extensionSet: md.ExtensionSet(
                                    [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                                    [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, _LatexInlineSyntax()],
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ).animate(delay: Duration(milliseconds: 100 * index)).fadeIn(duration: 400.ms).slideX(begin: 0.05, end: 0);
      }).toList(),
    );
  }

  // --- İşlevler ---

  /// Dosya seçimi
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.first.path;
      if (path == null) return;

      setState(() {
        _selectedFile = File(path);
        _fileName = result.files.first.name;
        _mimeType = ContentGeneratorService.getMimeType(path);
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Dosya seçilemedi: $e';
      });
    }
  }

  /// İçerik üretimi
  Future<void> _generateContent() async {
    if (_selectedFile == null || _mimeType == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Sınav türünü al
      final user = ref.read(userProfileProvider).value;
      final examType = user?.selectedExam;

      final service = ref.read(contentGeneratorServiceProvider);
      final result = await service.generateContent(
        file: _selectedFile!,
        contentType: _selectedContentType,
        mimeType: _mimeType!,
        examType: examType,
      );

      setState(() {
        _result = result;
        _isLoading = false;
        _revealedAnswers.clear();
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// Sıfırla
  void _reset() {
    setState(() {
      _selectedFile = null;
      _fileName = null;
      _mimeType = null;
      _result = null;
      _error = null;
      _revealedAnswers.clear();
    });
  }

  /// Dosya ikonu
  IconData _getFileIcon() {
    if (_mimeType == 'application/pdf') {
      return Icons.picture_as_pdf_rounded;
    }
    return Icons.image_rounded;
  }

  /// Dosya ikon rengi
  Color _getFileIconColor() {
    if (_mimeType == 'application/pdf') {
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
