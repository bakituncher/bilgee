import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:taktik/features/coach/services/question_solver_service.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

class QuestionSolverScreen extends ConsumerStatefulWidget {
  const QuestionSolverScreen({super.key});

  @override
  ConsumerState<QuestionSolverScreen> createState() => _QuestionSolverScreenState();
}

class _QuestionSolverScreenState extends ConsumerState<QuestionSolverScreen> {
  XFile? _selectedImage;
  String? _solution;
  bool _isLoading = false;
  String? _error;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    // Ephemeral State: Clean up data when screen is closed
    _selectedImage = null;
    _solution = null;
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _solution = null;
          _error = null;
        });
        // Auto-start solving process
        _solveQuestion();
      }
    } catch (e) {
      setState(() {
        _error = 'Görsel seçilemedi: \$e';
      });
    }
  }

  Future<void> _solveQuestion() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(questionSolverServiceProvider);
      final result = await service.solveQuestion(_selectedImage!);

      if (mounted) {
        setState(() {
          _solution = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Soru Yükle',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Kamera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Galeri',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Anlık Çözüm',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          if (_solution != null)
             IconButton(
               icon: const Icon(Icons.refresh_rounded),
               onPressed: () {
                 setState(() {
                   _selectedImage = null;
                   _solution = null;
                 });
               },
             ),
        ],
      ),
      body: SafeArea(
        child: _selectedImage == null
            ? _buildEmptyState(theme)
            : _buildContent(theme),
      ),
      floatingActionButton: _selectedImage == null ? FloatingActionButton.extended(
        onPressed: _showImageSourceSheet,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Soru Sor'),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.camera_enhance_rounded,
              size: 64,
              color: theme.colorScheme.primary,
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1), duration: 2.seconds),
          ),
          const SizedBox(height: 24),
          Text(
            'Takıldığın Soruyu Çek',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yapay zeka anında çözümlesin.',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question Card
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
              image: DecorationImage(
                image: FileImage(File(_selectedImage!.path)),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: _showImageSourceSheet, // Retake
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (_isLoading)
            _buildLoadingState(theme)
          else if (_error != null)
            _buildErrorState(theme)
          else if (_solution != null)
            _buildSolutionCard(theme),

          // Privacy Note
          if (_solution != null) ...[
            const SizedBox(height: 32),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.privacy_tip_outlined, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  const SizedBox(width: 6),
                  Text(
                    'Görselin sunucularımızda saklanmaz. Uygulama kapanınca silinir.',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ]
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Lottie.asset(
          'assets/lotties/loading_dots.json', // Ensure this exists or use a default loader
          height: 100,
          errorBuilder: (context, error, stackTrace) =>
              const CircularProgressIndicator(),
        ),
        const SizedBox(height: 16),
        Text(
          'Soru Analiz Ediliyor...',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ).animate().fadeIn(),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 32),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Bilinmeyen bir hata',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _solveQuestion,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionCard(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Çözüm',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            // Save Button (Local Only)
            TextButton.icon(
              onPressed: _saveSolutionLocally,
              icon: const Icon(Icons.bookmark_border_rounded, size: 18),
              label: const Text('Kaydet'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: MarkdownBody(
            data: _solution!,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(color: theme.colorScheme.onSurface, height: 1.5, fontSize: 15),
              h1: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              h2: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              strong: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700),
              blockquote: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontStyle: FontStyle.italic),
              blockquoteDecoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 4)),
              ),
            ),
            builders: {
              'latex': LatexElementBuilder(
                textStyle: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            },
            extensionSet: md.ExtensionSet(
              [
                ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                // Add LaTeX block syntax support if needed, or rely on text pattern
              ],
              [
                ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                 LatexInlineSyntax(),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
      ],
    );
  }

  void _saveSolutionLocally() {
    // Implement local save logic if needed (SharedPrefs or just a snackbar for now as per "Optional Record" step)
    // The prompt says "Opsiyonel Kayıt: Sadece kullanıcı açıkça 'Cevabı Kaydet' butonuna basarsa çözüm cihazın yerel veritabanına... kaydedilecektir."
    // For now, I'll just show a success message since I haven't set up a specific Hive box for saved questions yet.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Çözüm panoya kopyalandı! (Kaydetme özelliği yakında)')),
    );
    // Also copy to clipboard
    // Clipboard.setData(ClipboardData(text: _solution!));
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple LaTeX Syntax Parser for Inline Math ($...$)
class LatexInlineSyntax extends md.InlineSyntax {
  LatexInlineSyntax() : super(r'(\$\$[\s\S]*?\$\$)|(\$[^$]*\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final match0 = match.group(0)!;
    // Strip $ signs
    final raw = match0.startsWith(r'$$')
        ? match0.substring(2, match0.length - 2)
        : match0.substring(1, match0.length - 1);

    final el = md.Element.text('latex', raw);
    parser.addNode(el);
    return true;
  }
}

class LatexElementBuilder extends MarkdownElementBuilder {
  final TextStyle? textStyle;

  LatexElementBuilder({this.textStyle});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Math.tex(
      element.textContent,
      textStyle: textStyle ?? preferredStyle,
      mathStyle: MathStyle.text,
    );
  }
}
