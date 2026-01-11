import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taktik/features/coach/services/question_solver_service.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:taktik/data/providers/firestore_providers.dart';

class QuestionSolverScreen extends ConsumerStatefulWidget {
  const QuestionSolverScreen({super.key});

  @override
  ConsumerState<QuestionSolverScreen> createState() => _QuestionSolverScreenState();
}

class _QuestionSolverScreenState extends ConsumerState<QuestionSolverScreen> {
  // --- Değişkenler ---

  // Crop işlemi için ham resim verisi (Kırpma ekranı için)
  Uint8List? _rawImageBytes;

  // Kırpılmış ve sunucuya gönderilmeye hazır dosya
  XFile? _finalImageFile;

  // Crop Widget Kontrolcüsü
  final _cropController = CropController();

  // Analiz Sonuçları
  String? _solution;
  bool _isAnalyzing = false; // Yapay zeka analiz durumu
  bool _isCropping = false;  // Kırpma işlemi işleniyor durumu
  String? _error;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _rawImageBytes = null;
    _finalImageFile = null;
    super.dispose();
  }

  // --- Temel Fonksiyonlar ---

  void _handleBack() {
    // 1. Durum: Analiz sonucu veya kırpma ekranındaysak -> Temizle ve başa dön
    if (_rawImageBytes != null || _finalImageFile != null || _solution != null) {
      setState(() {
        _rawImageBytes = null;
        _finalImageFile = null;
        _solution = null;
        _error = null;
        _isAnalyzing = false;
        _isCropping = false;
      });
      return;
    }

    // 2. Durum: Hiçbir şey yoksa -> Sayfadan çık
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
        // Resmi byte olarak oku (Crop paketi byte array ister)
        final bytes = await image.readAsBytes();
        setState(() {
          _rawImageBytes = bytes; // Resmi kırpma moduna sok
          _finalImageFile = null;
          _solution = null;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Görsel yüklenirken hata oluştu: $e';
      });
    }
  }

  // Kırpma işlemi bittiğinde çalışır (Kütüphane callback'i)
  Future<void> _onCropped(Uint8List croppedData) async {
    setState(() {
      _isCropping = true;
    });

    try {
      // Byte verisini geçici bir dosyaya yaz (Servis XFile istiyor)
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/question_${DateTime.now().millisecondsSinceEpoch}.jpg').create();
      await file.writeAsBytes(croppedData);

      setState(() {
        _finalImageFile = XFile(file.path);
        _isCropping = false;
        _rawImageBytes = null; // Kırpma ekranından çık

        // Otomatik olarak analizi başlat
        _solveQuestion();
      });
    } catch (e) {
      setState(() {
        _isCropping = false;
        _error = 'Görsel işlenemedi: $e';
      });
    }
  }

  Future<void> _solveQuestion() async {
    if (_finalImageFile == null) return;

    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final service = ref.read(questionSolverServiceProvider);
      final user = ref.read(userProfileProvider).value;
      final examType = user?.selectedExam;

      final result = await service.solveQuestion(_finalImageFile!, examType: examType);

      if (mounted) {
        setState(() {
          _solution = result;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception:', '').trim();
          _isAnalyzing = false;
        });
      }
    }
  }

  void _showImageSourceSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Soru Yükle',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),
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

  // --- Arayüz (Build) ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // DURUM 1: Henüz fotoğraf seçilmediyse veya sonuç ekranındaysak (Normal Scaffold)
    // _rawImageBytes == null ise burası çalışır.
    if (_rawImageBytes == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor, // AppBar rengi sabitlendi
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface),
            onPressed: _handleBack,
          ),
          title: Text(
            _solution != null ? 'Çözüm' : 'Anlık Çözüm',
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
        ),
        body: SafeArea(
          child: _finalImageFile == null
              ? _buildEmptyState(theme) // Fotoğraf yoksa
              : _buildResultContent(theme), // Fotoğraf varsa (Analiz/Sonuç)
        ),
        floatingActionButton: _finalImageFile == null
            ? FloatingActionButton.extended(
          onPressed: _showImageSourceSheet,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          icon: const Icon(Icons.add_a_photo_rounded),
          label: const Text('Soru Sor'),
        )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      );
    }

    // DURUM 2: Fotoğraf seçildi, Kırpma Ekranı (Özel Siyah Arayüz)
    // _rawImageBytes != null ise burası çalışır.
    return Scaffold(
      backgroundColor: Colors.black, // Full screen siyah mod
      body: Stack(
        children: [
          // 1. Kırpma Aracı (Orta Alan)
          Padding(
            padding: const EdgeInsets.only(top: 60, bottom: 100),
            child: Center(
              child: Crop(
                image: _rawImageBytes!,
                controller: _cropController,
                onCropped: (image) {
                  // Crop sonucu geldiğinde
                  if (image is Uint8List) {
                    _onCropped(image);
                  }
                },
                baseColor: Colors.black,
                maskColor: Colors.black.withOpacity(0.6),
                initialSize: 0.8,
                cornerDotBuilder: (size, edgeAlignment) => const DotControl(color: Colors.white),
                interactive: true,
                // fixCropRect parametresi bazı versiyonlarda farklı olabilir,
                // interactive: true genelde yeterlidir.
              ),
            ),
          ),

          // 2. Üst Bar (Başlık)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                alignment: Alignment.center,
                child: Text(
                  "Soruyu Kırp",
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w600
                  ),
                ),
              ),
            ),
          ),

          // 3. Yükleniyor Göstergesi (Crop işlemi sırasında)
          if (_isCropping)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // 4. Alt Kontrol Paneli (İptal - Onay)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                top: 20,
                left: 24,
                right: 24,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // İptal Butonu
                  TextButton(
                    onPressed: _handleBack,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('İptal', style: TextStyle(fontSize: 16)),
                  ),

                  // Onay Butonu (Sağ Altta)
                  FilledButton.icon(
                    onPressed: () => _cropController.crop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text('Kırp & Çöz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Yardımcı Widget'lar ---

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

  Widget _buildResultContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Soru Kartı
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
              image: DecorationImage(
                image: FileImage(File(_finalImageFile!.path)),
                fit: BoxFit.cover,
              ),
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  onPressed: () {
                    // Yeniden çekmek için (Başa dön)
                    setState(() {
                      _finalImageFile = null;
                      _rawImageBytes = null;
                      _solution = null;
                    });
                  },
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  tooltip: "Yeni Fotoğraf Çek",
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          if (_isAnalyzing)
            _buildLoadingState(theme)
          else if (_error != null)
            _buildErrorState(theme)
          else if (_solution != null)
              _buildSolutionCard(theme),

          // Gizlilik notu
          if (_solution != null) ...[
            const SizedBox(height: 32),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.privacy_tip_outlined, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  const SizedBox(width: 6),
                  Text(
                    'Görsel sunucularımızda saklanmaz.',
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
          'assets/lotties/loading_dots.json',
          height: 100,
          errorBuilder: (context, error, stackTrace) =>
          const Center(child: CircularProgressIndicator()),
        ),
        const SizedBox(height: 16),
        Text(
          'Soru Analiz Ediliyor...',
          style: TextStyle(
            fontSize: 16,
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
              [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
              [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, LatexInlineSyntax()],
            ),
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
      ],
    );
  }

  void _saveSolutionLocally() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Çözüm panoya kopyalandı!')),
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

// --- LaTeX Syntax Sınıfları (Eski koddakiyle aynı) ---

class LatexInlineSyntax extends md.InlineSyntax {
  LatexInlineSyntax() : super(r'(\$\$[\s\S]*?\$\$)|(\$[^$]*\$)');

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

class LatexElementBuilder extends MarkdownElementBuilder {
  final TextStyle? textStyle;
  LatexElementBuilder({this.textStyle});

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