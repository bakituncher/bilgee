// lib/features/onboarding/screens/exam_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/core/navigation/app_routes.dart';

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
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.help_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Seçimini Onayla'),
              ],
            ),
            content: Text(
              '$fullName sınavını seçmek üzeresin. Emin misin?',
              style: theme.textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Evet, Devam Et'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _header(BuildContext context, {double progress = 2 / 3}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sınav Seçimi',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // KALDIRILDI: _confirmResetIfNeeded() - Sınav değiştirme özelliği kaldırıldı

  // Bu fonksiyon artık hem seçim sonrası navigasyonu hem de veritabanı kaydını yönetecek.
  Future<void> _handleSelection(BuildContext context, WidgetRef ref, Function saveData) async {
    // 1. Veritabanına kaydet.
    await saveData();

    // Profil verisini yenile ve okunmasını bekle.
    ref.refresh(userProfileProvider);
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
      builder: (ctx) {
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
                  ...exam.sections
                      .where((section) => section.name != 'TYT')
                      .map(
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              const SizedBox(height: 12),
              Text(
                'Hazırlanacağın sınavı seçerek yolculuğuna devam et.',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Animate(
                        effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.2))],
                        child: _buildExamCard(context, "YKS", () => _onExamTypeSelected(context, ref, ExamType.yks)),
                      ),
                      Animate(
                        effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.2))],
                        child: _buildExamCard(context, "LGS", () => _onExamTypeSelected(context, ref, ExamType.lgs)),
                      ),
                      Animate(
                        effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.2))],
                        child: _buildExamCard(context, "AGS", () => _onExamTypeSelected(context, ref, ExamType.ags)),
                      ),
                      Animate(
                        effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.2))],
                        child: _buildExamCard(context, "KPSS", () => _showKpssSubTypeSelection(context, ref)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamCard(BuildContext context, String displayName, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
