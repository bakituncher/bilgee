// lib/features/pomodoro/widgets/pomodoro_timer_view.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:intl/intl.dart';
import '../logic/pomodoro_notifier.dart';

class PomodoroTimerView extends ConsumerWidget {
  const PomodoroTimerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pomodoro = ref.watch(pomodoroProvider);
    final notifier = ref.read(pomodoroProvider.notifier);

    final colorScheme = Theme.of(context).colorScheme;
    final (title, progressColor, message) = switch (pomodoro.sessionState) {
      PomodoroSessionState.work => ("Odaklanma Modu", colorScheme.secondary, "Yaratım anındasın. Evren sessiz."),
      PomodoroSessionState.shortBreak => ("Kısa Mola", colorScheme.primary, "Nefes al. Zihnin berraklaşsın."),
      PomodoroSessionState.longBreak => ("Uzun Mola", colorScheme.primary, "Harika iş! Zihinsel bir yolculuğa çık."),
      _ => ("Beklemede", colorScheme.surfaceContainerHighest, "Mabet seni bekliyor."),
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
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
        ),
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
              style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)),
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
              style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)),
            ),
          ],
        ),
        if (onBreak)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton.icon(
              onPressed: notifier.skipBreakAndStartWork,
              icon: Icon(Icons.skip_next_rounded, color: Theme.of(context).colorScheme.secondary),
              label: Text("Molayı atla ve çalışmaya başla", style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
            ),
          ),
        if (pomodoro.sessionState == PomodoroSessionState.work && pomodoro.currentTaskIdentifier != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton.icon(
                onPressed: () {
                  notifier.markTaskAsCompleted();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("'${pomodoro.currentTask}' tamamlandı olarak işaretlendi!"),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                },
                icon: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                label: Text(
                  "'${pomodoro.currentTask}' görevini tamamla",
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                )),
          ),
        const SizedBox(height: 8),
        Text(
          'İpucu: Zamanlayıcıya çift dokunarak başlat/duraklat, uzun basarak ayarlara aç.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
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
  double _lastProgress = 0.0; // 0..1 artan

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
                return AnimatedBuilder(
                  animation: _rotCtrl,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _DialPainter(
                        progress: animatedProgress,
                        color: widget.color,
                        isPaused: pomodoro.isPaused,
                        interval: pomodoro.longBreakInterval.clamp(1, 12),
                        completedInCycle: ((pomodoro.currentRound - 1) % pomodoro.longBreakInterval.clamp(1, 12))
                            .clamp(0, pomodoro.longBreakInterval.clamp(1, 12) - 1),
                        rotationAngle: (_rotCtrl.value * 2 * pi),
                        finalPulse: isFinalCountdown ? (1 + (sin(_rotCtrl.value * 2 * pi * 10) * 0.04)) : 1.0,
                        colorScheme: Theme.of(context).colorScheme,
                      ),
                    );
                  },
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
  final ColorScheme colorScheme;
  _DialPainter(
      {required this.progress,
        required this.color,
        required this.isPaused,
        required this.interval,
        required this.completedInCycle,
        required this.rotationAngle,
        required this.finalPulse,
        required this.colorScheme});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Let's assume the color scheme is passed to the painter.
    final surfaceVariant = colorScheme.surfaceContainerHighest;
    final onSurface = colorScheme.onSurface;

    // Arkaplan çemberi
    final backgroundPaint = Paint()
      ..color = colorScheme.surfaceContainerHighest.withOpacity(0.2)
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
        ..color = i < completedInCycle ? color : colorScheme.surfaceContainerHighest.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dx, dy), dotRadius, paint);
      final stroke = Paint()
        ..color = colorScheme.onSurface.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(Offset(dx, dy), dotRadius, stroke);
    }

    // Nefes/pulse arka katman - rotationAngle kullanarak sürekli çizimi önle
    final breath = sin(rotationAngle * (isPaused ? 0.5 : 1.5)) * 5;
    final breathPaint = Paint()
      ..color = color.withOpacity(isPaused ? 0.05 : 0.1)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, (radius - 20 + breath) * finalPulse, breathPaint);
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.isPaused != isPaused ||
        oldDelegate.interval != interval ||
        oldDelegate.completedInCycle != completedInCycle ||
        oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.finalPulse != finalPulse;
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
    final totalCycle = '${_work.toInt()} / ${_short.toInt()} / ${_long.toInt()} dk • Aralık: ${_interval.toInt()} tur';
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Material(
          color: colorScheme.surface.withOpacity(0.98),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom + 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Grabber
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: colorScheme.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: Text("Zaman Ayarları", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
                        IconButton(
                          tooltip: 'Kapat',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(totalCycle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ),
                    const SizedBox(height: 16),
                    // Süreler kartı
                    _SettingsCard(
                      title: 'Süreler',
                      child: Column(
                        children: [
                          _ValueRow(
                            label: 'Odaklanma', unit: 'dk', value: _work, min: 10, max: 120, step: 5, color: colorScheme.secondary,
                            onChanged: (v) => setState(() => _work = v.roundToDouble()),
                          ),
                          const Divider(height: 12),
                          _ValueRow(
                            label: 'Kısa mola', unit: 'dk', value: _short, min: 3, max: 20, step: 1, color: colorScheme.primary,
                            onChanged: (v) => setState(() => _short = v.roundToDouble()),
                          ),
                          const Divider(height: 12),
                          _ValueRow(
                            label: 'Uzun mola', unit: 'dk', value: _long, min: 10, max: 45, step: 5, color: colorScheme.primary,
                            onChanged: (v) => setState(() => _long = v.roundToDouble()),
                          ),
                          const Divider(height: 12),
                          _ValueRow(
                            label: 'Uzun mola aralığı',
                            unit: 'tur',
                            value: _interval,
                            min: 2,
                            max: 8,
                            step: 1,
                            color: colorScheme.surfaceContainerHighest,
                            onChanged: (v) => setState(() => _interval = v.roundToDouble()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Otomasyon kartı
                    _SettingsCard(
                      title: 'Otomasyon',
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            value: _autoStartBreaks,
                            onChanged: (v) => setState(() => _autoStartBreaks = v),
                            title: const Text('Çalışma bitince molayı otomatik başlat'),
                            subtitle: const Text('Seans bittiğinde mola sayacı otomatik başlar'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 4),
                          SwitchListTile.adaptive(
                            value: _autoStartWork,
                            onChanged: (v) => setState(() => _autoStartWork = v),
                            title: const Text('Mola bitince çalışmayı otomatik başlat'),
                            subtitle: const Text('Mola tamamlanınca yeni tura otomatik geç'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 4),
                          SwitchListTile.adaptive(
                            value: _keepScreenOn,
                            onChanged: (v) => setState(() => _keepScreenOn = v),
                            title: const Text('Zamanlayıcı sırasında ekranı açık tut'),
                            subtitle: const Text('Yanıp sönmeden, kapanmadan sürekli açık kalsın'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Kaydet butonu
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_rounded),
                        onPressed: (){
                          ref.read(pomodoroProvider.notifier).updateSettings(
                            work: _work.toInt(), short: _short.toInt(), long: _long.toInt(), interval: _interval.toInt(), applyToCurrent: true,
                          );
                          ref.read(pomodoroProvider.notifier).updatePreferences(
                            autoStartBreaks: _autoStartBreaks, autoStartWork: _autoStartWork, keepScreenOn: _keepScreenOn,
                          );
                          Navigator.pop(context);
                        },
                        label: const Text('Kaydet'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Yeni: Bölüm kartı
class _SettingsCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SettingsCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          child,
        ],
      ),
    );
  }
}

// Yeni: Değer satırı + mini stepper
class _ValueRow extends StatelessWidget {
  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
  final double step;
  final Color color;
  final ValueChanged<double> onChanged;
  const _ValueRow({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        _MiniStepper(
          value: value,
          min: min,
          max: max,
          step: step,
          color: color,
          unit: unit,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _MiniStepper extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final String unit;
  final Color color;
  final ValueChanged<double> onChanged;
  const _MiniStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canDec = value > min;
    final canInc = value < max;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: canDec ? () => onChanged((value - step).clamp(min, max)) : null,
          icon: const Icon(Icons.remove_rounded),
          style: IconButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: colorScheme.onSurface,
            backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(canDec ? 0.5 : 0.2),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            border: Border.all(color: color.withOpacity(0.25)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${value.toInt()} $unit',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colorScheme.onSurface),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: canInc ? () => onChanged((value + step).clamp(min, max)) : null,
          icon: const Icon(Icons.add_rounded),
          style: IconButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: colorScheme.onSurface,
            backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(canInc ? 0.5 : 0.2),
          ),
        ),
      ],
    );
  }
}

