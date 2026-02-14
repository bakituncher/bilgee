// lib/features/strategic_planning/screens/strategy_review_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/data/repositories/ai_service.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';

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
  bool _isSaving = false; // 👈 Çift tıklama engelleyici

  @override
  void initState() {
    super.initState();
    _currentStrategyData = widget.generationResult;
  }

  WeeklyPlan get weeklyPlan => WeeklyPlan.fromJson(_currentStrategyData['weeklyPlan']);
  String get pacing => _currentStrategyData['pacing'];

  void _approvePlan() async {
    // ✅ Çift tıklamayı engelle
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final userId = ref.read(authControllerProvider).value!.uid;

      // Plan kaydet
      await ref.read(firestoreServiceProvider).updateStrategicPlan(
        userId: userId,
        pacing: pacing,
        weeklyPlan: _currentStrategyData['weeklyPlan'],
      );

      // Quest'i kaydet
      ref.read(questNotifierProvider.notifier).userApprovedStrategy();

      // Provider'ları yenile
      ref.invalidate(userProfileProvider);
      ref.invalidate(planProvider);

      // Ana ekrana dön
      if (mounted) context.go('/home');
    } catch (e) {
      // Hata olursa kullanıcıyı bilgilendir
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plan kaydedilemedi: $e')),
        );
      }
    } finally {
      // İşlem bitti, kilidi aç
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _fetchRevisedPlan(String feedback) async {
    setState(() => _isRevising = true);

    final user = ref.read(userProfileProvider).value;
    final tests = ref.read(testsProvider).value ?? [];
    final performance = ref.read(performanceProvider).value;
    final planDoc = ref.read(planProvider).value;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kullanıcı verisi bulunamadı.")));
      }
      setState(() => _isRevising = false);
      return;
    }

    if (performance == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Performans verisi yükleniyor, lütfen bekleyin.")));
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2),
                Expanded(
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
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _openRevisionWorkshop,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            side: BorderSide(color: Theme.of(context).colorScheme.primary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.edit_note_rounded),
                                SizedBox(width: 8),
                                Text("Revizyon İste"),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _approvePlan, // 👈 Loading sırasında devre dışı
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _isSaving
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text("Kaydediliyor..."),
                                    ],
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.check_circle_outline_rounded),
                                      SizedBox(width: 8),
                                      Text("Onayla ve Başla"),
                                    ],
                                  ),
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
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 20),
                    Text(
                      "Strateji güncelleniyor...\nEmirlerin işleniyor komutanım!",
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
      elevation: 4, // 👈 Gölge ekle
      color: Theme.of(context).cardColor, // 👈 Tam renk, opacity yok
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
                  ?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold, // 👈 Daha kalın yazı
                  ),
            ),
            const Divider(height: 24, thickness: 2), // 👈 Çizgi kalınlaştır
            Expanded(
              child: dailyPlan.schedule.isEmpty
                  ? Center(
                child: Text(
                  "Bugün dinlenme ve strateji gözden geçirme günü. Zihnini dinlendir, yarınki fethe hazırlan!",
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              )
                  : ListView.builder(
                itemCount: dailyPlan.schedule.length,
                itemBuilder: (context, index) {
                  final item = dailyPlan.schedule[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4), // 👈 Hafif arka plan
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.15), // 👈 İkon kutusu
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIconForTaskType(item.type),
                            size: 18,
                            color: Theme.of(context).colorScheme.primary, // 👈 Primary renk kullan
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.activity,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600, // 👈 Daha kalın
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.time,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.8), // 👈 Daha belirgin
                                ),
                              ),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Lütfen bir geri bildirim belirtin."),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
      return;
    }
    widget.onRevisionRequested("- $allFeedbacks");
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Column(
              children: _quickFeedbacks.map((feedback) {
                final isSelected = _selectedFeedbacks.contains(feedback);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilterChip(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      label: SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            feedback,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                      ),
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
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                return TextField(
                  controller: _textController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    label: SizedBox(
                      width: constraints.maxWidth - 32,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: const Text("Eklemek istediğin özel bir not var mı?"),
                      ),
                    ),
                  ),
                );
              },
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