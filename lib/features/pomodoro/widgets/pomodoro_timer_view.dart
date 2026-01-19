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
      PomodoroSessionState.work => ("Odaklanma Zamanı", colorScheme.secondary, "Çalışma seansın devam ediyor."),
      PomodoroSessionState.shortBreak => ("Kısa Mola", colorScheme.primary, "Biraz dinlen ve devam et."),
      PomodoroSessionState.longBreak => ("Uzun Mola", colorScheme.primary, "Uzun bir mola zamanı, iyice dinlen."),
      _ => ("Beklemede", colorScheme.surfaceContainerHighest, "Başlamak için hazırsın."),
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
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // Minimalist Başlık
        Text(
          title,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.95),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        // Görev Bilgisi
        GestureDetector(
          onTap: () => _showTaskSelectionSheet(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.task_alt, size: 16, color: Colors.white.withOpacity(0.9)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    pomodoro.currentTask,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit_outlined, size: 14, color: Colors.white.withOpacity(0.7)),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildControls(BuildContext context, PomodoroModel pomodoro, PomodoroNotifier notifier, WidgetRef ref) {
    final onBreak = pomodoro.sessionState == PomodoroSessionState.shortBreak || pomodoro.sessionState == PomodoroSessionState.longBreak;
    final canPromptReset = pomodoro.sessionState != PomodoroSessionState.idle;

    return Column(
      children: [
        // Minimalist Kontroller
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Settings Button
            _ModernIconButton(
              icon: Icons.settings_outlined,
              onPressed: () => _showSettingsSheet(context, ref),
              size: 48,
            ),
            const SizedBox(width: 32),
            // Ana Play/Pause Button
            GestureDetector(
              onTap: pomodoro.isPaused ? notifier.start : notifier.pause,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  pomodoro.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: const Color(0xFF2E3192),
                  size: 40,
                ),
              ),
            ).animate(target: pomodoro.isPaused ? 0 : 1).scale(
              duration: 300.ms,
              curve: Curves.easeOutBack,
              begin: const Offset(1, 1),
              end: const Offset(0.95, 0.95),
            ),
            const SizedBox(width: 32),
            // Reset Button
            _ModernIconButton(
              icon: Icons.refresh_rounded,
              onPressed: () => _confirmAndReset(context, notifier, prompt: canPromptReset),
              size: 48,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Tur göstergesi
        _RoundIndicator(
          currentRound: pomodoro.currentRound,
          totalRounds: pomodoro.longBreakInterval,
        ),

        const SizedBox(height: 24),

        // Aksiyon butonları
        if (onBreak)
          _ActionButton(
            icon: Icons.skip_next_rounded,
            label: "Molayı atla",
            onPressed: notifier.skipBreakAndStartWork,
          ),
        if (pomodoro.sessionState == PomodoroSessionState.work && pomodoro.currentTaskIdentifier != null)
          _ActionButton(
            icon: Icons.check_circle_outline,
            label: "Görevi tamamla",
            onPressed: () {
              notifier.markTaskAsCompleted();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("'${pomodoro.currentTask}' tamamlandı!"),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
      ],
    ).animate().fadeIn(duration: 400.ms);
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
            // Merkez metin - Minimalist
            Center(
              child: Text(
                '$minutes:$seconds',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                  fontSize: 72,
                  color: Colors.white,
                ),
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

    // Arkaplan çemberi - daha ince ve minimal
    final backgroundPaint = Paint()
      ..color = colorScheme.surfaceContainerHighest.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, backgroundPaint);

    if (progress > 0.0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * finalPulse
        ..strokeCap = StrokeCap.round;

      // Hafif glow sadece aktif durumlarda
      if (!isPaused) {
        final glowPaint = Paint()
          ..color = color.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14 * finalPulse
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

        canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, glowPaint);
      }

      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, progressPaint);
    }

    // Tur noktaları - daha minimal
    const dotRadius = 4.0;
    final dotDistance = radius - 6;
    for (int i = 0; i < interval; i++) {
      final angle = -pi / 2 + 2 * pi * (i / interval);
      final dx = center.dx + cos(angle) * dotDistance;
      final dy = center.dy + sin(angle) * dotDistance;
      final paint = Paint()
        ..color = i < completedInCycle ? color.withOpacity(0.9) : colorScheme.surfaceContainerHighest.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dx, dy), dotRadius, paint);
    }

    // Nefes/pulse arka katman - daha subtil
    final breath = sin(rotationAngle * (isPaused ? 0.5 : 1.5)) * 3;
    final breathPaint = Paint()
      ..color = color.withOpacity(isPaused ? 0.03 : 0.06)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, (radius - 25 + breath) * finalPulse, breathPaint);
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

// Modern Icon Button
class _ModernIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  const _ModernIconButton({
    required this.icon,
    required this.onPressed,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
        iconSize: size * 0.45,
      ),
    );
  }
}

// Round Indicator
class _RoundIndicator extends StatelessWidget {
  final int currentRound;
  final int totalRounds;

  const _RoundIndicator({
    required this.currentRound,
    required this.totalRounds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 16, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 8),
          Text(
            'Tur $currentRound / $totalRounds',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Action Button
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                        onPressed: () async {
                          final pomodoro = ref.read(pomodoroProvider);
                          final isActiveSession = !pomodoro.isPaused &&
                              (pomodoro.sessionState == PomodoroSessionState.work ||
                               pomodoro.sessionState == PomodoroSessionState.shortBreak ||
                               pomodoro.sessionState == PomodoroSessionState.longBreak);

                          // Aktif seans varsa kullanıcıyı uyar
                          if (isActiveSession) {
                            final shouldApply = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Mevcut Oturuma Uygula?'),
                                content: const Text(
                                  'Aktif bir seans var. Yeni ayarlar uygulanırsa mevcut süre sıfırlanacak ve yeni süreyle baştan başlayacak.\n\nDevam etmek istiyor musun?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('İptal'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Uygula'),
                                  ),
                                ],
                              ),
                            );

                            if (shouldApply != true) return;
                          }

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

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
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

