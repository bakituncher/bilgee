import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taktik/features/coach/providers/saved_solutions_provider.dart';
import 'package:taktik/features/coach/screens/saved_solutions_screen.dart';
import 'package:taktik/features/coach/services/question_solver_service.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:taktik/data/providers/firestore_providers.dart';

// Basit mesaj modeli
class SolverMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  SolverMessage(this.text, {required this.isUser}) : time = DateTime.now();
}

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

  // YENİ: Akış Kontrol Değişkenleri
  String? _initialSolution; // İlk gelen tekil çözüm
  bool _isChatMode = false; // Sohbet modu aktif mi?

  final List<SolverMessage> _messages = []; // Sohbet geçmişi
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isAnalyzing = false; // Yapay zeka analiz durumu
  bool _isCropping = false;  // Kırpma işlemi işleniyor durumu
  bool _isProcessingImage = false; // Fotoğraf ilk işlenirken (Loader için)
  bool _isChatLoading = false; // Sohbet cevap bekliyor mu?
  String? _error;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    _rawImageBytes = null;
    _finalImageFile = null;
    super.dispose();
  }

  // --- Temel Fonksiyonlar ---

  void _handleBack() {
    if (_rawImageBytes != null || _finalImageFile != null) {
      setState(() {
        _rawImageBytes = null;
        _finalImageFile = null;
        _initialSolution = null;
        _messages.clear();
        _isChatMode = false;
        _error = null;
        _isAnalyzing = false;
        _isCropping = false;
      });
      return;
    }
    if (context.canPop()) context.pop();
    else context.go('/ai-hub');
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);

      if (image != null) {
        setState(() {
          _isProcessingImage = true; // Yükleniyor göster
        });

        // OPTİMİZASYON: Resmi ham haliyle okumak yerine sıkıştırarak okuyoruz.
        // Bu işlem 10MB'lık fotoyu ~300KB'a düşürür, crop ekranı uçak gibi açılır.
        final Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
          image.path,
          minWidth: 1080, // 1080p fazlasıyla yeterli
          minHeight: 1080,
          quality: 85,    // Kalite kaybı fark edilmez ama boyut çok düşer
          format: CompressFormat.jpeg,
        );

        if (compressedBytes != null) {
          setState(() {
            _rawImageBytes = compressedBytes;
            _finalImageFile = null;
            _initialSolution = null;
            _messages.clear();
            _isChatMode = false;
            _error = null;
            _isProcessingImage = false;
          });
        } else {
          // Sıkıştırma başarısız olursa orijinali kullan (Fallback)
          final originalBytes = await image.readAsBytes();
          setState(() {
            _rawImageBytes = originalBytes;
            _initialSolution = null;
            _messages.clear();
            _isChatMode = false;
            _isProcessingImage = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Görsel yüklenirken hata oluştu: $e';
        _isProcessingImage = false;
      });
    }
  }

  Future<void> _onCropped(Uint8List croppedData) async {
    // İşlem başladığı an loading göster
    setState(() {
      _isCropping = true;
    });

    try {
      // Dosya yazma işlemi arka planda hızlıca olsun
      final tempDir = await getTemporaryDirectory();
      // Dosya adını benzersiz yap
      final fileName = 'q_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');

      // Byte verisini dosyaya yaz
      await file.writeAsBytes(croppedData);

      setState(() {
        _finalImageFile = XFile(file.path);
        _isCropping = false;
        _rawImageBytes = null; // Kırpma ekranından çık

        // Analizi başlat
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
          _initialSolution = result; // İlk sonucu kaydet
          _isAnalyzing = false;
          _isChatMode = false; // Henüz sohbet modu kapalı
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

  // BUTONA BASILINCA ÇAĞRILACAK: Sohbet Modunu Başlat
  void _activateChatMode() {
    if (_initialSolution == null) return;

    setState(() {
      _isChatMode = true;
      // İlk çözümü sohbetin ilk mesajı olarak ekle
      if (_messages.isEmpty) {
        _messages.add(SolverMessage(_initialSolution!, isUser: false));
      }
    });

    // Hafif bir kaydırma efekti ile kullanıcıya odaklanma hissi ver
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // YENİ: Takip sorusu gönderme
  Future<void> _sendFollowUpMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isChatLoading) return;

    // 1. Kullanıcı mesajını ekle
    setState(() {
      _messages.add(SolverMessage(text, isUser: true));
      _isChatLoading = true;
    });
    _chatController.clear();
    _scrollToBottom();

    try {
      final service = ref.read(questionSolverServiceProvider);
      final user = ref.read(userProfileProvider).value;

      // Bağlam olarak ilk çözümü kullan
      final contextSolution = _initialSolution ?? _messages.first.text;

      final response = await service.solveFollowUp(
        originalPrompt: "Context",
        previousSolution: contextSolution,
        userQuestion: text,
        examType: user?.selectedExam,
      );

      if (mounted) {
        setState(() {
          _messages.add(SolverMessage(response, isUser: false));
          _isChatLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'))
        );
        setState(() => _isChatLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- YENİ KAYDETME FONKSİYONU ---
  Future<void> _saveSolutionLocally() async {
    // Kaydetme mantığı: Sohbet varsa sohbeti, yoksa sadece ilk çözümü kaydet
    final contentToSave = _isChatMode
        ? _messages.map((m) => "${m.isUser ? 'Soru' : 'Çözüm'}: ${m.text}").join('\n\n---\n\n')
        : _initialSolution;

    if (_finalImageFile == null || contentToSave == null) return;

    try {
      final imageFile = File(_finalImageFile!.path);

      await ref.read(savedSolutionsProvider.notifier).saveSolution(
        imageFile: imageFile,
        solutionText: contentToSave,
        subject: "Matematik", // İstersen analizden dersi de çekebiliriz
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isChatMode ? 'Çözüm ve sohbet kaydedildi!' : 'Çözüm kaydedildi!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Görüntüle',
              textColor: Colors.white,
              onPressed: _openSavedSolutions,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openSavedSolutions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SavedSolutionsScreen()),
    );
  }

  void _showImageSourceSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(28), // Daha yuvarlak köşeler
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Nasıl yüklemek istersin?",
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                _buildSourceButton(
                  theme,
                  Icons.camera_alt_rounded,
                  "Kamera",
                  () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(width: 16),
                _buildSourceButton(
                  theme,
                  Icons.photo_library_rounded,
                  "Galeri",
                  () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButton(ThemeData theme, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
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
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // --- Arayüz (Build) ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // DURUM 0: Fotoğraf seçildi, işleniyor (Kırpma ekranına geçiş ara yüzü)
    if (_isProcessingImage) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                "Fotoğraf Hazırlanıyor...",
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              )
            ],
          ),
        ),
      );
    }

    // DURUM 1: Henüz fotoğraf seçilmediyse veya sonuç ekranındaysak
    if (_rawImageBytes == null) {
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
            _isChatMode ? 'Soru Asistanı' : (_initialSolution != null ? 'Çözüm' : 'Anlık Çözüm'),
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          actions: [
            if (_initialSolution != null)
              IconButton(
                icon: const Icon(Icons.bookmark_border_rounded),
                tooltip: 'Kaydet',
                onPressed: _saveSolutionLocally,
              )
            else
              IconButton(
                icon: const Icon(Icons.bookmark_border_rounded),
                tooltip: 'Kaydedilenler',
                onPressed: _openSavedSolutions,
              )
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Resim Alanı (Her zaman üstte, sohbette küçülebilir)
              if (_finalImageFile != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _isChatMode ? 120 : 200, // Sohbette yer açmak için resmi küçült
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                    image: DecorationImage(
                      image: FileImage(File(_finalImageFile!.path)),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

              // İÇERİK ALANI
              Expanded(
                child: _isAnalyzing
                    ? _buildLoadingState(theme)
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: _buildErrorState(theme),
                            ),
                          )
                        : _initialSolution == null
                            ? _buildEmptyState(theme) // Fotoğraf çekin ekranı
                            : _isChatMode
                                ? _buildChatView(theme) // SOHBET MODU
                                : _buildInitialResultView(theme), // İLK SONUÇ MODU
              ),

              // Chat Input (Sadece sohbet modunda görünür)
              if (_isChatMode) _buildInputArea(theme),
            ],
          ),
        ),
        floatingActionButton: (_initialSolution == null && !_isAnalyzing)
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
                  if (image is Uint8List) {
                    _onCropped(image);
                  }
                },
                baseColor: Colors.black,
                maskColor: Colors.black.withOpacity(0.6),
                initialSize: 0.8,
                cornerDotBuilder: (size, edgeAlignment) => const DotControl(color: Colors.white),
                interactive: true,
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

  // --- MODERN KARŞILAMA EKRANI ---
  Widget _buildEmptyState(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          // 1. HERO KARTI (Büyük Başlık)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, size: 48, color: Colors.white),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(duration: 2.seconds, begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
                const SizedBox(height: 16),
                const Text(
                  "Sorularla Boğuşma,\nZekice Çöz!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Takıldığın sorunun fotoğrafını çek,\nyapay zeka anında çözsün ve anlatısın.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.2, end: 0),

          const SizedBox(height: 32),

          // 2. ÖZELLİK LİSTESİ BAŞLIĞI
          Text(
            "Nasıl Çalışır?",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 16),

          // 3. ADIM KARTLARI
          _buildFeatureRow(
            theme,
            icon: Icons.camera_alt_outlined,
            title: "Fotoğrafını Çek",
            subtitle: "Net bir şekilde soruyu görüntüle.",
            delay: 300,
          ),
          _buildFeatureRow(
            theme,
            icon: Icons.document_scanner_outlined,
            title: "Yapay Zeka Analizi",
            subtitle: "Saniyeler içinde detaylı çözüm.",
            delay: 400,
          ),
          _buildFeatureRow(
            theme,
            icon: Icons.chat_bubble_outline_rounded,
            title: "Anlamadığını Sor",
            subtitle: "Çözüm üzerine sohbet et.",
            isNew: true, // Yeni özelliği vurgula
            delay: 500,
          ),

          const SizedBox(height: 80), // FAB için boşluk
        ],
      ),
    );
  }

  // Yardımcı Widget: Özellik Satırı
  Widget _buildFeatureRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int delay,
    bool isNew = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "YENİ",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onTertiary,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: delay.ms).fadeIn().slideX(begin: 0.1, end: 0);
  }

  // --- MOD WIDGETLARI ---

  // MOD 1: Sadece Çözüm Ekranı
  Widget _buildInitialResultView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Çözüm Kartı
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
              data: _initialSolution!,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, height: 1.5),
                h1: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                strong: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700),
                blockquote: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
                blockquoteDecoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 4)),
                ),
              ),
              builders: {
                'latex': LatexElementBuilder(
                  textStyle: TextStyle(color: theme.colorScheme.onSurface),
                ),
              },
              extensionSet: md.ExtensionSet(
                [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, LatexInlineSyntax()],
              ),
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 24),

          // AKSİYON BUTONU: "Anlamadım"
          FilledButton.icon(
            onPressed: _activateChatMode,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
            ),
            icon: const Icon(Icons.help_outline_rounded),
            label: const Text(
              "Anlamadım / Soru Sor",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),

          const SizedBox(height: 16),
          Center(
            child: Text(
              "Detaylı sormak için butona tıkla 👆",
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // MOD 2: Sohbet Ekranı
  Widget _buildChatView(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isChatLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _buildTypingIndicator(theme);
        return _buildMessageBubble(theme, _messages[index]);
      },
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
        mainAxisSize: MainAxisSize.min,
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

  // --- YENİ WIDGET'LAR ---

  Widget _buildMessageBubble(ThemeData theme, SolverMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    "Taktik Tavşan",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // Markdown Desteği (Latex dahil)
            MarkdownBody(
              data: message.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                  fontSize: 15,
                ),
                strong: TextStyle(
                  color: isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              builders: {
                'latex': LatexElementBuilder(
                  textStyle: TextStyle(
                    color: isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                  ),
                ),
              },
              extensionSet: md.ExtensionSet(
                [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, LatexInlineSyntax()],
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: InputDecoration(
                hintText: 'Anlamadığın yeri sor...',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendFollowUpMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isChatLoading ? null : _sendFollowUpMessage,
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Lottie.asset(
            'assets/lotties/loading_dots.json',
            height: 40,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
          ),
          const SizedBox(width: 8),
          Text(
            "Cevap yazılıyor...",
            style: TextStyle(color: theme.colorScheme.outline),
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
            data: _messages.isNotEmpty ? _messages.first.text : '',
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
}


// --- LaTeX Syntax Sınıfları ---

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