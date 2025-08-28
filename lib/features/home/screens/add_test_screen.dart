// lib/features/home/screens/add_test_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/models/exam_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import '../logic/add_test_notifier.dart';
import '../widgets/add_test_step1.dart';
import '../widgets/add_test_step2.dart';
import '../widgets/add_test_step3.dart';

// Provider'lar artık logic dosyasında. Bu dosya sadece UI.

class AddTestScreen extends ConsumerWidget {
  const AddTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider).value;
    final addTestState = ref.watch(addTestProvider);

    if (userProfile?.selectedExam == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text("Lütfen önce profilden bir sınav seçin.")));
    }

    final selectedExamType = ExamType.values.byName(userProfile!.selectedExam!);

    return FutureBuilder<Exam>(
      future: ExamData.getExamByType(selectedExamType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && addTestState.availableSections.isEmpty) {
          return Scaffold(appBar: AppBar(title: Text('${selectedExamType.displayName} Sonuç Bildirimi')), body: const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(appBar: AppBar(title: Text('${selectedExamType.displayName} Sonuç Bildirimi')), body: Center(child: Text("Sınav verisi yüklenemedi: ${snapshot.error}")));
        }

        if (snapshot.hasData && addTestState.availableSections.isEmpty) {
          final exam = snapshot.data!;
          List<ExamSection> availableSections;

          // DEĞİŞİKLİK: YKS ve LGS için bölüm mantığı ayrıldı.
          if (selectedExamType == ExamType.yks) {
            final tytSection = exam.sections.firstWhere((s) => s.name == 'TYT');
            final userAytSection = exam.sections.firstWhere(
                  (s) => s.name == userProfile.selectedExamSection,
              orElse: () => exam.sections.first,
            );
            availableSections = (tytSection.name == userAytSection.name) ? [tytSection] : [tytSection, userAytSection];
          } else {
            // LGS ve diğer sınavlar için tüm bölümleri al.
            availableSections = exam.sections;
          }

          // Veri hazır olduğunda, beyni (Notifier) anında bilgilendir.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // DEĞİŞİKLİK: Notifier'a hangi sınav türüyle çalıştığı bilgisi gönderiliyor.
            ref.read(addTestProvider.notifier).initialize(availableSections, selectedExamType);
          });
        }

        final List<Widget> steps = [
          const Step1TestInfo(),
          const Step2ScoreEntry(),
          const Step3Summary(),
        ];

        return Scaffold(
          appBar: AppBar(title: Text('${selectedExamType.displayName} Sonuç Bildirimi')),
          body: steps[addTestState.currentStep],
        );
      },
    );
  }
}