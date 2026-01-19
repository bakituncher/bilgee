// lib/features/weakness_workshop/screens/workshop_stats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/performance_summary.dart';

class WorkshopStatsScreen extends ConsumerWidget {
  const WorkshopStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfAsync = ref.watch(performanceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Cihazın alt güvenli alan boşluğunu alıyoruz
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // Adaptive background for both themes
          _AdaptiveBackground(isDark: isDark),
          Column(
            children: [
              _WSHeader(
                title: 'İstatistikler',
                onBack: () => context.pop(),
                onSaved: () => context.push('/ai-hub/weakness-workshop/saved-workshops'),
                isDark: isDark,
              ),
              Expanded(
                child: perfAsync.when(
                  data: (perf) {
                    final summary = perf ?? const PerformanceSummary();
                    final analysis = WorkshopAnalysis(summary);

                    if (analysis.totalQuestionsAnswered == 0) {
                      return _buildEmptyState(context);
                    }

                    return ListView(
                      // DÜZELTME: Alt boşluğa bottomPadding ekliyoruz
                      padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0 + bottomPadding),
                      children: [
                        _buildAlchemistPrism(context, analysis),
                        const SizedBox(height: 20),
                        _buildSubjectSpectrum(context, analysis),
                        const SizedBox(height: 20),
                        _buildForgingBench(context, analysis),
                      ].animate(interval: 120.ms).fadeIn(duration: 500.ms).slideY(begin: 0.2),
                    );
                  },
                  loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.secondary)),
                  error: (e, s) => Center(child: Text('Hata: $e', style: TextStyle(color: isDark ? Colors.white : theme.colorScheme.onSurface))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.diamond_rounded, size: 80, color: isDark ? Colors.white : colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Ocak Henüz Soğuk',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: isDark ? Colors.white : colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Atölyede bir konuyu çalıştığında ocak alevlenecek. İlk konunu çalışmaya başla!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark ? Colors.white70 : colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
      ),
    );
  }

  // Compact Mastery Circle - Adaptive for both themes
  Widget _buildAlchemistPrism(BuildContext context, WorkshopAnalysis analysis) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final masteryPercent = analysis.overallAccuracy;
    final masteryColor = Color.lerp(colorScheme.error, colorScheme.secondary, masteryPercent / 100)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor.withOpacity(0.5) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
              : colorScheme.surfaceContainerHighest.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Animate(
            onPlay: (c) => c.repeat(reverse: true),
            effects: [
              ShimmerEffect(duration: 3000.ms, color: masteryColor.withOpacity(0.4)),
            ],
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [masteryColor.withOpacity(0.4), Colors.transparent],
                  stops: const [0.5, 1.0],
                ),
              ),
              child: Center(
                child: Text(
                  "%${masteryPercent.toStringAsFixed(1)}",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : colorScheme.onSurface,
                    shadows: isDark ? [Shadow(color: masteryColor, blurRadius: 12)] : [],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Genel Ustalık Oranı",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _StatItem(value: analysis.totalQuestionsAnswered.toString(), label: "Toplam Soru")),
              Expanded(child: _StatItem(value: analysis.uniqueTopicsWorkedOn.toString(), label: "İşlenen Cevher")),
              Expanded(child: _StatItem(value: analysis.mostWorkedSubject, label: "Favori Cephe")),
            ],
          ),
        ],
      ),
    );
  }

  // Compact Subject Spectrum - Adaptive for both themes
  Widget _buildSubjectSpectrum(BuildContext context, WorkshopAnalysis analysis) {
    final chartData = analysis.subjectAccuracyList;
    if (chartData.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Bilgi Tayfı",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...chartData.map((data) => _SubjectCrystalBar(data: data)),
      ],
    );
  }

  // Compact Topic Lists - Adaptive for both themes
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
              iconColor: Theme.of(context).colorScheme.secondary,
              topics: strongest,
              isPolished: true
          ),
          const SizedBox(height: 16),
        ],
        if (weakest.isNotEmpty) ...[
          _buildTopicSection(
              context,
              title: "Dövülecek Ham Cevherler",
              subtitle: "En Yüksek Gelişim Potansiyeli",
              icon: Icons.local_fire_department_rounded,
              iconColor: Theme.of(context).colorScheme.error,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 10),
        ...topics.map((topic) => _TopicCard(topic: topic, isPolished: isPolished))
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final progress = data.accuracy / 100;
    final color = Color.lerp(colorScheme.error, colorScheme.secondary, progress)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor.withOpacity(0.5) : theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
              : colorScheme.surfaceContainerHighest.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              data.subject,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? Colors.white : colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: isDark
                        ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                        : colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  ),
                ),
                Animate(
                  effects: [
                    ScaleEffect(
                      duration: 1000.ms,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      begin: const Offset(0, 1),
                      end: Offset(progress, 1),
                    ),
                  ],
                  child: Container(
                    width: 100,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.8), color],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: isDark
                          ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)]
                          : [],
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  height: 20,
                  child: Center(
                    child: Text(
                      "%${data.accuracy.toStringAsFixed(0)}",
                      style: TextStyle(
                        color: progress > 0.3 ? Colors.white : (isDark ? Colors.white70 : colorScheme.onSurface),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        shadows: progress > 0.3 && isDark ? [const Shadow(color: Colors.black, blurRadius: 4)] : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final color = isPolished ? colorScheme.secondary : colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor.withOpacity(0.6) : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.4 : 0.5),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isPolished ? null : () => context.push('/ai-hub/weakness-workshop'),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic['topic'] as String,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? Colors.white : colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        topic['subject'] as String,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white70 : colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPolished) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: color, size: 20),
                ]
              ],
            ),
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

class _WSHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onSaved;
  final bool isDark;
  const _WSHeader({required this.title, required this.onBack, required this.onSaved, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final top = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 8, 16, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : colorScheme.onSurface,
            ),
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : colorScheme.surfaceContainerHighest.withOpacity(0.5),
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                    : colorScheme.surfaceContainerHighest.withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: colorScheme.secondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Cevher Kasası',
            onPressed: onSaved,
            icon: Icon(
              Icons.inventory_2_outlined,
              color: isDark ? Colors.white : colorScheme.onSurface,
            ),
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : colorScheme.surfaceContainerHighest.withOpacity(0.5),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdaptiveBackground extends StatefulWidget {
  final bool isDark;
  const _AdaptiveBackground({required this.isDark});
  @override
  State<_AdaptiveBackground> createState() => _AdaptiveBackgroundState();
}

class _AdaptiveBackgroundState extends State<_AdaptiveBackground> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return widget.isDark
            ? _buildDarkBackground(t)
            : _buildLightBackground(context);
      },
    );
  }

  Widget _buildDarkBackground(double t) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF0F172A), const Color(0xFF0B1020), t)!,
            Color.lerp(const Color(0xFF1E293B), const Color(0xFF0F172A), 1 - t)!,
          ],
        ),
      ),
      child: Stack(
        children: [
          _GlowBlob(top: -40, left: -20, color: const Color(0xFF22D3EE).withValues(alpha: 0.25), size: 200 + 40 * t),
          _GlowBlob(bottom: -60, right: -30, color: const Color(0xFFA78BFA).withValues(alpha: 0.22), size: 240 - 20 * t),
          _GlowBlob(top: 160, right: -40, color: const Color(0xFF34D399).withValues(alpha: 0.18), size: 180 + 20 * (1 - t)),
        ],
      ),
    );
  }

  Widget _buildLightBackground(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).scaffoldBackgroundColor,
            colorScheme.surfaceContainerHighest.withOpacity(0.2),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double? top, left, right, bottom;
  final Color color;
  final double size;
  const _GlowBlob({this.top, this.left, this.right, this.bottom, required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 40)],
        ),
      ),
    );
  }
}