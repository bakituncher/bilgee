// lib/features/pomodoro/widgets/pomodoro_timer_view.dart
import 'dart:math';
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
    final theme = Theme.of(context);

    final (title, progressColor) = switch (pomodoro.sessionState) {
      PomodoroSessionState.work => ("Odaklanma", AppTheme.secondaryColor),
      PomodoroSessionState.shortBreak => ("Kısa Mola", AppTheme.successColor),
      PomodoroSessionState.longBreak => ("Uzun Mola", AppTheme.successColor),
      _ => ("Başlamaya Hazır", AppTheme.lightSurfaceColor),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // HEADER: GÖREV SEÇİMİ
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.assignment_outlined, size: 18),
                  label: Text(pomodoro.currentTask, overflow: TextOverflow.ellipsis),
                  onPressed: () => _showTaskSelectionSheet(context, ref),
                ),
                Text("Tur: ${pomodoro.currentRound} / ${pomodoro.longBreakInterval}",
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor),
                ),
              ],
            ),
          ),

          // ZAMANLAYICI
          Expanded(
            child: _TimerDial(
              pomodoro: pomodoro,
              color: progressColor,
              title: title,
            ),
          ),

          // KONTROLLER
          _buildControls(context, pomodoro, notifier, ref),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, PomodoroModel pomodoro, PomodoroNotifier notifier, WidgetRef ref) {
    final onBreak = pomodoro.sessionState == PomodoroSessionState.shortBreak || pomodoro.sessionState == PomodoroSessionState.longBreak;
    final canCompleteTask = pomodoro.sessionState == PomodoroSessionState.work && pomodoro.currentTaskIdentifier != null;

    Widget bottomButton;
    if (onBreak) {
      bottomButton = TextButton.icon(
        key: const ValueKey('skip'),
        onPressed: notifier.skipBreakAndStartWork,
        icon: const Icon(Icons.skip_next_rounded),
        label: const Text("Molayı Atla"),
      );
    } else if (canCompleteTask) {
      bottomButton = TextButton.icon(
        key: const ValueKey('complete'),
        style: TextButton.styleFrom(foregroundColor: AppTheme.successColor),
        onPressed: () {
          notifier.markTaskAsCompleted();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("'${pomodoro.currentTask}' tamamlandı olarak işaretlendi!"),
              backgroundColor: AppTheme.successColor,
            ),
          );
        },
        icon: const Icon(Icons.check_circle_outline),
        label: Text("'${pomodoro.currentTask}' görevini tamamla"),
      );
    } else {
      bottomButton = const SizedBox(key: ValueKey('placeholder'), height: 48);
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AYARLAR
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: "Ayarlar",
              onPressed: () => _showSettingsSheet(context, ref),
              style: IconButton.styleFrom(
                foregroundColor: AppTheme.secondaryTextColor,
                side: BorderSide(color: AppTheme.lightSurfaceColor.withOpacity(0.2)),
              ),
            ),
            const SizedBox(width: 16),
            // OYNAT / DURDUR
            IconButton.filled(
              iconSize: 52,
              onPressed: pomodoro.isPaused ? notifier.start : notifier.pause,
              icon: Icon(pomodoro.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            // YENİLE
            IconButton(
              icon: const Icon(Icons.replay_rounded),
              tooltip: "Sıfırla",
              onPressed: notifier.reset,
               style: IconButton.styleFrom(
                foregroundColor: AppTheme.secondaryTextColor,
                side: BorderSide(color: AppTheme.lightSurfaceColor.withOpacity(0.2)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: 300.ms,
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, child: child)),
          child: bottomButton,
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
  final String title;
  const _TimerDial({required this.pomodoro, required this.color, required this.title});

  @override
  Widget build(BuildContext context) {
    final totalDuration = pomodoro.activeSessionTotalDuration;
    final time = Duration(seconds: pomodoro.timeRemaining);
    final minutes = time.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = time.inSeconds.remainder(60).toString().padLeft(2, '0');
    final progress = totalDuration > 0 ? pomodoro.timeRemaining / totalDuration : 1.0;

    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _DialPainter(
          progress: 1 - progress,
          color: color,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
              const SizedBox(height: 8),
              Text('$minutes:$seconds', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 6),
              Text(
                pomodoro.isPaused ? "Duraklatıldı" : "Bitiş: ${DateFormat('HH:mm').format(DateTime.now().add(time))}",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor)
              ),
            ],
          ).animate().fadeIn(duration: 400.ms),
        ),
      ),
    ).animate(target: pomodoro.isPaused ? 1: 0).scale(
      begin: const Offset(1,1), end: const Offset(0.95, 0.95),
      duration: 400.ms, curve: Curves.easeOutCubic,
    );
  }
}

class _DialPainter extends CustomPainter {
  final double progress;
  final Color color;
  _DialPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.9;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Arka plan çizgisi
    final backgroundPaint = Paint()
      ..color = AppTheme.lightSurfaceColor.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius, backgroundPaint);

    // İlerleme çizgisi
    if (progress > 0.0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          colors: [color.withOpacity(0.5), color],
          startAngle: -pi / 2,
          endAngle: -pi/2 + 2*pi*progress,
          transform: const GradientRotation(-pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, progressPaint);
    }

    // Nefes efekti
    final breath = sin(DateTime.now().millisecondsSinceEpoch / 800) * 8;
    final breathPaint = Paint()
      ..color = color.withOpacity(0.05)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
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
            ),
            SwitchListTile.adaptive(
              value: _autoStartWork,
              onChanged: (v) => setState(() => _autoStartWork = v),
              title: const Text('Mola bitince çalışmayı otomatik başlat'),
            ),
            SwitchListTile.adaptive(
              value: _keepScreenOn,
              onChanged: (v) => setState(() => _keepScreenOn = v),
              title: const Text('Zamanlayıcı sırasında ekranı açık tut'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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
