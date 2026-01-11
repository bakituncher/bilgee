import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taktik/features/coach/services/question_solver_service.dart';
import 'package:taktik/features/coach/services/saved_questions_service.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/shared/utils/markdown_latex_utils.dart';

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
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _selectedImage = null;
    _solution = null;
    super.dispose();
  }

  void _handleBack() {
    if (_selectedImage != null || _solution != null) {
      setState(() {
        _selectedImage = null;
        _solution = null;
        _error = null;
      });
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/ai-hub');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        // Crop Step
        final croppedFile = await _cropImage(File(image.path));

        if (croppedFile != null) {
          setState(() {
            _selectedImage = XFile(croppedFile.path);
            _solution = null;
            _error = null;
          });
          _solveQuestion();
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Görsel seçilemedi: $e';
      });
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    final theme = Theme.of(context);
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Soruyu Kırp',
          toolbarColor: theme.colorScheme.surface,
          toolbarWidgetColor: theme.colorScheme.onSurface,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          activeControlsWidgetColor: theme.colorScheme.primary,
        ),
        IOSUiSettings(
          title: 'Soruyu Kırp',
        ),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<void> _solveQuestion() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(questionSolverServiceProvider);
      final user = ref.read(userProfileProvider).value;
      final examType = user?.selectedExam;

      final result = await service.solveQuestion(_selectedImage!, examType: examType);

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

  Future<void> _saveSolutionLocally() async {
    if (_selectedImage == null || _solution == null) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(savedQuestionsServiceProvider).saveQuestion(
        imageFile: File(_selectedImage!.path),
        solutionMarkdown: _solution!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Soru arşivine kaydedildi!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            action: SnackBarAction(
              label: 'Görüntüle',
              textColor: Colors.white,
              onPressed: () => context.pushNamed('SavedQuestions'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedilemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

  void _openToolOffer() {
    context.pushNamed(
      'ToolOffer',
      extra: {
        'title': 'Sınırsız Soru Çözümü',
        'subtitle': 'Taktik Tavşan ile dilediğin kadar soru çözdür.',
        'icon': Icons.camera_enhance_rounded,
        'color': const Color(0xFF6C63FF),
        'heroTag': 'question_solver_offer',
        'marketingTitle': 'Takıldığın yerde bekleme!',
        'marketingSubtitle': 'Sınırsız soru çözümü ile netlerini hızla artır. Her soru için anında detaylı açıklama al.',
        'imageAsset': 'assets/images/bunnyy.png',
      },
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
          onPressed: _handleBack,
        ),
        title: Text(
          'Taktik Çözüm',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Arşivim',
            icon: const Icon(Icons.bookmarks_rounded),
            onPressed: () => context.pushNamed('SavedQuestions'),
          ),
          IconButton(
            tooltip: 'Premium Bilgi',
            icon: Icon(Icons.workspace_premium_rounded, color: Colors.amber[700]),
            onPressed: _openToolOffer,
          ),
        ],
      ),
      body: SafeArea(
        child: _selectedImage == null
            ? _buildEmptyState(theme)
            : _buildContent(theme),
      ),
      floatingActionButton: _selectedImage == null ? Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showImageSourceSheet,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 0,
          icon: const Icon(Icons.camera_alt_rounded),
          label: const Text('Soru Sor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                 .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 2.seconds),
                Image.asset(
                  'assets/images/bunnyy.png',
                  height: 120,
                ).animate().slideY(begin: 0.1, end: 0, duration: 1.seconds, curve: Curves.easeOutBack),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Taktik Tavşan Hazır!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Çözemediğin sorunun fotoğrafını çek veya yükle. Taktik Tavşan senin için adım adım açıklasın.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Soru Kartı
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              image: DecorationImage(
                image: FileImage(File(_selectedImage!.path)),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black12, Colors.black45],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    onPressed: _showImageSourceSheet, // Retake
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      backdropFilter: true,
                    ),
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

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Tavşan Animasyonu
        Stack(
          alignment: Alignment.center,
          children: [
             Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ).animate(onPlay: (c) => c.repeat())
             .scale(begin: const Offset(1, 1), end: const Offset(1.5, 1.5), duration: 1.5.seconds)
             .fadeOut(),
            Image.asset('assets/images/bunnyy.png', height: 80)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .rotate(begin: -0.05, end: 0.05, duration: 1.seconds),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Taktik Tavşan Soruyu Çözüyor...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ).animate().shimmer(duration: 2.seconds),
        const SizedBox(height: 8),
        Text(
          'Görsel analiz ediliyor ve çözüm hazırlanıyor.',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 40),
          const SizedBox(height: 16),
          Text(
            'Bir Sorun Oluştu',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.error),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Bilinmeyen bir hata',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _solveQuestion,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar Dene'),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Çözüm',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            // Save Button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSolutionLocally,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.primary,
                elevation: 0,
                side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSaving
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.bookmark_add_outlined, size: 18),
              label: Text(_isSaving ? 'Kaydediliyor' : 'Kaydet'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: MarkdownBody(
            data: _solution!,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(color: theme.colorScheme.onSurface, height: 1.6, fontSize: 16),
              h1: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 22),
              h2: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 20),
              strong: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700),
              blockquote: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontStyle: FontStyle.italic),
              blockquoteDecoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
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
              [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
              [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, LatexInlineSyntax()],
            ),
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05, end: 0),

        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () {
               // Share functionality could go here
            },
            icon: Icon(Icons.share_rounded, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.5)),
            label: Text(
              'Çözümü Paylaş (Yakında)',
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
            ),
          ),
        ),
      ],
    );
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 36, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

