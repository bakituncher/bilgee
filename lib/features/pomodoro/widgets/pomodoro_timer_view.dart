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
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // Başlık ve alt mesaj
        Text(title, style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(message, style: const TextStyle(color: AppTheme.secondaryTextColor, fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        // Bilgi chipleri
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.assignment_outlined, size: 18),
              label: Text(pomodoro.currentTask, overflow: TextOverflow.ellipsis),
              onPressed: () => _showTaskSelectionSheet(context, ref),
            ),
            Chip(
              avatar: const Icon(Icons.schedule_rounded, size: 18),
              label: Text("Bitiş: $endStr"),
            ),
            Chip(
              avatar: const Icon(Icons.flag_rounded, size: 18),
              label: Text("Tur: ${pomodoro.currentRound} / ${pomodoro.longBreakInterval}"),
            ),
          ],
        ).animate().fadeIn(duration: 500.ms),
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

class _TimerDial extends StatefulWidget {
  final PomodoroModel pomodoro;
  final Color color;
  const _TimerDial({required this.pomodoro, required this.color});

  @override
  State<_TimerDial> createState() => _TimerDialState();
}

class _TimerDialState extends State<_TimerDial> with SingleTickerProviderStateMixin {
  late final AnimationController _rotCtrl;
  double _lastProgress = 0.0; // 0..1 artan ilerleme

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _lastProgress = _computeProgress(widget.pomodoro);
  }

  @override
  void didUpdateWidget(covariant _TimerDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    // yeni hedef progress’i izle, TweenAnimationBuilder kullanıldığı için sadece referans olarak tutuyoruz
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    super.dispose();
  }

  double _computeProgress(PomodoroModel pomodoro) {
    final total = switch (pomodoro.sessionState) {
      PomodoroSessionState.idle => pomodoro.workDuration,
      _ => pomodoro.activeSessionTotalDuration,
    };
    if (total <= 0) return 0.0;
    final remainingRatio = pomodoro.timeRemaining / total;
    return (1 - remainingRatio).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final pomodoro = widget.pomodoro;
    final time = Duration(seconds: pomodoro.timeRemaining);
    final minutes = time.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = time.inSeconds.remainder(60).toString().padLeft(2, '0');

    final targetProgress = _computeProgress(pomodoro);

    // Son 10 saniye pulse efekti
    final isFinalCountdown = pomodoro.timeRemaining <= 10 &&
        (pomodoro.sessionState == PomodoroSessionState.work || pomodoro.sessionState == PomodoroSessionState.shortBreak || pomodoro.sessionState == PomodoroSessionState.longBreak);

    return Animate(
      target: pomodoro.isPaused ? 1 : 0,
      effects: [ScaleEffect(duration: 400.ms, curve: Curves.easeOutBack, begin: const Offset(1,1), end: const Offset(0.9, 0.9))],
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: _lastProgress, end: targetProgress),
              duration: const Duration(milliseconds: 950),
              curve: Curves.easeInOutCubic,
              onEnd: () => _lastProgress = targetProgress,
              builder: (context, animatedProgress, _) {
                return CustomPaint(
                  painter: _DialPainter(
                    progress: animatedProgress,
                    color: widget.color,
                    isPaused: pomodoro.isPaused,
                    interval: pomodoro.longBreakInterval.clamp(1, 12),
                    completedInCycle: ((pomodoro.currentRound - 1) % pomodoro.longBreakInterval.clamp(1, 12)).clamp(0, pomodoro.longBreakInterval.clamp(1, 12) - 1),
                    rotationAngle: (_rotCtrl.value * 2 * pi),
                    finalPulse: isFinalCountdown ? (1 + (sin(DateTime.now().millisecondsSinceEpoch / 120) * 0.04)) : 1.0,
                  ),
                );
              },
            ),
            // Merkez metin ve mini bilgi
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$minutes:$seconds', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  // küçük ipucu
                  Opacity(
                    opacity: 0.8,
                    child: Text(
                      pomodoro.isPaused ? 'Çift dokun: Başlat' : 'Çift dokun: Duraklat',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double progress; // 0..1 artan
  final Color color;
  final bool isPaused;
  final int interval;
  final int completedInCycle;
  final double rotationAngle; // degrade dönüşü
  final double finalPulse; // son 10 sn nabız
  _DialPainter({required this.progress, required this.color, required this.isPaused, required this.interval, required this.completedInCycle, required this.rotationAngle, required this.finalPulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Arkaplan çemberi
    final backgroundPaint = Paint()
      ..color = AppTheme.lightSurfaceColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, radius, backgroundPaint);

    if (progress > 0.0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.6),
            color,
            color.withOpacity(0.6),
          ],
          stops: const [0.0, 0.3, 0.6, 1.0],
          startAngle: -pi / 2 + rotationAngle,
          endAngle: (3 * pi / 2) + rotationAngle,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16 * finalPulse
        ..strokeCap = StrokeCap.round;

      // Glow katmanı
      final glowPaint = Paint()
        ..color = color.withOpacity(isPaused ? 0.08 : 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22 * finalPulse
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);

      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, glowPaint);
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
      final stroke = Paint()
        ..color = Colors.black.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(Offset(dx, dy), dotRadius, stroke);
    }

    // Nefes/pulse arka katman
    final breath = sin(DateTime.now().millisecondsSinceEpoch / (isPaused ? 2000 : 700)) * 5;
    final breathPaint = Paint()
      ..color = color.withOpacity(isPaused ? 0.05 : 0.1)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, (radius - 20 + breath) * finalPulse, breathPaint);
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
    final totalCycle = '${_work.toInt()} / ${_short.toInt()} / ${_long.toInt()} dk';
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
            const SizedBox(height: 8),
            Text('Presetler', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.secondaryTextColor)),
            const SizedBox(height: 8),
            _QuickPresets(
              onPick: (w, s, l, i){
                setState((){
                  _work = w; _short = s; _long = l; _interval = i;
                });
              },
            ),
            const SizedBox(height: 8),
            Text('Mevcut: $totalCycle • Uzun mola aralığı: ${_interval.toInt()} tur', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
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

class _QuickPresets extends StatefulWidget {
  final void Function(double work, double short, double long, double interval) onPick;
  const _QuickPresets({required this.onPick});

  @override
  State<_QuickPresets> createState() => _QuickPresetsState();
}

class _QuickPresetsState extends State<_QuickPresets> {
  int _selected = -1;
  @override
  Widget build(BuildContext context) {
    final presets = <({String label, List<double> vals})>[
      (label: '25/5/15 • Klasik', vals: [25, 5, 15, 4]),
      (label: '50/10/20 • Derin', vals: [50, 10, 20, 3]),
      (label: '90/15/30 • Sprint', vals: [90, 15, 30, 2]),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < presets.length; i++)
          ChoiceChip(
            selected: _selected == i,
            label: Text(presets[i].label),
            onSelected: (v){
              setState(()=> _selected = v ? i : -1);
              if (v) {
                final p = presets[i].vals;
                widget.onPick(p[0], p[1], p[2], p[3]);
              }
            },
          )
      ],
    );
  }
}

