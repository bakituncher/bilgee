import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/models/plan_document.dart';
import 'package:taktik/features/strategic_planning/screens/strategic_planning_screen.dart';

// State to hold the temporary plan while editing
final editablePlanProvider = StateProvider.autoDispose<WeeklyPlan?>((ref) => null);

class EditablePlanScreen extends ConsumerStatefulWidget {
  final WeeklyPlan initialPlan;
  final bool isPreview; // If true, we are in the flow (not saved yet). If false, we are editing an existing plan.

  const EditablePlanScreen({super.key, required this.initialPlan, required this.isPreview});

  @override
  ConsumerState<EditablePlanScreen> createState() => _EditablePlanScreenState();
}

class _EditablePlanScreenState extends ConsumerState<EditablePlanScreen> {
  late WeeklyPlan _currentPlan;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.initialPlan;
  }

  void _updatePlan(WeeklyPlan newPlan) {
    setState(() {
      _currentPlan = newPlan;
    });
  }

  void _moveTask(int fromDayIndex, int itemIndex, int toDayIndex) {
    // Create deep copies to avoid mutating state directly (though simpler here)
    final newDailyPlans = List<DailyPlan>.from(_currentPlan.plan);

    final fromDay = newDailyPlans[fromDayIndex];
    final itemToMove = fromDay.schedule[itemIndex];

    // Remove from source
    final newSourceSchedule = List<ScheduleItem>.from(fromDay.schedule);
    newSourceSchedule.removeAt(itemIndex);
    newDailyPlans[fromDayIndex] = DailyPlan(
      day: fromDay.day,
      schedule: newSourceSchedule,
      rawScheduleString: fromDay.rawScheduleString
    );

    // Add to target
    final toDay = newDailyPlans[toDayIndex];
    final newTargetSchedule = List<ScheduleItem>.from(toDay.schedule);
    newTargetSchedule.add(itemToMove);
    // Optional: Sort by time if times are parsable, but AI often gives loose times.
    // For now, append to end.

    newDailyPlans[toDayIndex] = DailyPlan(
      day: toDay.day,
      schedule: newTargetSchedule,
      rawScheduleString: toDay.rawScheduleString
    );

    _updatePlan(WeeklyPlan(
      planTitle: _currentPlan.planTitle,
      strategyFocus: _currentPlan.strategyFocus,
      plan: newDailyPlans,
      creationDate: _currentPlan.creationDate,
    ));
  }

  void _deleteTask(int dayIndex, int itemIndex) {
    final newDailyPlans = List<DailyPlan>.from(_currentPlan.plan);
    final day = newDailyPlans[dayIndex];
    final newSchedule = List<ScheduleItem>.from(day.schedule);
    newSchedule.removeAt(itemIndex);

    newDailyPlans[dayIndex] = DailyPlan(
      day: day.day,
      schedule: newSchedule,
      rawScheduleString: day.rawScheduleString
    );

    _updatePlan(WeeklyPlan(
      planTitle: _currentPlan.planTitle,
      strategyFocus: _currentPlan.strategyFocus,
      plan: newDailyPlans,
      creationDate: _currentPlan.creationDate,
    ));
  }

  Future<void> _savePlan() async {
    setState(() => _isSaving = true);
    try {
      final user = ref.read(userProfileProvider).value;
      if (user == null) return;

      final planMap = {
        'planTitle': _currentPlan.planTitle,
        'strategyFocus': _currentPlan.strategyFocus,
        'creationDate': _currentPlan.creationDate.toIso8601String(),
        'plan': _currentPlan.plan.map((d) => {
          'day': d.day,
          'schedule': d.schedule.map((s) => {
            'time': s.time,
            'activity': s.activity,
            'type': s.type,
          }).toList(),
          'rawScheduleString': d.rawScheduleString,
        }).toList(),
      };

      await ref.read(firestoreServiceProvider).saveWeeklyPlan(user.id, planMap);

      // Invalidate providers to refresh UI
      ref.invalidate(planProvider);
      ref.read(planningStepProvider.notifier).state = PlanningStep.dataCheck; // Reset flow

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan kaydedildi!")));
        if (widget.isPreview) {
          // Navigate to home or plan view
           context.go('/home/weekly-plan');
        } else {
           context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPreview ? "Planını Düzenle & Onayla" : "Planı Düzenle"),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePlan,
            child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("KAYDET", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Görevlerin üzerine basılı tutarak silebilir veya tıklayarak başka güne taşıyabilirsin.",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _currentPlan.plan.length,
              itemBuilder: (context, dayIndex) {
                final dailyPlan = _currentPlan.plan[dayIndex];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ExpansionTile(
                    initiallyExpanded: true, // Expand all by default for overview
                    title: Text(
                      dailyPlan.day,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    children: [
                      if (dailyPlan.schedule.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("Bu gün için planlanmış görev yok.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                        )
                      else
                        ...List.generate(dailyPlan.schedule.length, (itemIndex) {
                          final item = dailyPlan.schedule[itemIndex];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getTypeColor(item.type, context).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_getTypeIcon(item.type), color: _getTypeColor(item.type, context), size: 20),
                            ),
                            title: Text(item.activity, style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text(item.time, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () => _showEditMenu(context, dayIndex, itemIndex, item),
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEditMenu(BuildContext context, int dayIndex, int itemIndex, ScheduleItem item) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(item.activity, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Ne yapmak istersin?"),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text("Görevi Sil", style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteTask(dayIndex, itemIndex);
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: const Text("Başka Güne Taşı"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showMoveDialog(context, dayIndex, itemIndex);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMoveDialog(BuildContext context, int currentDayIndex, int itemIndex) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Hangi güne taşıyalım?"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _currentPlan.plan.length,
              itemBuilder: (context, i) {
                if (i == currentDayIndex) return const SizedBox.shrink(); // Don't move to same day
                return ListTile(
                  title: Text(_currentPlan.plan[i].day),
                  onTap: () {
                    Navigator.pop(ctx);
                    _moveTask(currentDayIndex, itemIndex, i);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Color _getTypeColor(String type, BuildContext context) {
    switch (type.toLowerCase()) {
      case 'study': return Colors.blue;
      case 'test': return Colors.orange;
      case 'video': return Colors.purple;
      case 'rest': return Colors.green;
      default: return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'study': return Icons.book;
      case 'test': return Icons.assignment;
      case 'video': return Icons.play_circle_outline;
      case 'rest': return Icons.spa;
      default: return Icons.task_alt;
    }
  }
}
