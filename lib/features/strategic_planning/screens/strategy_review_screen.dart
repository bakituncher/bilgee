// lib/features/strategic_planning/screens/strategy_review_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/models/plan_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';
import 'package:bilge_ai/data/repositories/ai_service.dart';
import 'package:bilge_ai/features/quests/logic/quest_notifier.dart';

class StrategyReviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> generationResult;
  const StrategyReviewScreen({super.key, required this.generationResult});

  @override
  ConsumerState<StrategyReviewScreen> createState() =>
      _StrategyReviewScreenState();
}

class _StrategyReviewScreenState extends ConsumerState<StrategyReviewScreen> {
  late Map<String, dynamic> _currentStrategyData;
  final PageController _pageController = PageController(viewportFraction: 0.85);
  bool _isRevising = false;

  @override
  void initState() {
    super.initState();
    _currentStrategyData = widget.generationResult;
  }

  WeeklyPlan get weeklyPlan => WeeklyPlan.fromJson(_currentStrategyData['weeklyPlan']);
  String get pacing => _currentStrategyData['pacing'];

  void _approvePlan() {
    final userId = ref.read(authControllerProvider).value!.uid;
    ref.read(firestoreServiceProvider).updateStrategicPlan(
      userId: userId,
      pacing: pacing,
      weeklyPlan: _currentStrategyData['weeklyPlan'],
    );
    ref.read(questNotifierProvider.notifier).userApprovedStrategy();
    ref.invalidate(userProfileProvider);
    context.go('/home');
  }

  Future<void> _fetchRevisedPlan(String feedback) async {
    setState(() => _isRevising = true);

    final user = ref.read(userProfileProvider).value;
    final tests = ref.read(testsProvider).value;
    final performance = ref.read(performanceProvider).value;
    final planDoc = ref.read(planProvider).value;

    if (user == null || tests == null || performance == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kullanıcı, test veya performans verisi bulunamadı.")));
      }
      setState(() => _isRevising = false);
      return;
    }

    try {
      final resultJson = await ref.read(aiServiceProvider).generateGrandStrategy(
        user: user,
        tests: tests,
        performance: performance,
        planDoc: planDoc,
        pacing: pacing,
        revisionRequest: feedback,
      );

      final decodedData = jsonDecode(resultJson);

      if (decodedData.containsKey('error')) {
        throw Exception(decodedData['error']);
      }

      setState(() {
        _currentStrategyData = {
          'weeklyPlan': decodedData['weeklyPlan'],
          'pacing': pacing,
        };
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revizyon sırasında hata: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRevising = false);
      }
    }
  }

  void _openRevisionWorkshop() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: RevisionWorkshop(
          onRevisionRequested: (String feedback) {
            Navigator.of(context).pop();
            _fetchRevisedPlan(feedback);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Zafer Yolu Çizildi!",
                          style: textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                          "İşte sana özel hazırlanan haftalık harekat planın. İncele ve onayla.",
                          style: textTheme.titleMedium
                              ?.copyWith(color: AppTheme.secondaryTextColor)),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2),
                SizedBox(
                  height: 400,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: weeklyPlan.plan.length,
                    itemBuilder: (context, index) {
                      final dailyPlan = weeklyPlan.plan[index];
                      return _DailyPlanCard(dailyPlan: dailyPlan)
                          .animate()
                          .fadeIn(delay: (100 * index).ms)
                          .slideX(begin: 0.5);
                    },
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text("Revizyon İste"),
                          onPressed: _openRevisionWorkshop,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppTheme.secondaryColor),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text("Onayla ve Başla"),
                          onPressed: _approvePlan,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isRevising)
            Container(
              color: Colors.black.withValues(alpha: Colors.black.a * 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.secondaryColor),
                    const SizedBox(height: 20),
                    Text(
                      "Strateji güncelleniyor...\nEmirlerin işleniyor komutanım!",
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(color: AppTheme.secondaryTextColor),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(),
        ],
      ),
    );
  }
}

class _DailyPlanCard extends StatelessWidget {
  final DailyPlan dailyPlan;
  const _DailyPlanCard({required this.dailyPlan});

  IconData _getIconForTaskType(String type) {
    switch (type.toLowerCase()) {
      case 'study': return Icons.book_rounded;
      case 'practice': case 'routine': return Icons.edit_note_rounded;
      case 'test': return Icons.quiz_rounded;
      case 'review': return Icons.history_edu_rounded;
      case 'break': return Icons.self_improvement_rounded;
      default: return Icons.shield_moon_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dailyPlan.day,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppTheme.secondaryColor),
            ),
            const Divider(height: 24),
            Expanded(
              child: dailyPlan.schedule.isEmpty
                  ? Center(
                child: Text(
                  "Bugün dinlenme ve strateji gözden geçirme günü. Zihnini dinlendir, yarınki fethe hazırlan!",
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppTheme.secondaryTextColor),
                ),
              )
                  : ListView.builder(
                itemCount: dailyPlan.schedule.length,
                itemBuilder: (context, index) {
                  final item = dailyPlan.schedule[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Icon(_getIconForTaskType(item.type),
                              size: 20, color: AppTheme.secondaryTextColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.activity, style: Theme.of(context).textTheme.bodyLarge),
                              Text(item.time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RevisionWorkshop extends StatefulWidget {
  final Function(String feedback) onRevisionRequested;
  const RevisionWorkshop({super.key, required this.onRevisionRequested});

  @override
  State<RevisionWorkshop> createState() => _RevisionWorkshopState();
}

class _RevisionWorkshopState extends State<RevisionWorkshop> {
  final _textController = TextEditingController();
  final List<String> _quickFeedbacks = [
    "Daha yoğun bir program istiyorum.",
    "Biraz daha hafif olmalı.",
    "Matematik dersine daha çok ağırlık verelim.",
    "Sözel konulara odaklanmalıyız.",
    "Daha fazla deneme çözümü ekle.",
  ];
  final Set<String> _selectedFeedbacks = {};

  void _sendFeedback() {
    final customFeedback = _textController.text.trim();
    final allFeedbacks = [..._selectedFeedbacks, customFeedback]
        .where((f) => f.isNotEmpty)
        .join("\n- ");
    if (allFeedbacks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Lütfen bir geri bildirim belirtin."),
        backgroundColor: AppTheme.accentColor,
      ));
      return;
    }
    widget.onRevisionRequested("- " + allFeedbacks);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Revizyon Atölyesi",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Stratejide neleri değiştirmemi istersin?",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: _quickFeedbacks.map((feedback) {
                final isSelected = _selectedFeedbacks.contains(feedback);
                return FilterChip(
                  label: Text(feedback),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedFeedbacks.add(feedback);
                      } else {
                        _selectedFeedbacks.remove(feedback);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Eklemek istediğin özel bir not var mı?",
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _sendFeedback,
              child: const Text("Yeni Plan Oluştur"),
            ),
          ],
        ),
      ),
    );
  }
}