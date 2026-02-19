// lib/features/onboarding/screens/exam_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:lottie/lottie.dart';

class ExamSelectionScreen extends ConsumerWidget {
  const ExamSelectionScreen({super.key});

  Future<bool> _confirmInitialExamSelection(
      BuildContext context, {
        required String examDisplayName,
        String? sectionDisplayName,
      }) async {
    final theme = Theme.of(context);
    final fullName =
    sectionDisplayName == null ? examDisplayName : '$examDisplayName - $sectionDisplayName';

    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  fullName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bu sınavı seçmek istediğine emin misin?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Evet, Devam Et'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Vazgeç',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ) ??
        false;
  }

  Widget _header(BuildContext context, {double progress = 2 / 3}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 8,
      ),
    );
  }

  // KALDIRILDI: _confirmResetIfNeeded() - Sınav değiştirme özelliği kaldırıldı

  // Bu fonksiyon artık hem seçim sonrası navigasyonu hem de veritabanı kaydını yönetecek.
  Future<void> _handleSelection(BuildContext context, WidgetRef ref, Function saveData) async {
    // 1. Veritabanına kaydet.
    await saveData();

    // Widget dispose edilmediyse devam et
    if (!context.mounted) return;

    // Profil verisini yenile ve okunmasını bekle.
    final _ = ref.refresh(userProfileProvider);
    await ref.read(userProfileProvider.future);

    // 2. Artık güncel veriyle navigasyonu güvenle kontrol et.
    if (!context.mounted) return;

    if (context.canPop()) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Sınav tercihin başarıyla güncellendi!"),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
    } else {
      context.go(AppRoutes.availability);
    }
  }

  void _showKpssSubTypeSelection(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (ctx) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hangi KPSS türüne hazırlanıyorsun?',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _onExamTypeSelected(context, ref, ExamType.kpssLisans);
                    },
                    child: const Text('KPSS Lisans'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _onExamTypeSelected(context, ref, ExamType.kpssOnlisans);
                    },
                    child: const Text('KPSS Önlisans'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _onExamTypeSelected(context, ref, ExamType.kpssOrtaogretim);
                    },
                    child: const Text('KPSS Ortaöğretim'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageSelection(
      BuildContext context,
      WidgetRef ref,
      Exam exam,
      ExamSection section,
      ExamType examType,
      String userId,
      dynamic firestoreService,
      ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (ctx) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Hangi dil sınavına hazırlanıyorsun?',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ...section.availableLanguages!.map(
                        (language) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);

                          final ok = await _confirmInitialExamSelection(
                            context,
                            examDisplayName: exam.name,
                            sectionDisplayName: 'YDT - $language',
                          );
                          if (!ok) return;

                          await _handleSelection(
                            context,
                            ref,
                                () => firestoreService.saveExamSelection(
                              userId: userId,
                              examType: examType,
                              sectionName: section.name,
                              language: language,
                            ),
                          );
                        },
                        child: Text(language),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onExamTypeSelected(BuildContext context, WidgetRef ref, ExamType examType) async {
    final exam = await ExamData.getExamByType(examType);
    final userId = ref.read(authControllerProvider).value!.uid;
    final firestoreService = ref.read(firestoreServiceProvider);

    // Çok bölümlü sınavlarda (YKS) onayı burada değil, alt seçimden sonra alacağız.
    final isMultiSection = exam.sections.length > 1 && examType != ExamType.lgs;

    // Tek bölümlü sınavlar (LGS, KPSS alt türleri vb.)
    if (!isMultiSection) {
      // KPSS alt türleri için displayName zaten "KPSS Lisans" vb. döndürüyor.
      final ok = await _confirmInitialExamSelection(
        context,
        examDisplayName: examType.displayName,
      );
      if (!ok) return;

      await _handleSelection(
        context,
        ref,
            () => firestoreService.saveExamSelection(
          userId: userId,
          examType: examType,
          sectionName: exam.sections.first.name,
          language: null,
        ),
      );
      return;
    }

    // YKS gibi çok bölümlü sınavlarda önce alan/bölüm seçtir, onayı sonra al.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (ctx) {
        // AGS için "AGS" ortak bölümünü filtrele, sadece branşları göster
        final sectionsToShow = examType == ExamType.ags
            ? exam.sections.where((s) => s.name != 'AGS').toList()
            : exam.sections;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Hangi alana hazırlanıyorsun?',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ...sectionsToShow.map(
                        (section) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);

                          // YDT seçildiyse önce dil seçimi yap
                          if (section.name == 'YDT' && section.availableLanguages != null) {
                            _showLanguageSelection(context, ref, exam, section, examType, userId, firestoreService);
                            return;
                          }

                          final ok = await _confirmInitialExamSelection(
                            context,
                            examDisplayName: exam.name,
                            sectionDisplayName: section.name,
                          );
                          if (!ok) return;

                          await _handleSelection(
                            context,
                            ref,
                                () => firestoreService.saveExamSelection(
                              userId: userId,
                              examType: examType,
                              sectionName: section.name,
                              // YDT dışı seçimlerde dil bilgisini sıfırla
                              language: null,
                            ),
                          );
                        },
                        child: Text(section.name),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final canPop = context.canPop();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sınav Seçimi'),
        automaticallyImplyLeading: canPop,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxHeight < 600;
            return Column(
              children: [
                // Üst kısım - Progress bar ve Lottie animasyonu
                Padding(
                  padding: EdgeInsets.all(isSmall ? 8.0 : 16.0),
                  child: Column(
                    children: [
                      _header(context),
                      SizedBox(height: isSmall ? 6 : 16),
                      Lottie.asset(
                        'assets/lotties/Davsan.json',
                        height: isSmall ? 60 : (constraints.maxHeight < 700 ? 90 : 150),
                        fit: BoxFit.contain,
                      ),
                      SizedBox(height: isSmall ? 4 : 12),
                      Text(
                        'Hazırlanacağın sınavı seçelim',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                // Alt kısım - Kartlar ekrana eşit dağılır, scroll yok
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isSmall ? 8.0 : 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Animate(
                            effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.2))],
                            child: _buildExamCard(context, "YKS", () => _onExamTypeSelected(context, ref, ExamType.yks), isSmall: isSmall),
                          ),
                          Animate(
                            effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.2))],
                            child: _buildExamCard(context, "LGS", () => _onExamTypeSelected(context, ref, ExamType.lgs), isSmall: isSmall),
                          ),
                          Animate(
                            effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.2))],
                            child: _buildExamCard(context, "DGS", () => _onExamTypeSelected(context, ref, ExamType.dgs), isSmall: isSmall),
                          ),
                          Animate(
                            effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.2))],
                            child: _buildExamCard(context, "ALES", () => _onExamTypeSelected(context, ref, ExamType.ales), isSmall: isSmall),
                          ),
                          Animate(
                            effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.2))],
                            child: _buildExamCard(context, "AGS - ÖABT", () => _onExamTypeSelected(context, ref, ExamType.ags), isSmall: isSmall),
                          ),
                          Animate(
                            effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.2))],
                            child: _buildExamCard(context, "KPSS", () => _showKpssSubTypeSelection(context, ref), isSmall: isSmall),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildExamCard(BuildContext context, String displayName, VoidCallback onTap, {bool isSmall = false}) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: isSmall ? 8 : 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }
}

