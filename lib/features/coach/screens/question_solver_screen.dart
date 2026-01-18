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
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/core/utils/exam_utils.dart';

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
  bool _isSaved = false; // YENİ: Çözüm kaydedildi mi?
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
        _isSaved = false; // Sıfırla
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
            _isSaved = false; // Sıfırla
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
            _isSaved = false; // Sıfırla
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
      _isSaved = false; // Yeni soru için sıfırla
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

    // Kullanıcının derslerini al
    final availableSubjects = await _getUserSubjects();

    if (availableSubjects.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ders listesi yüklenemedi'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Çözüm Arşivi ekranını seçim modunda aç
    final selectedSubject = await Navigator.push<String>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SavedSolutionsScreen(
          isSelectionMode: true,
          availableSubjects: availableSubjects,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    if (selectedSubject == null) return; // Kullanıcı iptal etti

    try {
      final imageFile = File(_finalImageFile!.path);

      await ref.read(savedSolutionsProvider.notifier).saveSolution(
        imageFile: imageFile,
        solutionText: contentToSave,
        subject: selectedSubject,
      );

      if (mounted) {
        setState(() {
          _isSaved = true; // BAŞARILI: Durumu güncelle
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isChatMode
                  ? '✅ "$selectedSubject" klasörüne kaydedildi!'
                  : '✅ "$selectedSubject" klasörüne kaydedildi!',
            ),
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

  // Kullanıcının sınavına göre dersleri getir
  Future<List<String>> _getUserSubjects() async {
    try {
      final user = ref.read(userProfileProvider).value;
      if (user?.selectedExam == null) {
        debugPrint('❌ Kullanıcının seçili sınavı yok');
        return [];
      }

      debugPrint('✅ Kullanıcı sınavı: ${user!.selectedExam}');

      // ExamType enum'ını al
      final examType = ExamType.values.firstWhere(
            (e) => e.name == user.selectedExam,
        orElse: () => ExamType.yks,
      );

      debugPrint('✅ Exam type: ${examType.name}');

      // Exam verisini yükle
      final exam = await ExamData.getExamByType(examType);
      debugPrint('✅ Exam data yüklendi: ${exam.name}');

      // Kullanıcının ilgili bölümlerini al
      final relevantSections = ExamUtils.getRelevantSectionsForUser(user, exam);
      debugPrint('✅ İlgili bölümler: ${relevantSections.map((s) => s.name).join(", ")}');

      // Tüm dersleri topla (Set kullanarak tekrarları engelle)
      final subjects = <String>{};
      for (final section in relevantSections) {
        subjects.addAll(section.subjects.keys);
      }

      debugPrint('✅ Toplam ${subjects.length} ders bulundu: ${subjects.join(", ")}');

      // Alfabetik sırala ve döndür
      return subjects.toList()..sort();
    } catch (e) {
      debugPrint('❌ Ders listesi alınırken hata: $e');
      return [];
    }
  }


  void _openSavedSolutions() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SavedSolutionsScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
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

  // Premium FAB (Floating Action Button) Tasarımı
  Widget _buildStylishFAB(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.tertiary, // Gradyan geçişi
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          // Ana Gölge
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          // Hafif parlama efekti (beyaz)
          BoxShadow(
            color: Colors.white.withOpacity(0.2),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showImageSourceSheet,
          borderRadius: BorderRadius.circular(30),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                const Text(
                  "Soru Sor",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 3.seconds, delay: 2.seconds, color: Colors.white.withOpacity(0.3)); // Hafif parıltı efekti
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
                icon: Icon(
                  _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: _isSaved ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
                tooltip: _isSaved ? 'Kaydedildi' : 'Kaydet',
                onPressed: _isSaved
                    ? () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Bu soru zaten kütüphanene eklendi 🐰'),
                      backgroundColor: theme.colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
                    : _saveSolutionLocally,
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
                  child: Stack(
                    children: [
                      // Ana resim
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor),
                          image: DecorationImage(
                            image: FileImage(File(_finalImageFile!.path)),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      // Animasyon overlay (sadece analiz sırasında) - TARAMA EFEKTİ
                      if (_isAnalyzing)
                        _ScanningAnalysisOverlay(theme: theme),
                    ],
                  ),
                ),

              // İÇERİK ALANI
              Expanded(
                child: _isAnalyzing
                    ? const SizedBox.expand() // Animasyon resmin üstünde, burada boş alan
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
            ? _buildStylishFAB(theme)
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          // HERO KARTI
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primaryContainer, theme.colorScheme.surface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Taktik Tavşan Görseli
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/bunnyy.png',
                    height: 56,
                    width: 56,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(duration: 3.seconds, begin: const Offset(1, 1), end: const Offset(1.05, 1.05)),
                const SizedBox(height: 14),
                Text(
                  "Sorularla Boğuşma,\nTaktik Tavşan Yanında!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Takıldığın sorunun fotoğrafını çek,\nTaktik Tavşan senin için adım adım çözsün.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.2, end: 0),

          const SizedBox(height: 20),

          Text(
            "Nasıl Çalışır?",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 10),

          // Özellikler
          _buildFeatureRow(
            theme,
            icon: Icons.camera_alt_outlined,
            title: "Fotoğrafını Çek",
            subtitle: "Soruyu net bir şekilde görüntüle.",
            delay: 300,
          ),
          _buildFeatureRow(
            theme,
            icon: Icons.auto_awesome_outlined,
            title: "Taktik Tavşan Çözsün",
            subtitle: "Saniyeler içinde detaylı anlatım.",
            delay: 400,
          ),
          _buildFeatureRow(
            theme,
            icon: Icons.chat_bubble_outline_rounded,
            title: "Anlamadığını Sor",
            subtitle: "Tavşan ile sohbet et.",
            delay: 500,
          ),
          _buildFeatureRow(
            theme,
            icon: Icons.bookmark_outline_rounded,
            title: "Dilersen Soruyu Kaydet",
            subtitle: "İstediğin zaman tekrar bak.",
            delay: 600,
          ),

          const SizedBox(height: 70), // FAB için alt boşluk
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
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
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

// --- TARAMA EFEKTLİ ANALİZ OVERLAY ---
class _ScanningAnalysisOverlay extends StatefulWidget {
  final ThemeData theme;

  const _ScanningAnalysisOverlay({required this.theme});

  @override
  State<_ScanningAnalysisOverlay> createState() => _ScanningAnalysisOverlayState();
}

class _ScanningAnalysisOverlayState extends State<_ScanningAnalysisOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scanAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withOpacity(0.4),
      ),
      child: AnimatedBuilder(
        animation: _scanAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // Grid overlay (opsiyonel - gelişmiş görünüm için)
              CustomPaint(
                painter: _GridPainter(
                  color: widget.theme.colorScheme.primary.withOpacity(0.1),
                ),
                size: Size.infinite,
              ),

              // Ana tarama çizgisi
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: _ScanLinePainter(
                    progress: _scanAnimation.value,
                    color: widget.theme.colorScheme.primary,
                  ),
                  child: Container(),
                ),
              ),

              // Merkez bilgi kutusu
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: widget.theme.colorScheme.surface.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.theme.colorScheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Radar ikonu
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Dış halka (pulse efekti)
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.theme.colorScheme.primary.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                          ).animate(onPlay: (c) => c.repeat())
                              .scale(
                                begin: const Offset(1.0, 1.0),
                                end: const Offset(1.3, 1.3),
                                duration: 1.5.seconds,
                              )
                              .fadeOut(begin: 0.6, duration: 1.5.seconds),

                          // İç ikon
                          Icon(
                            Icons.document_scanner_outlined,
                            size: 36,
                            color: widget.theme.colorScheme.primary,
                          ).animate(onPlay: (c) => c.repeat())
                              .shimmer(
                                duration: 1.8.seconds,
                                color: widget.theme.colorScheme.secondary,
                              ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Metin
                      Text(
                        'Soru Analiz Ediliyor',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: widget.theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Taktik Tavşan çözümü hazırlıyor...',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.theme.colorScheme.onSurfaceVariant,
                        ),
                      ).animate(onPlay: (c) => c.repeat())
                          .fadeIn(duration: 1.seconds)
                          .then()
                          .fadeOut(duration: 1.seconds),

                      const SizedBox(height: 12),

                      // Progress indicator
                      SizedBox(
                        width: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            backgroundColor: widget.theme.colorScheme.primary.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate()
                    .fadeIn(duration: 300.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.0, 1.0),
                      duration: 300.ms,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Tarama çizgisi çizen CustomPainter
class _ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Progress -1'den 1'e gidiyor, biz bunu 0-1 aralığına çevirelim
    final normalizedProgress = (progress + 1) / 2;
    final scanY = size.height * normalizedProgress;

    // Glow efekti için gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withOpacity(0.0),
        color.withOpacity(0.3),
        color.withOpacity(0.8),
        color.withOpacity(0.3),
        color.withOpacity(0.0),
      ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    );

    final rect = Rect.fromLTWH(
      0,
      scanY - 40,
      size.width,
      80,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, paint);

    // Ana tarama çizgisi (ince parlak çizgi)
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, scanY),
      Offset(size.width, scanY),
      linePaint,
    );

    // Yan nokta efektleri
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 5; i++) {
      final x = (size.width / 4) * i;
      canvas.drawCircle(Offset(x, scanY), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Grid çizen CustomPainter (arka plan detayı)
class _GridPainter extends CustomPainter {
  final Color color;

  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;

    // Dikey çizgiler
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Yatay çizgiler
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

