// lib/features/onboarding/screens/exam_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/core/theme/app_theme.dart';

class ExamSelectionScreen extends ConsumerWidget {
  const ExamSelectionScreen({super.key});

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

  Future<bool> _confirmResetIfNeeded(BuildContext context) async {
    // Bu ekran 'Sınavı Değiştir' olarak açıldıysa tüm veriler silinecek.
    if (!context.canPop()) return true; // onboarding akışı: reset yok, direkt devam
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Tüm Veriler Silinecek'),
            content: const Text('Sınavı değiştirirsen tüm denemelerin, odak seansların ve performans verilerin kalıcı olarak silinecek. Devam etmek istiyor musun?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Evet, Sil')),
            ],
          ),
        ) ?? false;
  }

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
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hangi KPSS türüne hazırlanıyorsun?',
                  style: Theme.of(context).textTheme.headlineSmall,
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
                    child: const Text("Lisans"),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _onExamTypeSelected(context, ref, ExamType.kpssOnlisans);
                    },
                    child: const Text("Önlisans"),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _onExamTypeSelected(context, ref, ExamType.kpssOrtaogretim);
                    },
                    child: const Text("Ortaöğretim"),
                  ),
                ),
              ],
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

    final proceed = await _confirmResetIfNeeded(context);
    if (!proceed) return;

    // Eğer değişim akışı ise önce verileri temizle
    if (context.canPop()) {
      await firestoreService.resetUserDataForNewExam();
    }

    // LGS ve tek bölümlü sınavlar için (KPSS gibi)
    if (exam.sections.length == 1 || examType == ExamType.lgs) {
      await _handleSelection(context, ref, () =>
          firestoreService.saveExamSelection(
            userId: userId,
            examType: examType,
            sectionName: exam.sections.first.name,
          ),
      );
      return;
    }

    // YKS gibi çok bölümlü sınavlar için
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                        // Önce modal'ı kapat
                        Navigator.pop(ctx);
                        // Sonra seçimi işle
                        await _handleSelection(context, ref, () =>
                            firestoreService.saveExamSelection(
                              userId: userId,
                              examType: examType,
                              sectionName: section.name,
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
        title: canPop ? const Text("Sınavı Değiştir") : const Text('Sınav Seçimi'),
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
                canPop
                    ? 'Stratejilerin ve analizlerin bu seçime göre güncellenecek.'
                    : 'Hazırlanacağın sınavı seçerek yolculuğuna devam et.',
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