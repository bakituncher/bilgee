// lib/features/pomodoro/widgets/pomodoro_timer_view.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/models/plan_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/shared/widgets/score_slider.dart';
import 'package:intl/intl.dart';
import '../logic/pomodoro_notifier.dart';

class PomodoroTimerView extends ConsumerWidget {
  const PomodoroTimerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pomodoro = ref.watch(pomodoroProvider);
    final notifier = ref.read(pomodoroProvider.notifier);

    final (title, progressColor, message) = switch (pomodoro.sessionState) {
      PomodoroSessionState.work => ("Odaklanma Modu", AppTheme.secondaryColor, "Yaratım anındasın. Evren sessiz."),
      PomodoroSessionState.shortBreak => ("Kısa Mola", AppTheme.successColor, "Nefes al. Zihnin berraklaşsın."),
      PomodoroSessionState.longBreak => ("Uzun Mola", AppTheme.successColor, "Harika iş! Zihinsel bir yolculuğa çık."),
      _ => ("Beklemede", AppTheme.lightSurfaceColor, "Mabet seni bekliyor."),
    };

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(height: 50),
          _buildHeader(context, title, message, pomodoro, ref),
          Expanded(child: _TimerDial(pomodoro: pomodoro, color: progressColor)),
          _buildControls(context, pomodoro, notifier, ref),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title, String message, PomodoroModel pomodoro, WidgetRef ref) {
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(message, style: TextStyle(color: AppTheme.secondaryTextColor, fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        ActionChip(
          avatar: const Icon(Icons.assignment_outlined, size: 18),
          label: Text(pomodoro.currentTask, overflow: TextOverflow.ellipsis),
          onPressed: () => _showTaskSelectionSheet(context, ref),
        ),
        const SizedBox(height: 8),
        Text("Tur: ${pomodoro.currentRound} / ${pomodoro.longBreakInterval}",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor)),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildControls(BuildContext context, PomodoroModel pomodoro, PomodoroNotifier notifier, WidgetRef ref) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filled(
              onPressed: () => _showSettingsSheet(context, ref),
              icon: const Icon(Icons.settings),
              style: IconButton.styleFrom(backgroundColor: AppTheme.lightSurfaceColor.withOpacity(0.5)),
            ),
            const SizedBox(width: 20),
            IconButton.filled(
              iconSize: 56,
              onPressed: pomodoro.isPaused ? notifier.start : notifier.pause,
              icon: Icon(pomodoro.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            ),
            const SizedBox(width: 20),
            IconButton.filled(
              onPressed: notifier.reset,
              icon: const Icon(Icons.replay_rounded),
              style: IconButton.styleFrom(backgroundColor: AppTheme.lightSurfaceColor.withOpacity(0.5)),
            ),
          ],
        ),
        if(pomodoro.sessionState == PomodoroSessionState.work && pomodoro.currentTaskIdentifier != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: TextButton.icon(
                onPressed: (){
                  notifier.markTaskAsCompleted();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("'${pomodoro.currentTask}' tamamlandı olarak işaretlendi!"), backgroundColor: AppTheme.successColor),
                  );
                },
                icon: const Icon(Icons.check_circle, color: AppTheme.successColor),
                label: Text("'${pomodoro.currentTask}' görevini tamamla", style: const TextStyle(color: AppTheme.successColor))
            ),
          )
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Future<void> _showTaskSelectionSheet(BuildContext context, WidgetRef ref) async {
    final user = ref.read(userProfileProvider).value;
    final planDoc = ref.read(planProvider).value;
    final weeklyPlan = planDoc?.weeklyPlan != null ? WeeklyPlan.fromJson(planDoc!.weeklyPlan!) : null;

    final List<({String task, String? identifier})> tasks = [
      (task: "Genel Çalışma", identifier: null),
    ];

    if (user != null && weeklyPlan != null) {
      final today = DateTime.now();
      final todayName = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'][today.weekday - 1];
      final dateKey = DateFormat('yyyy-MM-dd').format(today);

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
              )).toList(),
            ],
          ),
        ),
      ),
    );

    if (selectedTask != null) {
      ref.read(pomodoroProvider.notifier).setTask(task: selectedTask.task, identifier: selectedTask.identifier);
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
      PomodoroSessionState.work => pomodoro.workDuration,
      PomodoroSessionState.shortBreak => pomodoro.shortBreakDuration,
      PomodoroSessionState.longBreak => pomodoro.longBreakDuration,
      _ => pomodoro.workDuration,
    };
    final time = Duration(seconds: pomodoro.timeRemaining);
    final minutes = time.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = time.inSeconds.remainder(60).toString().padLeft(2, '0');
    final progress = totalDuration > 0 ? pomodoro.timeRemaining / totalDuration : 1.0;

    return Animate(
      target: pomodoro.isPaused ? 1 : 0,
      effects: [ScaleEffect(duration: 400.ms, curve: Curves.easeOutBack, begin: const Offset(1,1), end: const Offset(0.9, 0.9))],
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _DialPainter(
            progress: 1 - progress,
            color: color,
            isPaused: pomodoro.isPaused,
          ),
          child: Center(
            child: Text('$minutes:$seconds', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2)),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isPaused;
  _DialPainter({required this.progress, required this.color, required this.isPaused});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final backgroundPaint = Paint()
      ..color = AppTheme.lightSurfaceColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, radius, backgroundPaint);

    if (progress > 0.0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          colors: [color.withOpacity(0.5), color],
          startAngle: -pi / 2,
          transform: const GradientRotation(-pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, progressPaint);
    }

    final breath = sin(DateTime.now().millisecondsSinceEpoch / (isPaused ? 2000 : 500)) * 5;
    final breathPaint = Paint()
      ..color = color.withOpacity(isPaused ? 0.05 : 0.1)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, radius - 20 + breath, breathPaint);
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) => true;
}


class PomodoroSettingsSheet extends ConsumerStatefulWidget {
  const PomodoroSettingsSheet({super.key});

  @override
  ConsumerState<PomodoroSettingsSheet> createState() => _PomodoroSettingsSheetState();
}

class _PomodoroSettingsSheetState extends ConsumerState<PomodoroSettingsSheet> {
  late double _work, _short, _long, _interval;

  @override
  void initState() {
    super.initState();
    final pomodoro = ref.read(pomodoroProvider);
    _work = (pomodoro.workDuration / 60).roundToDouble();
    _short = (pomodoro.shortBreakDuration / 60).roundToDouble();
    _long = (pomodoro.longBreakDuration / 60).roundToDouble();
    _interval = pomodoro.longBreakInterval.toDouble();
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
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: (){
                  ref.read(pomodoroProvider.notifier).updateSettings(
                    work: _work.toInt(),
                    short: _short.toInt(),
                    long: _long.toInt(),
                    interval: _interval.toInt(),
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