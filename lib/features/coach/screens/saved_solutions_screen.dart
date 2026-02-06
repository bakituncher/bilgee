import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/core/utils/exam_utils.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/coach/models/saved_solution_model.dart';
import 'package:taktik/features/coach/providers/saved_solutions_provider.dart';
import 'package:taktik/features/coach/screens/subject_solutions_screen.dart';
import 'package:taktik/utils/subject_utils.dart';
import 'package:taktik/shared/widgets/custom_back_button.dart';

class SavedSolutionsScreen extends ConsumerStatefulWidget {
  final bool isSelectionMode; // Ders seçim modu aktif mi?
  final List<String>? availableSubjects; // Seçilebilir dersler (seçim modunda)

  const SavedSolutionsScreen({
    super.key,
    this.isSelectionMode = false,
    this.availableSubjects,
  });

  @override
  ConsumerState<SavedSolutionsScreen> createState() =>
      _SavedSolutionsScreenState();
}

class _SavedSolutionsScreenState extends ConsumerState<SavedSolutionsScreen> {
  final ImagePicker _picker = ImagePicker();

  // -- CROP STATE --
  Uint8List? _rawImageBytes; // Kırpma ekranı aktifse dolu olur
  final _cropController = CropController();
  bool _isCropping = false; // Kırpma işlemi işleniyor mu? (Loading)
  bool _isLoading = false; // Genel yükleme
  int _rotationAngle = 0; // Döndürme açısı

  @override
  void dispose() {
    _rawImageBytes = null;
    super.dispose();
  }

  // --- YARDIM PENCERESİ ---
  void _showInfoSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Taşmayı önlemek için kaydırılabilir yap
      backgroundColor: Colors.transparent,
      builder: (context) => SingleChildScrollView(
        child: Container(
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(28),
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
              // İkon ve Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Soru Kutusu Nedir?",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Açıklama Metni
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.05)),
                ),
                child: Text(
                  "Soru kutusu, aralıklı tekrar yöntemiyle öğrenilen bilgileri uzun süreli hafızaya taşıyan bir sistemdir.\n\nÇözemediğiniz sorular üzerinde düzenli çalışarak eksiklerinizi kapatır, bilgiyi pekiştirir ve sınavda kolayca hatırlamanızı sağlar.",
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Kapat Butonu
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text("Anladım",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CROP & RESİM İŞLEMLERİ ---

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      setState(() => _isLoading = true);

      // Kullanıcının derslerini kontrol et (Erken çıkış)
      final subjects = await _getUserSubjects();
      if (subjects.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Ders listesi alınamadı veya tanımlı değil.'),
                backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // Optimizasyon: Resmi sıkıştırarak byte'lara çevir
      final Uint8List? compressedBytes =
      await FlutterImageCompress.compressWithFile(
        image.path,
        minWidth: 1080,
        minHeight: 1080,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      final bytes = compressedBytes ?? await image.readAsBytes();

      if (mounted) {
        setState(() {
          _rawImageBytes = bytes; // Kırpma ekranını aç
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onCropped(Uint8List croppedData) async {
    setState(() => _isCropping = true);

    try {
      // 1. Dosyayı geçici dizine yaz
      final tempDir = await getTemporaryDirectory();
      final fileName = 'q_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(croppedData);

      // 2. Kırpma modundan çık
      setState(() {
        _isCropping = false;
        _rawImageBytes = null;
      });

      // 3. Ders Seçimi Ekranına Git
      if (!mounted) return;

      final subjects = await _getUserSubjects();

      final selectedSubject = await Navigator.push<String>(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              SavedSolutionsScreen(
                isSelectionMode: true,
                availableSubjects: subjects,
              ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );

      // 4. Eğer ders seçildiyse kaydet
      if (selectedSubject != null) {
        await _saveImage(file, selectedSubject);
      }
    } catch (e) {
      setState(() {
        _isCropping = false;
        _rawImageBytes = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Görsel işlenemedi: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleCropBack() {
    setState(() {
      _rawImageBytes = null;
      _isLoading = false;
      _rotationAngle = 0; // Döndürme açısını sıfırla
    });
  }

  // Resmi 90 derece sağa döndürme
  Future<void> _rotateImage() async {
    if (_rawImageBytes == null) return;

    setState(() => _isCropping = true);

    try {
      // Resmi decode et
      img.Image? image = img.decodeImage(_rawImageBytes!);
      if (image == null) {
        throw Exception('Resim işlenemedi');
      }

      // 90 derece sağa döndür
      image = img.copyRotate(image, angle: 90);

      // Encode et
      final rotatedBytes = Uint8List.fromList(img.encodeJpg(image, quality: 85));

      setState(() {
        _rawImageBytes = rotatedBytes;
        _rotationAngle = (_rotationAngle + 90) % 360;
        _isCropping = false;
      });
    } catch (e) {
      setState(() {
        _isCropping = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Döndürme hatası: $e')),
        );
      }
    }
  }

  // --- DİĞER YARDIMCI FONKSİYONLAR ---

  Map<String, List<SavedSolutionModel>> _groupBySubject(
      List<SavedSolutionModel> solutions) {
    final Map<String, List<SavedSolutionModel>> grouped = {};
    for (final solution in solutions) {
      final subject = solution.subject ?? 'Genel';
      if (!grouped.containsKey(subject)) {
        grouped[subject] = [];
      }
      grouped[subject]!.add(solution);
    }
    return grouped;
  }


  Future<List<String>> _getUserSubjects() async {
    try {
      final user = ref.read(userProfileProvider).value;
      if (user?.selectedExam == null) return [];

      final examType = ExamType.values.firstWhere(
            (e) => e.name == user!.selectedExam,
        orElse: () => ExamType.yks,
      );

      final exam = await ExamData.getExamByType(examType);
      final relevantSections = ExamUtils.getRelevantSectionsForUser(user!, exam);

      final subjects = <String>{};
      for (final section in relevantSections) {
        subjects.addAll(section.subjects.keys);
      }

      return subjects.toList()..sort();
    } catch (e) {
      debugPrint('Ders listesi alınırken hata: $e');
      return [];
    }
  }

  Future<void> _saveImage(File imageFile, String subject) async {
    try {
      await ref.read(savedSolutionsProvider.notifier).saveSolution(
        imageFile: imageFile,
        solutionText: 'Görsel Soru',
        subject: subject,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "$subject" klasörüne eklendi!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Kaydetme hatası: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Ekleme menüsü için de scroll güvenliği
      backgroundColor: Colors.transparent,
      builder: (context) => SingleChildScrollView(
        child: Container(
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(28),
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
                "Soru Ekle",
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _buildSourceButton(
      ThemeData theme, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border:
            Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
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

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    // DURUM 1: KIRPMA MODU
    if (_rawImageBytes != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 60, bottom: 100),
              child: Center(
                child: Crop(
                  key: ValueKey(_rotationAngle), // Döndürme sonrası widget'ı yeniden oluştur
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
                  cornerDotBuilder: (size, edgeAlignment) =>
                  const DotControl(color: Colors.white),
                  interactive: true,
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Sol boşluk (denge için)
                      const SizedBox(width: 48),
                      // Başlık (Orta)
                      Expanded(
                        child: Text(
                          "Soruyu Kırp",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 18,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      // Döndürme Butonu (Sağ Üst)
                      IconButton(
                        onPressed: _rotateImage,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.15),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.rotate_right, size: 24),
                        tooltip: 'Döndür',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isCropping)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black,
                // Güvenli alan padding kontrolü
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                  top: 20,
                  left: 24,
                  right: 24,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _handleCropBack,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      child:
                      const Text('İptal', style: TextStyle(fontSize: 16)),
                    ),
                    FilledButton.icon(
                      onPressed: () => _cropController.crop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text('Kırp & Kaydet',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // DURUM 2: NORMAL LISTE MODU
    final List<SavedSolutionModel> solutions =
    ref.watch(savedSolutionsProvider);
    final theme = Theme.of(context);
    final grouped = _groupBySubject(solutions);

    final List<String> subjects =
    widget.isSelectionMode && widget.availableSubjects != null
        ? widget.availableSubjects!
        : grouped.keys.toList();

    subjects.sort();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.isSelectionMode ? 'Nereye Kaydedelim?' : 'Soru Kutum',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: widget.isSelectionMode
            ? IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        )
            : const CustomBackButton(),
        actions: [
          IconButton(
            onPressed: _showInfoSheet,
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Soru Kutusu Nedir?',
          ),
        ],
      ),
      floatingActionButton: widget.isSelectionMode
          ? null
          : FloatingActionButton.extended(
        onPressed: _showImageSourceSheet,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Soru Ekle'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (solutions.isEmpty && !widget.isSelectionMode) ||
          (widget.isSelectionMode && subjects.isEmpty)
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 80,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isSelectionMode
                  ? "Seçilecek ders bulunamadı."
                  : "Henüz kutuda soru yok.\nHadi hemen bir tane ekleyelim!",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color:
                  theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
      )
          : widget.isSelectionMode
          ? _buildSelectionGrid(context, theme, subjects, grouped)
          : _buildNormalGrid(context, theme, subjects, grouped),
    );
  }

  Widget _buildNormalGrid(BuildContext context, ThemeData theme,
      List<String> subjects, Map<String, List<SavedSolutionModel>> grouped) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final subject = subjects[index];
        final subjectSolutions = grouped[subject]!;
        return _buildSubjectCard(
          context,
          theme,
          subject,
          subjectSolutions,
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    SubjectSolutionsScreen(
                      subject: subject,
                    ),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSelectionGrid(BuildContext context, ThemeData theme,
      List<String> subjects, Map<String, List<SavedSolutionModel>> grouped) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Soruyu kaydetmek istediğin dersi seç',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              final subjectSolutions = grouped[subject] ?? [];
              return _buildSubjectCard(
                context,
                theme,
                subject,
                subjectSolutions,
                isSelectionMode: true,
                onTap: () {
                  Navigator.pop(context, subject);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectCard(
      BuildContext context,
      ThemeData theme,
      String subject,
      List<SavedSolutionModel> subjectSolutions, {
        bool isSelectionMode = false,
        required VoidCallback onTap,
      }) {
    final subjectColor = SubjectUtils.getSubjectColor(subject, colorScheme: theme.colorScheme);
    final subjectIcon = SubjectUtils.getSubjectIcon(subject);

    return Card(
      elevation: 2,
      shadowColor: subjectColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                subjectColor.withOpacity(0.1),
                subjectColor.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            // DÜZELTME: Sabit boşluklar yerine esnek yapı
            children: [
              const SizedBox(height: 4),
              // İkon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: subjectColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  subjectIcon,
                  size: 36,
                  color: subjectColor,
                ),
              ),
              const SizedBox(height: 10),
              // Ders İsmi (Esnek Alan)
              Expanded(
                child: Center(
                  child: Text(
                    subject,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Badge
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: subjectColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isSelectionMode && subjectSolutions.isEmpty
                      ? 'Yeni Klasör'
                      : '${subjectSolutions.length} soru',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: subjectColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}