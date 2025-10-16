// lib/features/pomodoro/widgets/pomodoro_timer_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/shared/widgets/score_slider.dart';
import 'package:intl/intl.dart';
import '../logic/pomodoro_notifier.dart';

class PomodoroTimerView extends ConsumerWidget {
  const PomodoroTimerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pomodoro = ref.watch(pomodoroProvider);
    final notifier = ref.read(pomodoroProvider.notifier);

    final (title, progressColor) = switch (pomodoro.sessionState) {
      PomodoroSessionState.work => ("Odaklanma", AppTheme.secondaryColor),
      PomodoroSessionState.shortBreak => ("Kısa Mola", AppTheme.successColor),
      PomodoroSessionState.longBreak => ("Uzun Mola", AppTheme.successColor),
      _ => ("Beklemede", AppTheme.lightSurfaceColor),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const Spacer(),
          _buildHeader(context, title, pomodoro, ref),
          Expanded(
            flex: 4,
            child: _TimerDial(pomodoro: pomodoro, color: progressColor),
          ),
          Expanded(
            flex: 3,
            child: _buildControls(context, pomodoro, notifier, ref),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title, PomodoroModel pomodoro, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ActionChip(
          avatar: const Icon(Icons.assignment_turned_in_outlined, size: 18),
          label: Text(pomodoro.currentTask.isEmpty ? "Genel Çalışma" : pomodoro.currentTask, overflow: TextOverflow.ellipsis),
          onPressed: () => _showTaskSelectionSheet(context, ref),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildControls(BuildContext context, PomodoroModel pomodoro, PomodoroNotifier notifier, WidgetRef ref) {
    final onBreak = pomodoro.sessionState == PomodoroSessionState.shortBreak || pomodoro.sessionState == PomodoroSessionState.longBreak;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => _showSettingsSheet(context, ref),
              icon: const Icon(Icons.settings_outlined),
              iconSize: 28,
              color: AppTheme.secondaryTextColor,
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.5),
            const SizedBox(width: 24),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                fixedSize: const Size(80, 80),
              ),
              iconSize: 48,
              onPressed: pomodoro.isPaused ? notifier.start : notifier.pause,
              icon: AnimatedSwitcher(
                duration: 300.ms,
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Icon(
                  pomodoro.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  key: ValueKey<bool>(pomodoro.isPaused),
                ),
              ),
            ).animate().scale(delay: 100.ms, duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(width: 24),
            IconButton(
              onPressed: notifier.reset,
              icon: const Icon(Icons.replay_rounded),
              iconSize: 28,
              color: AppTheme.secondaryTextColor,
            ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.5),
          ],
        ),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: 300.ms,
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: onBreak
              ? TextButton.icon(
                  onPressed: notifier.skipBreakAndStartWork,
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text("Molayı Atla"),
                )
              : (pomodoro.currentTaskIdentifier != null
                  ? TextButton.icon(
                      onPressed: () {
                        notifier.markTaskAsCompleted();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("'${pomodoro.currentTask}' tamamlandı!"), backgroundColor: AppTheme.successColor),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline, color: AppTheme.successColor),
                      label: Text("'${pomodoro.currentTask}' görevini tamamla", style: const TextStyle(color: AppTheme.successColor)),
                    )
                  : const SizedBox(height: 48)), // Placeholder to prevent layout jump
        ),
      ],
    );
  }

  Future<void> _showTaskSelectionSheet(BuildContext context, WidgetRef ref) async {
    final user = ref.read(userProfileProvider).value;
    final planDoc = ref.read(planProvider).value;
    final weeklyPlan = planDoc?.weeklyPlan != null ? WeeklyPlan.fromJson(planDoc!.weeklyPlan!) : null;

    final List<({String task, String? identifier})> tasks = [
      (task: "Genel Çalışma", identifier: null),
    ];

    String? dateKeyForSelection;

    if (user != null && weeklyPlan != null) {
      final today = DateTime.now();
      final todayName = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'][today.weekday - 1];
      final dateKey = DateFormat('yyyy-MM-dd').format(today);
      dateKeyForSelection = dateKey;

      final todayPlan = weeklyPlan.plan.firstWhere((day) => day.day == todayName, orElse: () => DailyPlan(day: todayName, schedule: []));
      final completedToday = ref.read(completedTasksForDateProvider(today)).maybeWhen(data: (list)=> list, orElse: ()=> const <String>[]);

      for (var item in todayPlan.schedule) {
        final identifier = '${item.time}-${item.activity}';
        final isCompleted = completedToday.contains(identifier);
        if (!isCompleted) {
          tasks.add((task: item.activity, identifier: identifier));
        }
      }
    }

    final selectedTask = await showModalBottomSheet<({String task, String? identifier})>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Bugünkü Görevler", style: Theme.of(context).textTheme.headlineSmall),
              ),
              ...tasks.map((task) => ListTile(
                leading: Icon(task.identifier == null ? Icons.workspaces_outline : Icons.checklist_rtl_rounded),
                title: Text(task.task, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.of(context).pop(task),
              )),
            ],
          ),
        ),
      ),
    );

    if (selectedTask != null) {
      final dateKey = dateKeyForSelection ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      ref.read(pomodoroProvider.notifier).setTask(task: selectedTask.task, identifier: selectedTask.identifier, dateKey: dateKey);
    }
  }

  Future<void> _showSettingsSheet(BuildContext context, WidgetRef ref) async {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const PomodoroSettingsSheet()
    );
  }
}

class _TimerDial extends StatelessWidget {
  final PomodoroModel pomodoro;
  final Color color;
  const _TimerDial({required this.pomodoro, required this.color});

  @override
  Widget build(BuildContext context) {
    final totalDuration = switch (pomodoro.sessionState) {
      PomodoroSessionState.idle => pomodoro.workDuration,
      _ => pomodoro.activeSessionTotalDuration,
    };
    final time = Duration(seconds: pomodoro.timeRemaining);
    final minutes = time.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = time.inSeconds.remainder(60).toString().padLeft(2, '0');
    final progress = totalDuration > 0 ? pomodoro.timeRemaining / totalDuration : 1.0;

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 8,
              color: AppTheme.lightSurfaceColor.withOpacity(0.15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: AnimatedSwitcher(
              duration: 500.ms,
              child: CircularProgressIndicator(
                key: ValueKey(color),
                value: progress,
                strokeWidth: 8,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$minutes:$seconds',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 4),
                ).animate(target: pomodoro.isPaused ? 0.95 : 1.0)
                 .scale(duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 8),
                Text(
                  "Tur ${pomodoro.currentRound} / ${pomodoro.longBreakInterval}",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutCubic);
  }
}


class PomodoroSettingsSheet extends ConsumerStatefulWidget {
  const PomodoroSettingsSheet({super.key});

  @override
  ConsumerState<PomodoroSettingsSheet> createState() => _PomodoroSettingsSheetState();
}

class _PomodoroSettingsSheetState extends ConsumerState<PomodoroSettingsSheet> {
  late double _work, _short, _long, _interval;
  late bool _autoStartBreaks, _autoStartWork, _keepScreenOn;

  @override
  void initState() {
    super.initState();
    final pomodoro = ref.read(pomodoroProvider);
    _work = (pomodoro.workDuration / 60).roundToDouble();
    _short = (pomodoro.shortBreakDuration / 60).roundToDouble();
    _long = (pomodoro.longBreakDuration / 60).roundToDouble();
    _interval = pomodoro.longBreakInterval.toDouble();
    _autoStartBreaks = pomodoro.autoStartBreaks;
    _autoStartWork = pomodoro.autoStartWork;
    _keepScreenOn = pomodoro.keepScreenOn;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Zaman Ayarları", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            ScoreSlider(label: "Odaklanma (dk)", value: _work, max: 60, color: AppTheme.secondaryColor, onChanged: (v) => setState(() => _work = v.roundToDouble())),
            ScoreSlider(label: "Kısa Mola (dk)", value: _short, max: 15, color: AppTheme.successColor, onChanged: (v) => setState(() => _short = v.roundToDouble())),
            ScoreSlider(label: "Uzun Mola (dk)", value: _long, max: 30, color: AppTheme.successColor, onChanged: (v) => setState(() => _long = v.roundToDouble())),
            ScoreSlider(label: "Uzun Mola Aralığı (Tur)", value: _interval, max: 8, color: AppTheme.lightSurfaceColor, onChanged: (v) => setState(() => _interval = v.roundToDouble())),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: _autoStartBreaks,
              onChanged: (v) => setState(() => _autoStartBreaks = v),
              title: const Text('Çalışma bitince molayı otomatik başlat'),
              subtitle: const Text('Seans bittiğinde mola sayacı otomatik başlar'),
            ),
            SwitchListTile.adaptive(
              value: _autoStartWork,
              onChanged: (v) => setState(() => _autoStartWork = v),
              title: const Text('Mola bitince çalışmayı otomatik başlat'),
              subtitle: const Text('Mola tamamlanınca yeni tura otomatik geç'),
            ),
            SwitchListTile.adaptive(
              value: _keepScreenOn,
              onChanged: (v) => setState(() => _keepScreenOn = v),
              title: const Text('Zamanlayıcı sırasında ekranı açık tut'),
              subtitle: const Text('Yanıp sönmeden, kapanmadan sürekli açık kalsın'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: (){
                  ref.read(pomodoroProvider.notifier).updateSettings(
                    work: _work.toInt(),
                    short: _short.toInt(),
                    long: _long.toInt(),
                    interval: _interval.toInt(),
                    applyToCurrent: true,
                  );
                  ref.read(pomodoroProvider.notifier).updatePreferences(
                    autoStartBreaks: _autoStartBreaks,
                    autoStartWork: _autoStartWork,
                    keepScreenOn: _keepScreenOn,
                  );
                  Navigator.pop(context);
                },
                child: const Text("Kaydet")
            )
          ],
        ),
      ),
    );
  }
}