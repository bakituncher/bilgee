// lib/features/onboarding/screens/exam_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/data/models/exam_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/core/navigation/app_routes.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';

class ExamSelectionScreen extends ConsumerWidget {
  const ExamSelectionScreen({super.key});

  // Bu fonksiyon artık hem seçim sonrası navigasyonu hem de veritabanı kaydını yönetecek.
  Future<void> _handleSelection(BuildContext context, WidgetRef ref, Function saveData) async {
    // 1. Veritabanına kaydet.
    await saveData();

    // !!!İŞTE ÇÖZÜM BU SATIRDA!!!
    // Navigasyondan önce güncel profil verisinin gelmesini bekle.
    await ref.refresh(userProfileProvider.future);

    // 2. Artık güncel veriyle navigasyonu güvenle kontrol et.
    if (!context.mounted) return;

    if (context.canPop()) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sınav tercihin başarıyla güncellendi!"),
          backgroundColor: AppTheme.successColor,
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
    // Ayarlar'dan geliniyorsa geri butonu göster
    final canPop = context.canPop();

    return Scaffold(
      appBar: AppBar(
        // Eğer geri dönülemiyorsa (ilk kurulumsa) başlığı gizle
        title: canPop ? const Text("Sınavı Değiştir") : null,
        automaticallyImplyLeading: canPop,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                canPop ? 'Yeni Sınavını Seç' : 'Harika!',
                style: textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                canPop
                    ? 'Stratejilerin ve analizlerin bu seçime göre güncellenecek.'
                    : 'Şimdi hazırlanacağın sınavı seçerek yolculuğuna başla.',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 40),
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