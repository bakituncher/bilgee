// lib/features/weakness_workshop/screens/workshop_stats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';

class WorkshopStatsScreen extends ConsumerWidget {
  const WorkshopStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfAsync = ref.watch(performanceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Simyacının Cevher Ocağı"),
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.5),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor,
              AppTheme.cardColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: perfAsync.when(
          data: (perf) {
            final summary = perf ?? const PerformanceSummary();
            final analysis = WorkshopAnalysis(summary);

            if (analysis.totalQuestionsAnswered == 0) {
              return _buildEmptyState(context);
            }

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildAlchemistPrism(context, analysis),
                const SizedBox(height: 32),
                _buildSubjectSpectrum(context, analysis),
                const SizedBox(height: 32),
                _buildForgingBench(context, analysis),
              ].animate(interval: 150.ms).fadeIn(duration: 600.ms).slideY(begin: 0.3),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
          error: (e, s) => Center(child: Text("Hata: $e")),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_moon_rounded, size: 80, color: AppTheme.secondaryTextColor),
              const SizedBox(height: 16),
              Text(
                'Ocak Henüz Soğuk',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Cevher Atölyesi\'nde bir konu üzerinde çalıştığında, bu ocak senin zaferlerinle alev alacak. İlk ham cevherini dövmeye başla!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor, height: 1.5),
              ),
            ],
          ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),
        ));
  }

  // YENİ WIDGET: Simya Prizması
  Widget _buildAlchemistPrism(BuildContext context, WorkshopAnalysis analysis) {
    final masteryPercent = analysis.overallAccuracy;
    final masteryColor = Color.lerp(AppTheme.accentColor, AppTheme.successColor, masteryPercent / 100)!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.lightSurfaceColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Animate(
            onPlay: (c) => c.repeat(reverse: true),
            effects: [
              ShimmerEffect(duration: 3000.ms, color: masteryColor.withValues(alpha: 0.5)),
            ],
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [masteryColor.withValues(alpha: 0.5), Colors.transparent],
                  stops: const [0.4, 1.0],
                ),
              ),
              child: Center(
                child: Text(
                  "%${masteryPercent.toStringAsFixed(1)}",
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(color: masteryColor, blurRadius: 15)],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text("Genel Ustalık Oranı", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // *** HATA ÇÖZÜMÜ: Her istatistik öğesi Expanded ile sarmalandı ***
              Expanded(child: _StatItem(value: analysis.totalQuestionsAnswered.toString(), label: "Toplam Soru")),
              Expanded(child: _StatItem(value: analysis.uniqueTopicsWorkedOn.toString(), label: "İşlenen Cevher")),
              Expanded(child: _StatItem(value: analysis.mostWorkedSubject, label: "Favori Cephe")),
            ],
          ),
        ],
      ),
    );
  }

  // YENİ WIDGET: Bilgi Tayfı (Kristal Barlar)
  Widget _buildSubjectSpectrum(BuildContext context, WorkshopAnalysis analysis) {
    final chartData = analysis.subjectAccuracyList;
    if (chartData.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Bilgi Tayfı", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ...chartData.map((data) => _SubjectCrystalBar(data: data)).toList(),
      ],
    );
  }

  // YENİ WIDGET: Dövme Tezgâhı
  Widget _buildForgingBench(BuildContext context, WorkshopAnalysis analysis) {
    final strongest = analysis.getTopTopicsByMastery(count: 2);
    final weakest = analysis.getWeakestTopics(count: 3);

    return Column(
      children: [
        if (strongest.isNotEmpty) ...[
          _buildTopicSection(
              context,
              title: "Cilalanmış Cevherler",
              icon: Icons.shield_rounded,
              iconColor: AppTheme.successColor,
              topics: strongest,
              isPolished: true
          ),
          const SizedBox(height: 24),
        ],
        if (weakest.isNotEmpty) ...[
          _buildTopicSection(
              context,
              title: "Dövülecek Ham Cevherler",
              subtitle: "En Yüksek Gelişim Potansiyeli",
              icon: Icons.local_fire_department_rounded,
              iconColor: AppTheme.accentColor,
              topics: weakest,
              isPolished: false
          )
        ],
      ],
    );
  }

  Widget _buildTopicSection(BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Map<String, dynamic>> topics,
    required bool isPolished,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        if (subtitle != null)
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor)),
        const SizedBox(height: 12),
        ...topics.map((topic) => _TopicCard(topic: topic, isPolished: isPolished)).toList()
      ],
    );
  }
}

// YENİ YARDIMCI WIDGET'LAR
class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // *** HATA ÇÖZÜMÜ: Uzun metinler için hizalama ve taşma kontrolü eklendi ***
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SubjectCrystalBar extends StatelessWidget {
  final ({String subject, double accuracy}) data;
  const _SubjectCrystalBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final progress = data.accuracy / 100;
    final color = Color.lerp(AppTheme.accentColor, AppTheme.successColor, progress)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightSurfaceColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Text(
                data.subject,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final barWidth = (maxW * 0.38).clamp(80.0, 180.0);
              return SizedBox(
                width: barWidth,
                child: Stack(
                  children: [
                    Container(
                      width: barWidth,
                      height: 25,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                    Animate(
                      effects: [
                        ScaleEffect(
                          duration: 1200.ms,
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.centerLeft,
                          begin: const Offset(0, 1),
                          end: Offset(progress, 1),
                        ),
                      ],
                      child: Container(
                        width: barWidth,
                        height: 25,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: [color.withValues(alpha: 0.7), color],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: color, blurRadius: 10, spreadRadius: -5),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: barWidth,
                      height: 25,
                      child: Center(
                        child: Text(
                          "%${data.accuracy.toStringAsFixed(1)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final Map<String, dynamic> topic;
  final bool isPolished;
  const _TopicCard({required this.topic, required this.isPolished});

  @override
  Widget build(BuildContext context) {
    final color = isPolished ? AppTheme.successColor : AppTheme.secondaryColor;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.cardColor.withValues(alpha: 0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isPolished ? null : () => context.push('/ai-hub/weakness-workshop'),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topic['topic'] as String, style: Theme.of(context).textTheme.titleMedium),
                    Text(topic['subject'] as String, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
                  ],
                ),
              ),
              if (!isPolished) ...[
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryColor),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// GÜNCELLENMİŞ VE YENİ FONKSİYON EKLENMİŞ ANALİZ SINIFI
class WorkshopAnalysis {
  final PerformanceSummary summary;
  WorkshopAnalysis(this.summary);

  String _deSanitizeKey(String key) {
    return key.replaceAll('_', ' ');
  }

  int get totalQuestionsAnswered => summary.topicPerformances.values
      .expand((subject) => subject.values)
      .map((topic) => topic.questionCount)
      .sum;

  int get totalCorrectAnswers => summary.topicPerformances.values
      .expand((subject) => subject.values)
      .map((topic) => topic.correctCount)
      .sum;

  int get uniqueTopicsWorkedOn => summary.topicPerformances.values
      .expand((subject) => subject.keys)
      .toSet()
      .length;

  double get overallAccuracy => totalQuestionsAnswered > 0 ? (totalCorrectAnswers / totalQuestionsAnswered) * 100 : 0.0;

  String get mostWorkedSubject {
    if (summary.topicPerformances.isEmpty) return "Yok";
    final subjectName = summary.topicPerformances.entries
        .map((entry) => MapEntry(
        entry.key,
        entry.value.values.map((e) => e.questionCount).sum))
        .sortedBy<num>((e) => e.value)
        .lastOrNull
        ?.key;
    return subjectName != null ? _deSanitizeKey(subjectName) : "Yok";
  }

  List<({String subject, double accuracy})> get subjectAccuracyList {
    return summary.topicPerformances.entries.map((entry) {
      final totalQuestions = entry.value.values.map((e) => e.questionCount).sum;
      final totalCorrect = entry.value.values.map((e) => e.correctCount).sum;
      final accuracy = totalQuestions > 0 ? (totalCorrect / totalQuestions) * 100 : 0.0;
      return (subject: _deSanitizeKey(entry.key), accuracy: accuracy);
    }).where((d) => d.accuracy > 0).sortedBy<num>((d) => d.accuracy).reversed.toList();
  }

  List<Map<String, dynamic>> _getAllTopicsSorted() {
    final allTopics = summary.topicPerformances.entries.expand((subjectEntry) {
      return subjectEntry.value.entries.map((topicEntry) {
        final performance = topicEntry.value;
        final netCorrect = performance.correctCount - (performance.wrongCount * 0.25);
        final mastery = performance.questionCount > 0 ? (netCorrect / performance.questionCount) : 0.0;
        return {
          'subject': _deSanitizeKey(subjectEntry.key),
          'topic': _deSanitizeKey(topicEntry.key),
          'mastery': mastery.clamp(0.0, 1.0),
        };
      });
    }).where((topic) => (topic['mastery'] as double) > 0).toList();

    allTopics.sort((a, b) => (b['mastery'] as double).compareTo(a['mastery'] as double));
    return allTopics;
  }

  List<Map<String, dynamic>> getTopTopicsByMastery({int count = 2}) {
    return _getAllTopicsSorted().take(count).toList();
  }

  List<Map<String, dynamic>> getWeakestTopics({int count = 3}) {
    final allTopics = _getAllTopicsSorted();
    return allTopics.reversed.take(count).toList();
  }
}