// lib/features/coach/widgets/mastery_topic_bubble.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/models/topic_performance_model.dart';
import 'package:bilge_ai/data/models/exam_model.dart';

class MasteryTopicBubble extends StatefulWidget {
  final SubjectTopic topic;
  final TopicPerformanceModel performance;
  final double penaltyCoefficient;
  final VoidCallback onTap;
  final VoidCallback onLongPress; // YENİ: Uzun basma callback'i
  final bool compact; // GRID icin daha dar mod

  const MasteryTopicBubble({
    super.key,
    required this.topic,
    required this.performance,
    required this.penaltyCoefficient,
    required this.onTap,
    required this.onLongPress,
    this.compact = false,
  });

  @override
  State<MasteryTopicBubble> createState() => _MasteryTopicBubbleState();
}

class _MasteryTopicBubbleState extends State<MasteryTopicBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500 + Random().nextInt(1000)),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      < 0 => AppTheme.lightSurfaceColor,
      >= 0 && < 0.4 => AppTheme.accentColor,
      >= 0.4 && < 0.7 => AppTheme.secondaryColor,
      _ => AppTheme.successColor,
    };

    final String tooltipMessage = mastery < 0
        ? "${widget.topic.name}\n(Analiz için en az 5 soru çözülmeli)"
        : "${widget.topic.name}\nNet Hakimiyet: %${(mastery * 100).toStringAsFixed(0)}\nD:${widget.performance.correctCount} Y:${widget.performance.wrongCount}";

    return Tooltip(
      message: tooltipMessage,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector( // YENİ: GestureDetector ile sarmaladık
          onTap: widget.onTap,
          onLongPress: widget.onLongPress, // YENİ
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 12 : 16,
                vertical: widget.compact ? 8 : 10,
              ),
              constraints: widget.compact ? const BoxConstraints(minHeight: 48) : null,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(widget.compact ? 18 : 30),
                border: Border.all(color: color, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(_isHovered ? 0.7 : 0.4),
                    blurRadius: _isHovered ? 15.0 : 8.0,
                    spreadRadius: 1.0,
                  ),
                ],
              ),
              child: Builder(builder: (context){
                final name = widget.topic.name;
                final len = name.length;
                final baseSize = widget.compact ? 13.0 : 14.0;
                double fontSize = baseSize;
                if (widget.compact) {
                  if (len > 30) fontSize = 10.5; else if (len > 26) fontSize = 11.0; else if (len > 22) fontSize = 12.0; else if (len > 18) fontSize = 12.5;
                }
                return Text(
                  name,
                  maxLines: widget.compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}