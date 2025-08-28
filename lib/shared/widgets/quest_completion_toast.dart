// lib/shared/widgets/quest_completion_toast.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui; // blur için
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/quests/logic/quest_completion_notifier.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';

class QuestCompletionToast extends ConsumerStatefulWidget {
  final Quest completedQuest;
  const QuestCompletionToast({super.key, required this.completedQuest});

  @override
  ConsumerState<QuestCompletionToast> createState() => _QuestCompletionToastState();
}

class _QuestCompletionToastState extends ConsumerState<QuestCompletionToast> with TickerProviderStateMixin {
  Timer? _dismissTimer;
  late final AnimationController _pulseC;
  late final AnimationController _spinC;

  @override
  void initState() {
    super.initState();
    _pulseC = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _spinC = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _dismissTimer = Timer(5.seconds, () { if (mounted) _dismiss(); });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _pulseC.dispose();
    _spinC.dispose();
    super.dispose();
  }

  void _dismiss() { ref.read(questCompletionProvider.notifier).clear(); }

  @override
  Widget build(BuildContext context) {
    final quest = widget.completedQuest;
    final reward = "+${quest.reward} BP";

    return Semantics(
      label: 'Görev tamamlandı: ${quest.title}',
      liveRegion: true,
      readOnly: true,
      child: GestureDetector(
        onTap: _dismiss,
        child: Animate(
          target: ref.watch(questCompletionProvider) == null ? 0 : 1,
          effects: [
            FadeEffect(duration: 350.ms),
            SlideEffect(begin: const Offset(0, .4), curve: Curves.easeOutCubic, duration: 420.ms),
            ScaleEffect(begin: const Offset(.95, .95), end: const Offset(1,1), duration: 420.ms, curve: Curves.easeOutBack),
          ],
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  constraints: const BoxConstraints(maxWidth: 560), // genişlik sınırı eklendi
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.successColor.withValues(alpha: .20),
                        const Color(0xFF1E2B3D).withValues(alpha: .90),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: AppTheme.successColor.withValues(alpha: .55), width: 1.3),
                    boxShadow: [
                      BoxShadow(color: AppTheme.successColor.withValues(alpha: .35), blurRadius: 30, spreadRadius: 1, offset: const Offset(0,8)),
                      BoxShadow(color: Colors.black.withValues(alpha: .45), blurRadius: 18, offset: const Offset(0,6)),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Dekoratif yumuşak halkalar
                      Positioned(
                        right: -30,
                        top: -30,
                        child: AnimatedBuilder(
                          animation: _spinC,
                          builder: (_, __) => Transform.rotate(
                            angle: _spinC.value * math.pi * 2,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    AppTheme.successColor.withValues(alpha: .0),
                                    AppTheme.successColor.withValues(alpha: .35),
                                    AppTheme.successColor.withValues(alpha: .0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max, // shrink-wrap yerine tam genişlik
                        children: [
                          _QuestBadge(pulse: _pulseC, spin: _spinC),
                          const SizedBox(width: 18),
                          Expanded( // Flexible yerine Expanded
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Görev Tamamlandı',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        letterSpacing: 1.1,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.successColor,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  quest.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        height: 1.15,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _RewardChip(label: reward),
                                    const SizedBox(width: 8),
                                    if (quest.difficulty != null)
                                      _DifficultyChip(level: quest.difficulty!.name),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Kapat butonu InkWell -> GestureDetector
                          GestureDetector(
                            onTap: _dismiss,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: .06),
                                border: Border.all(color: Colors.white.withValues(alpha: .14)),
                              ),
                              child: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestBadge extends StatelessWidget {
  final AnimationController pulse; final AnimationController spin;
  const _QuestBadge({required this.pulse, required this.spin});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: AnimatedBuilder(
        animation: Listenable.merge([pulse, spin]),
        builder: (_, __) {
          final pulseScale = 1 + (pulse.value * 0.06);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppTheme.successColor.withValues(alpha: .55), Colors.transparent],
                  ),
                ),
              ),
              Transform.scale(
                scale: pulseScale,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppTheme.successColor, AppTheme.successColor.withValues(alpha: .6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: AppTheme.successColor.withValues(alpha: .5), blurRadius: 18, spreadRadius: 1),
                    ],
                    border: Border.all(color: Colors.white.withValues(alpha: .25), width: 1.2),
                  ),
                  child: AnimatedBuilder(
                    animation: spin,
                    builder: (_, child) => Transform.rotate(
                      angle: -spin.value * math.pi * 2,
                      child: child,
                    ),
                    child: const Icon(Icons.military_tech_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final String label; const _RewardChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [AppTheme.successColor.withValues(alpha: .25), AppTheme.successColor.withValues(alpha: .10)],
        ),
        border: Border.all(color: AppTheme.successColor.withValues(alpha: .55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: AppTheme.successColor),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.successColor, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final String level; const _DifficultyChip({required this.level});
  Color _color(String l){
    switch(l.toLowerCase()){
      case 'hard': case 'zor': return Colors.redAccent;
      case 'medium': case 'orta': return Colors.amberAccent;
      default: return Colors.lightBlueAccent;
    }
  }
  @override
  Widget build(BuildContext context) {
    final c = _color(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: .6)),
        color: c.withValues(alpha: .15),
      ),
      child: Text(level, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w600)),
    );
  }
}