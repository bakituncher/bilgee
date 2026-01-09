// lib/features/home/screens/add_test_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/utils/exam_utils.dart';
import '../logic/add_test_notifier.dart';
import '../widgets/add_test_step1.dart';
import '../widgets/add_test_step2.dart';
import '../widgets/add_test_step3.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';

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
          return Scaffold(appBar: AppBar(title: Text('${selectedExamType.displayName} Sonuç Bildirimi')), body: const LogoLoader());
        }
        if (snapshot.hasError) {
          return Scaffold(appBar: AppBar(title: Text('${selectedExamType.displayName} Sonuç Bildirimi')), body: Center(child: Text("Sınav verisi yüklenemedi: ${snapshot.error}")));
        }

        if (snapshot.hasData && addTestState.availableSections.isEmpty) {
          final exam = snapshot.data!;
          List<ExamSection> availableSections;

          // DEĞİŞİKLİK: İlgili bölümleri tek bir kaynaktan belirle.
          // - LGS: tüm sections (notifier içinde zaten birleştiriliyor)
          // - YKS: TYT + kullanıcının alanı / YDT
          // - AGS: "AGS Ortak" + kullanıcının branşı
          // - Diğerleri: kullanıcı alanı vb.
          availableSections = ExamUtils.getRelevantSectionsForUser(userProfile, exam);

          // Veri hazır olduğunda, beyni (Notifier) anında bilgilendir.
          WidgetsBinding.instance.addPostFrameCallback((_) {
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