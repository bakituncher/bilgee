// lib/features/home/screens/add_test_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/utils/exam_utils.dart'; // Mantık burada
import '../logic/add_test_notifier.dart';
import '../widgets/add_test_step1.dart';
import '../widgets/add_test_step2.dart';
import '../widgets/add_test_step3.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/shared/widgets/custom_back_button.dart';

class AddTestScreen extends ConsumerWidget {
  const AddTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider).value;
    final addTestState = ref.watch(addTestProvider);

    // Kullanıcı profilinde sınav seçili değilse uyarı ver
    if (userProfile?.selectedExam == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Sınav Seçimi")),
        body: const Center(
          child: Text("Lütfen önce profilden bir sınav seçin."),
        ),
      );
    }

    final selectedExamType = ExamType.values.byName(userProfile!.selectedExam!);

    return FutureBuilder<Exam>(
      future: ExamData.getExamByType(selectedExamType),
      builder: (context, snapshot) {
        // Yükleniyor durumu (Sadece bölümler henüz yüklenmemişse göster)
        if (snapshot.connectionState == ConnectionState.waiting && addTestState.availableSections.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text('${selectedExamType.displayName} Sonuç Bildirimi')),
            body: const LogoLoader(),
          );
        }

        // Hata durumu
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text('${selectedExamType.displayName} Sonuç Bildirimi')),
            body: Center(child: Text("Sınav verisi yüklenemedi: ${snapshot.error}")),
          );
        }

        // Veri geldiğinde ve henüz state'e aktarılmadıysa
        if (snapshot.hasData && addTestState.availableSections.isEmpty) {
          final exam = snapshot.data!;

          // YKS, AGS, LGS gibi sınavların bölüm mantığı ExamUtils içinden çekilir.
          // Bu sayede UI kodu temiz kalır.
          final List<ExamSection> availableSections = ExamUtils.getRelevantSectionsForUser(userProfile, exam);

          // Veri hazır olduğunda, Notifier'ı (State) başlat.
          // Build işlemi sırasında state değiştirmek hata vereceği için postFrameCallback kullanıyoruz.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(addTestProvider.notifier).initialize(availableSections, selectedExamType);
          });
        }

        // Adım Widget'ları
        final List<Widget> steps = [
          const Step1TestInfo(),
          const Step2ScoreEntry(),
          const Step3Summary(),
        ];

        return Scaffold(
          appBar: AppBar(
            leading: const CustomBackButton(),
            title: Text('${selectedExamType.displayName} Sonuç Bildirimi'),
            // İsteğe bağlı: Geri butonu davranışını state'i temizlemek için özelleştirebilirsiniz.
          ),
          body: steps.length > addTestState.currentStep
              ? steps[addTestState.currentStep]
              : const SizedBox.shrink(), // Hata önleyici
        );
      },
    );
  }
}