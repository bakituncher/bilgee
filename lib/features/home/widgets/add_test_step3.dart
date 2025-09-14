// lib/features/home/widgets/add_test_step3.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/home/logic/add_test_notifier.dart';
import 'package:bilge_ai/data/models/exam_model.dart';
import 'package:bilge_ai/features/quests/logic/quest_notifier.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';

class Step3Summary extends ConsumerWidget {
  const Step3Summary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addTestProvider);
    final notifier = ref.read(addTestProvider.notifier);
    final section = state.selectedSection!;
    final user = ref.watch(userProfileProvider).value;

    int totalCorrect = 0;
    int totalWrong = 0;
    int totalBlank = 0;
    int totalQuestions = 0;

    final Map<String, Map<String, int>> finalScores = {};

    state.scores.forEach((subject, values) {
      final subjectDetails = section.subjects[subject]!;
      final correct = values['dogru']!;
      final wrong = values['yanlis']!;
      final blank = subjectDetails.questionCount - correct - wrong;

      totalCorrect += correct;
      totalWrong += wrong;
      totalBlank += blank;
      totalQuestions += subjectDetails.questionCount;

      finalScores[subject] = {'dogru': correct, 'yanlis': wrong, 'bos': blank};
    });

    double totalNet = totalCorrect - (totalWrong * section.penaltyCoefficient);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Genel Özet", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          _SummaryRow(label: "Toplam Doğru", value: totalCorrect.toString(), color: AppTheme.successColor),
          _SummaryRow(label: "Toplam Yanlış", value: totalWrong.toString(), color: AppTheme.accentColor),
          _SummaryRow(label: "Toplam Boş", value: totalBlank.toString(), color: AppTheme.secondaryTextColor),
          const Divider(height: 32),
          _SummaryRow(label: "Toplam Net", value: totalNet.toStringAsFixed(2), isTotal: true),
          const Spacer(),
          ElevatedButton(
            onPressed: state.isSaving ? null : () async {
              if (user == null) return;
              notifier.setSaving(true);

              final newTest = TestModel(
                id: const Uuid().v4(),
                userId: user.id,
                testName: state.testName,
                examType: ExamType.values.byName(user.selectedExam!),
                sectionName: section.name,
                date: DateTime.now(),
                scores: finalScores,
                totalNet: totalNet,
                totalQuestions: totalQuestions,
                totalCorrect: totalCorrect,
                totalWrong: totalWrong,
                totalBlank: totalBlank,
                penaltyCoefficient: section.penaltyCoefficient,
              );

              try {
                await ref.read(firestoreServiceProvider).addTestResult(newTest);

                // Yeni test eklendiği için analizi yeniden çalıştırıp özeti kaydet
                try {
                  final updatedTests = await ref.read(firestoreServiceProvider).getTestResultsPaginated(user.id, limit: 1000);
                  final performance = await ref.read(firestoreServiceProvider).getPerformanceSummaryOnce(user.id);
                  final examData = await ExamData.getExamByType(ExamType.values.byName(user.selectedExam!));
                  final analysis = StatsAnalysis(updatedTests, performance, examData, ref.read(firestoreServiceProvider), user: user);
                  await ref.read(firestoreServiceProvider).updateAnalysisSummary(user.id, analysis);
                } catch (e, st) {
                  // Hata günlüğe kaydedilir ancak kullanıcı akışı engellenmez.
                  debugPrint('Performans özeti güncellenirken hata oluştu: $e\n$st');
                }

                // Yeni FutureProvider verisini yenile (invalidate)
                ref.invalidate(testsProvider);

                // --- GÜNCELLENDİ: Sadece 'test gönderimi' eylemini bildir ---
                ref.read(questNotifierProvider.notifier).userSubmittedTest();

                // ------------------------------------

                if (context.mounted) {
                  context.push('/home/test-result-summary', extra: newTest);
                }
              } catch (e, s) {
                debugPrint('Deneme sonucu kaydedilirken bir hata oluştu: $e');
                debugPrint('Stack trace: $s');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Deneme sonucu kaydedilemedi. Lütfen tekrar deneyin.'),
                      backgroundColor: AppTheme.accentColor,
                    ),
                  );
                }
              } finally {
                if(context.mounted) {
                  notifier.setSaving(false);
                }
              }
            },
            child: state.isSaving
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                : const Text('Kaydet ve Raporu Görüntüle'),
          ),
          TextButton(
              onPressed: () => notifier.previousStep(),
              child: const Text('Geri Dön ve Düzenle')
          )
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.color,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isTotal ? textTheme.titleLarge : textTheme.bodyLarge),
          Text(value, style: textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
