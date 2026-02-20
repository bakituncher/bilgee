import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/coach/models/saved_content_model.dart';
import 'package:taktik/features/coach/providers/saved_content_provider.dart';
import 'package:taktik/features/coach/widgets/flashcard_widget.dart';
import 'package:taktik/shared/widgets/custom_back_button.dart';

class SavedContentsScreen extends ConsumerStatefulWidget {
  const SavedContentsScreen({super.key});

  @override
  ConsumerState<SavedContentsScreen> createState() => _SavedContentsScreenState();
}

class _SavedContentsScreenState extends ConsumerState<SavedContentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final savedContents = ref.watch(savedContentProvider);
    final stats = ref.read(savedContentProvider.notifier).getStorageStats();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: CustomBackButton(
          onPressed: () {
            // İçerik üretici ekranına git
            context.go('/ai-hub/content-generator');
          },
        ),
        title: Text(
          'Kaydedilenler',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.secondaryBrandColor,
          unselectedLabelColor: colorScheme.onSurface.withOpacity(0.5),
          indicatorColor: AppTheme.secondaryBrandColor,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(text: 'Tümü (${stats['total']})'),
            Tab(text: 'Flashcard (${stats['flashcards']})'),
            Tab(text: 'Quiz (${stats['quizzes']})'),
            Tab(text: 'Özet (${stats['summaries']})'),
            Tab(text: 'Mnemonic (${stats['mnemonics']})'),
          ],
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildContentList(savedContents, null, theme, isDark),
            _buildContentList(
              savedContents.where((c) => c.type == SavedContentType.flashcard).toList(),
              SavedContentType.flashcard,
              theme,
              isDark,
            ),
            _buildContentList(
              savedContents.where((c) => c.type == SavedContentType.quiz).toList(),
              SavedContentType.quiz,
              theme,
              isDark,
            ),
            _buildContentList(
              savedContents.where((c) => c.type == SavedContentType.summary).toList(),
              SavedContentType.summary,
              theme,
              isDark,
            ),
            _buildContentList(
              savedContents.where((c) => c.type == SavedContentType.mnemonic).toList(),
              SavedContentType.mnemonic,
              theme,
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentList(
      List<SavedContentModel> contents,
      SavedContentType? type,
      ThemeData theme,
      bool isDark,
      ) {
    final colorScheme = theme.colorScheme;

    if (contents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_border_rounded,
                size: 48,
                color: colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz kayıt yok',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dönüştürücü ile oluşturduğun içerikleri\nburadan kaydedebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contents.length,
      itemBuilder: (context, index) {
        final content = contents[index];
        return _buildContentCard(content, index, theme, isDark);
      },
    );
  }

  Widget _buildContentCard(
      SavedContentModel content,
      int index,
      ThemeData theme,
      bool isDark,
      ) {
    final colorScheme = theme.colorScheme;
    final typeColor = _getTypeColor(content.type);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'tr_TR');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(content.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppTheme.accentBrandColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        confirmDismiss: (_) async {
          return await _showDeleteDialog();
        },
        onDismissed: (_) {
          ref.read(savedContentProvider.notifier).deleteContent(content);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('İçerik silindi'),
              backgroundColor: AppTheme.accentBrandColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: typeColor.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: typeColor.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showContentDetail(content),
              onLongPress: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.swipe_left_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        const Text('Silmek için sola kaydır'),
                      ],
                    ),
                    backgroundColor: AppTheme.secondaryBrandColor,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tür ikonu
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [typeColor, typeColor.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _getTypeIcon(content.type),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Bilgiler
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _getTypeName(content.type),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    dateFormat.format(content.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.onSurface.withOpacity(0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Ok ikonu
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onSurface.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: 50 * index))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.05, end: 0);
  }

  Color _getTypeColor(SavedContentType type) {
    switch (type) {
      case SavedContentType.flashcard:
        return const Color(0xFF6366F1);
      case SavedContentType.quiz:
        return AppTheme.secondaryBrandColor;
      case SavedContentType.summary:
        return const Color(0xFF8B5CF6);
      case SavedContentType.mnemonic:
        return const Color(0xFFFF6B9D);
    }
  }

  IconData _getTypeIcon(SavedContentType type) {
    switch (type) {
      case SavedContentType.flashcard:
        return Icons.style_rounded;
      case SavedContentType.quiz:
        return Icons.quiz_rounded;
      case SavedContentType.summary:
        return Icons.summarize_rounded;
      case SavedContentType.mnemonic:
        return Icons.psychology_rounded;
    }
  }

  String _getTypeName(SavedContentType type) {
    switch (type) {
      case SavedContentType.flashcard:
        return 'FLASHCARD';
      case SavedContentType.quiz:
        return 'QUIZ';
      case SavedContentType.summary:
        return 'ÖZET';
      case SavedContentType.mnemonic:
        return 'KODLAMA';
    }
  }

  Future<bool> _showDeleteDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('İçeriği Sil'),
        content: const Text('Bu içeriği silmek istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentBrandColor,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showContentDetail(SavedContentModel content) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _SavedContentDetailScreen(content: content),
      ),
    );
  }
}

/// Kaydedilen içerik detay ekranı - Flashcard, Quiz ve Özet için özel görünümler
class _SavedContentDetailScreen extends StatefulWidget {
  final SavedContentModel content;

  const _SavedContentDetailScreen({required this.content});

  @override
  State<_SavedContentDetailScreen> createState() => _SavedContentDetailScreenState();
}

class _SavedContentDetailScreenState extends State<_SavedContentDetailScreen> {
  // Quiz için seçili cevaplar
  final Map<int, int> _selectedAnswers = {};

  // Kartları parse et
  List<Map<String, dynamic>> _parseCards() {
    try {
      // Raw content'ten kartları parse etmeye çalış
      final content = widget.content.content;

      // JSON formatında mı kontrol et (yeni kaydetme formatı)
      if (content.trim().startsWith('[')) {
        final List<dynamic> parsed = jsonDecode(content);
        // Her bir item'ı Map<String, dynamic>'e dönüştür
        return parsed.map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return <String, dynamic>{};
        }).where((m) => m.isNotEmpty).toList();
      }

      // Eski format - Markdown formatından kartları çıkar
      final cards = <Map<String, dynamic>>[];
      final lines = content.split('\n');

      String? currentTitle;
      StringBuffer currentContent = StringBuffer();
      List<String>? currentOptions;
      int? correctIndex;
      String? currentAnswer;

      for (final line in lines) {
        // Kart başlığı - ## ile başlıyor
        if (line.startsWith('## ') || line.startsWith('### ')) {
          // Önceki kartı kaydet
          if (currentTitle != null) {
            cards.add({
              'title': currentTitle,
              'content': currentContent.toString().trim(),
              if (currentOptions != null) 'options': currentOptions,
              if (correctIndex != null) 'correctIndex': correctIndex,
              if (currentAnswer != null) 'answer': currentAnswer,
            });
          }
          currentTitle = line.replaceAll(RegExp(r'^#+\s*'), '').trim();
          currentContent = StringBuffer();
          currentOptions = null;
          correctIndex = null;
          currentAnswer = null;
        }
        // Seçenekler - A), B), C), D) formatında
        else if (RegExp(r'^[A-D]\)').hasMatch(line.trim())) {
          currentOptions ??= [];
          currentOptions.add(line.trim().substring(2).trim());
        }
        // Doğru cevap
        else if (line.contains('Doğru:') || line.contains('Cevap:')) {
          final answer = line.split(':').last.trim().toUpperCase();
          if (answer.isNotEmpty && answer.length == 1) {
            correctIndex = answer.codeUnitAt(0) - 65; // A=0, B=1, C=2, D=3
          }
          currentAnswer = line.split(':').last.trim();
        }
        // Normal içerik
        else if (currentTitle != null) {
          currentContent.writeln(line);
        }
      }

      // Son kartı kaydet
      if (currentTitle != null) {
        cards.add({
          'title': currentTitle,
          'content': currentContent.toString().trim(),
          if (currentOptions != null) 'options': currentOptions,
          if (correctIndex != null) 'correctIndex': correctIndex,
          if (currentAnswer != null) 'answer': currentAnswer,
        });
      }

      return cards;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final typeColor = _getTypeColor(widget.content.type);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: CustomBackButton(
          onPressed: () {
            // Navigator.push ile açıldığı için Navigator.pop kullan
            Navigator.of(context).pop();
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getTypeIcon(widget.content.type),
                color: typeColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.content.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: _buildContent(theme, isDark, typeColor, colorScheme),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark, Color typeColor, ColorScheme colorScheme) {
    switch (widget.content.type) {
      case SavedContentType.flashcard:
        return _buildFlashcardView(theme, isDark, typeColor, colorScheme);
      case SavedContentType.quiz:
        return _buildQuizView(theme, isDark, typeColor, colorScheme);
      case SavedContentType.summary:
        return _buildSummaryView(theme, isDark, typeColor, colorScheme);
      case SavedContentType.mnemonic:
        return _buildMnemonicView(theme, isDark, typeColor, colorScheme);
    }
  }

  /// Flashcard görünümü
  Widget _buildFlashcardView(ThemeData theme, bool isDark, Color typeColor, ColorScheme colorScheme) {
    final cards = _parseCards();

    if (cards.isEmpty) {
      // Fallback - Markdown olarak göster
      return _buildMarkdownView(theme, isDark, typeColor, colorScheme);
    }

    final cardColors = [
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFFEF4444),
    ];

    return Column(
      children: [
        // Üst bilgi
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.style_rounded, color: typeColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${cards.length} Flashcard',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: typeColor,
                  ),
                ),
                const Spacer(),
                Icon(Icons.touch_app_rounded, size: 16, color: colorScheme.onSurface.withOpacity(0.4)),
                const SizedBox(width: 4),
                Text(
                  'Dokunarak çevir',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Kartlar
        Expanded(
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.85),
            itemCount: cards.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final card = cards[index];
              final cardColor = cardColors[index % cardColors.length];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: FlashcardWidget(
                  index: index,
                  total: cards.length,
                  title: card['title'] ?? '',
                  content: card['content'] ?? '',
                  color: cardColor,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// Quiz görünümü
  Widget _buildQuizView(ThemeData theme, bool isDark, Color typeColor, ColorScheme colorScheme) {
    final cards = _parseCards();

    if (cards.isEmpty) {
      return _buildMarkdownView(theme, isDark, typeColor, colorScheme);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        // options'ı List<String>'e dönüştür
        final rawOptions = card['options'];
        final List<String> options = rawOptions != null
            ? (rawOptions as List).map((e) => e.toString()).toList()
            : [];
        final correctIndex = card['correctIndex'] as int?;
        final selectedAnswer = _selectedAnswers[index];
        final isAnswered = selectedAnswer != null;
        final isCorrect = isAnswered && selectedAnswer == correctIndex;

        final questionColor = isAnswered
            ? (isCorrect ? AppTheme.successBrandColor : AppTheme.accentBrandColor)
            : typeColor;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: questionColor.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Soru ${index + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: questionColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    card['title'] ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                // İçerik (varsa)
                if ((card['content'] as String?)?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MarkdownBody(
                      data: card['content'] ?? '',
                      shrinkWrap: true,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                // Şıklar
                if (options.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: options.asMap().entries.map((entry) {
                        final optIndex = entry.key;
                        final optText = entry.value;
                        final isSelected = selectedAnswer == optIndex;
                        final isCorrectOption = correctIndex == optIndex;
                        final optionLetter = String.fromCharCode(65 + optIndex);

                        Color bgColor = colorScheme.onSurface.withOpacity(0.03);
                        Color borderColor = colorScheme.onSurface.withOpacity(0.08);
                        Color letterBg = colorScheme.onSurface.withOpacity(0.08);
                        Color letterColor = colorScheme.onSurface.withOpacity(0.6);

                        if (isAnswered) {
                          if (isCorrectOption) {
                            bgColor = AppTheme.successBrandColor.withOpacity(0.08);
                            borderColor = AppTheme.successBrandColor.withOpacity(0.3);
                            letterBg = AppTheme.successBrandColor;
                            letterColor = Colors.white;
                          } else if (isSelected) {
                            bgColor = AppTheme.accentBrandColor.withOpacity(0.08);
                            borderColor = AppTheme.accentBrandColor.withOpacity(0.3);
                            letterBg = AppTheme.accentBrandColor;
                            letterColor = Colors.white;
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: isAnswered ? null : () {
                              setState(() {
                                _selectedAnswers[index] = optIndex;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor, width: 1.5),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
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
                                        color: colorScheme.onSurface.withOpacity(0.85),
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

                // İpucu (İstek üzerine eklenebilir)
                if (card['hint'] != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.goldBrandColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, color: AppTheme.goldBrandColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              card['hint'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Açıklama / Cevap (Cevaplandıktan sonra göster)
                if (isAnswered && card['answer'] != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.successBrandColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.successBrandColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppTheme.successBrandColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Açıklama',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.successBrandColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  card['answer'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: colorScheme.onSurface.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Özet görünümü
  Widget _buildSummaryView(ThemeData theme, bool isDark, Color typeColor, ColorScheme colorScheme) {
    return _buildMarkdownView(theme, isDark, typeColor, colorScheme);
  }

  /// Mnemonic görünümü
  Widget _buildMnemonicView(ThemeData theme, bool isDark, Color typeColor, ColorScheme colorScheme) {
    return _buildMarkdownView(theme, isDark, typeColor, colorScheme);
  }

  /// Markdown görünümü (fallback)
  Widget _buildMarkdownView(ThemeData theme, isDark, Color typeColor, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: MarkdownBody(
        data: widget.content.content,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          h1: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            height: 1.3,
          ),
          h2: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: typeColor,
            height: 1.4,
          ),
          h3: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withOpacity(0.9),
            height: 1.4,
          ),
          p: TextStyle(
            fontSize: 14,
            height: 1.7,
            color: colorScheme.onSurface.withOpacity(0.85),
          ),
          listBullet: TextStyle(
            color: typeColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          listIndent: 20,
          strong: TextStyle(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
          em: TextStyle(
            fontStyle: FontStyle.italic,
            color: colorScheme.onSurface.withOpacity(0.8),
          ),
          blockquoteDecoration: BoxDecoration(
            color: typeColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: typeColor, width: 4),
            ),
          ),
          blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          codeblockDecoration: BoxDecoration(
            color: colorScheme.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          codeblockPadding: const EdgeInsets.all(14),
          code: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(SavedContentType type) {
    switch (type) {
      case SavedContentType.flashcard:
        return const Color(0xFF6366F1);
      case SavedContentType.quiz:
        return AppTheme.secondaryBrandColor;
      case SavedContentType.summary:
        return const Color(0xFF8B5CF6);
      case SavedContentType.mnemonic:
        return const Color(0xFFFF6B9D);
    }
  }

  IconData _getTypeIcon(SavedContentType type) {
    switch (type) {
      case SavedContentType.flashcard:
        return Icons.style_rounded;
      case SavedContentType.quiz:
        return Icons.quiz_rounded;
      case SavedContentType.summary:
        return Icons.summarize_rounded;
      case SavedContentType.mnemonic:
        return Icons.psychology_rounded;
    }
  }
}
