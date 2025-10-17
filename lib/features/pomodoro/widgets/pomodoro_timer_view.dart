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
          // Jest: çift dokunuş ile başlat/duraklat
          Expanded(
            child: GestureDetector(
              onDoubleTap: pomodoro.isPaused ? notifier.start : notifier.pause,
              onLongPress: () => _showSettingsSheet(context, ref),
              child: _TimerDial(pomodoro: pomodoro, color: progressColor),
            ),
          ),
          _buildControls(context, pomodoro, notifier, ref),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title, String message, PomodoroModel pomodoro, WidgetRef ref) {
    final endTime = DateTime.now().add(Duration(seconds: pomodoro.timeRemaining));
    final endStr = DateFormat('HH:mm').format(endTime);
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(message, style: const TextStyle(color: AppTheme.secondaryTextColor, fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        ActionChip(
          avatar: const Icon(Icons.assignment_outlined, size: 18),
          label: Text(pomodoro.currentTask, overflow: TextOverflow.ellipsis),
          onPressed: () => _showTaskSelectionSheet(context, ref),
        ),
        const SizedBox(height: 6),
        Text("Bitiş: $endStr", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
        const SizedBox(height: 8),
        Text("Tur: ${pomodoro.currentRound} / ${pomodoro.longBreakInterval}",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor)),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildControls(BuildContext context, PomodoroModel pomodoro, PomodoroNotifier notifier, WidgetRef ref) {
    final onBreak = pomodoro.sessionState == PomodoroSessionState.shortBreak || pomodoro.sessionState == PomodoroSessionState.longBreak;
    final canPromptReset = pomodoro.sessionState != PomodoroSessionState.idle;
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
              onPressed: () => _confirmAndReset(context, notifier, prompt: canPromptReset),
              icon: const Icon(Icons.replay_rounded),
              style: IconButton.styleFrom(backgroundColor: AppTheme.lightSurfaceColor.withOpacity(0.5)),
            ),
          ],
        ),
        if (onBreak)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton.icon(
              onPressed: notifier.skipBreakAndStartWork,
              icon: const Icon(Icons.skip_next_rounded, color: AppTheme.secondaryColor),
              label: const Text("Molayı atla ve çalışmaya başla", style: TextStyle(color: AppTheme.secondaryColor)),
            ),
          ),
        if(pomodoro.sessionState == PomodoroSessionState.work && pomodoro.currentTaskIdentifier != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
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
          ),
        const SizedBox(height: 8),
        const Text('İpucu: Zamanlayıcıya çift dokunarak başlat/duraklat, uzun basarak ayarlara aç.', style: TextStyle(fontSize: 12, color: AppTheme.secondaryTextColor)),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Future<void> _confirmAndReset(BuildContext context, PomodoroNotifier notifier, {bool prompt = false}) async {
    if (!prompt) {
      notifier.reset();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sıfırla'),
        content: const Text('Mevcut ilerleme sıfırlanacak. Devam edilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sıfırla')),
        ],
      ),
    ) ?? false;
    if (ok) notifier.reset();
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
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Yeni görev...'),
                onTap: () => Navigator.of(context).pop((task: '__CUSTOM__', identifier: '__CUSTOM__')),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedTask != null) {
      // Özel görev akışı
      if (selectedTask.task == '__CUSTOM__' && selectedTask.identifier == '__CUSTOM__') {
        final text = await _promptForCustomTask(context);
        if (text != null && text.trim().isNotEmpty) {
          final dateKey = dateKeyForSelection ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
          ref.read(pomodoroProvider.notifier).setTask(task: text.trim(), identifier: null, dateKey: dateKey);
        }
        return;
      }
      // Tarih anahtarını her durumda bugüne ayarla; weekly plan varsa yukarıda üretildi
      final dateKey = dateKeyForSelection ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      ref.read(pomodoroProvider.notifier).setTask(task: selectedTask.task, identifier: selectedTask.identifier, dateKey: dateKey);
    }
  }

  Future<String?> _promptForCustomTask(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni görev'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(hintText: 'Görev adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Ekle')),
        ],
      ),
    );
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
    final endTime = DateTime.now().add(Duration(seconds: pomodoro.timeRemaining));
    final endStr = DateFormat('HH:mm').format(endTime);

    final interval = pomodoro.longBreakInterval.clamp(1, 12);
    final completedInCycle = ((pomodoro.currentRound - 1) % interval).clamp(0, interval - 1);

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
            interval: interval,
            completedInCycle: completedInCycle,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$minutes:$seconds', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 6),
                Text('Bitiş: $endStr', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor)),
              ],
            ),
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
  final int interval;
  final int completedInCycle;
  _DialPainter({required this.progress, required this.color, required this.isPaused, required this.interval, required this.completedInCycle});

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

    // Tur noktaları
    const dotRadius = 6.0;
    final dotDistance = radius - 8;
    for (int i = 0; i < interval; i++) {
      final angle = -pi / 2 + 2 * pi * (i / interval);
      final dx = center.dx + cos(angle) * dotDistance;
      final dy = center.dy + sin(angle) * dotDistance;
      final paint = Paint()
        ..color = i < completedInCycle ? color : AppTheme.lightSurfaceColor.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dx, dy), dotRadius, paint);
      // Dış hat
      final stroke = Paint()
        ..color = Colors.black.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(Offset(dx, dy), dotRadius, stroke);
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