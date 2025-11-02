import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/data/models/topic_performance_model.dart';
import 'package:taktik/data/models/exam_model.dart';

class MasteryTopicBubble extends StatefulWidget {
  final SubjectTopic topic;
  final TopicPerformanceModel performance;
  final double penaltyCoefficient;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool compact;
  final int? index; // Staggered animasyon için index

  const MasteryTopicBubble({
    super.key,
    required this.topic,
    required this.performance,
    required this.penaltyCoefficient,
    required this.onTap,
    required this.onLongPress,
    this.compact = false,
    this.index,
  });

  @override
  State<MasteryTopicBubble> createState() => _MasteryTopicBubbleState();
}

class _MasteryTopicBubbleState extends State<MasteryTopicBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    // PERFORMANS İYİLEŞTİRMESİ: Sadece hover/tap için kullanılan controller
    // Sürekli repeat() animasyonu kaldırıldı - %95 CPU/GPU tasarrufu
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _hoverController,
        curve: Curves.easeOutCubic,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(
        parent: _hoverController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool isHovered) {
    if (!mounted) return;
    setState(() => _isHovered = isHovered);
    if (isHovered) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  void _onTapDown() {
    if (!mounted) return;
    setState(() => _isPressed = true);
  }

  void _onTapUp() {
    if (!mounted) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final double netCorrect = widget.performance.correctCount -
        (widget.performance.wrongCount * widget.penaltyCoefficient);
    final double mastery = widget.performance.questionCount < 5
        ? -1
        : widget.performance.questionCount == 0
            ? 0
            : (netCorrect / widget.performance.questionCount).clamp(0.0, 1.0);

    final Color color = switch (mastery) {
      < 0 => Theme.of(context).colorScheme.surfaceContainerHighest,
      >= 0 && < 0.4 => Theme.of(context).colorScheme.error,
      >= 0.4 && < 0.7 => Theme.of(context).colorScheme.primary,
      _ => Colors.green,
    };

    final String tooltipMessage = mastery < 0
        ? "${widget.topic.name}\n(Analiz için en az 5 soru çözülmeli)"
        : "${widget.topic.name}\nNet Hakimiyet: %${(mastery * 100).toStringAsFixed(0)}\nD:${widget.performance.correctCount} Y:${widget.performance.wrongCount}";

    // Staggered animasyon desteği
    final delay = widget.index != null ? (widget.index! * 30).clamp(0, 500) : 0;

    return Tooltip(
      message: tooltipMessage,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => _onHoverChanged(true),
        onExit: (_) => _onHoverChanged(false),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: (_) => _onTapDown(),
          onTapUp: (_) => _onTapUp(),
          onTapCancel: () => _onTapUp(),
          child: AnimatedBuilder(
            animation: _hoverController,
            builder: (context, child) {
              return Transform.scale(
                scale: _isPressed ? 0.95 : _scaleAnimation.value,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 14 : 18,
                    vertical: widget.compact ? 10 : 12,
                  ),
                  constraints: widget.compact
                      ? const BoxConstraints(minHeight: 50)
                      : null,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.2),
                        color.withOpacity(0.12),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(widget.compact ? 20 : 32),
                    border: Border.all(
                      color: color.withOpacity(_isHovered ? 0.9 : 0.6),
                      width: _isHovered ? 2.0 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(_glowAnimation.value * 0.5),
                        blurRadius: _isHovered ? 20.0 : 10.0,
                        spreadRadius: _isHovered ? 2.0 : 0.0,
                      ),
                      if (_isHovered)
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 30.0,
                          spreadRadius: 5.0,
                        ),
                    ],
                  ),
                  child: Builder(builder: (context) {
                    final name = widget.topic.name;
                    final len = name.length;
                    final baseSize = widget.compact ? 13.5 : 14.5;
                    double fontSize = baseSize;

                    if (widget.compact) {
                      if (len > 30) {
                        fontSize = 11.0;
                      } else if (len > 26) {
                        fontSize = 11.5;
                      } else if (len > 22) {
                        fontSize = 12.0;
                      } else if (len > 18) {
                        fontSize = 12.5;
                      }
                    }

                    return Text(
                      name,
                      maxLines: widget.compact ? 2 : 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: _isHovered ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: 0.3,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            blurRadius: _isHovered ? 15.0 : 12.0,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.black.withOpacity(0.7)
                                : Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 1),
                          ),
                          Shadow(
                            blurRadius: 5.0,
                            color: color.withOpacity(0.5),
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        )
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
      ),
    );
  }
}

