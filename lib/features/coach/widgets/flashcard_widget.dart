import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:math' as math;
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

class FlashcardWidget extends StatefulWidget {
  final int index;
  final int total;
  final String title;
  final String content;
  final Color color;

  const FlashcardWidget({
    super.key,
    required this.index,
    required this.total,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _frontRotation;
  late Animation<double> _backRotation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _frontRotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: math.pi / 2), weight: 50.0),
      TweenSequenceItem(tween: ConstantTween(math.pi / 2), weight: 50.0),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _backRotation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(-math.pi / 2), weight: 50.0),
      TweenSequenceItem(tween: Tween(begin: -math.pi / 2, end: 0.0), weight: 50.0),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleCard,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Back Side (Answer/Content)
          AnimatedBuilder(
            animation: _backRotation,
            builder: (context, child) {
              final angle = _backRotation.value;
              if (angle.abs() >= math.pi / 2) return const SizedBox.shrink();
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: _buildBack(),
              );
            },
          ),
          // Front Side (Question/Title)
          AnimatedBuilder(
            animation: _frontRotation,
            builder: (context, child) {
              final angle = _frontRotation.value;
              if (angle.abs() >= math.pi / 2) return const SizedBox.shrink();
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: _buildFront(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFront() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative background elements
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.style_rounded,
              size: 140,
              color: Colors.white.withOpacity(0.1),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'Kart ${widget.index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${widget.index + 1}/${widget.total}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                // Center Title
                Expanded(
                  child: Center(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Bottom Hint
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Çevirmek için dokun',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.color.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)), // Border width 2
            ),
            child: Row(
              children: [
                Icon(Icons.info_rounded, color: widget.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: widget.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    MarkdownBody(
                      data: widget.content,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontSize: 18,
                          height: 1.6,
                          color: colorScheme.onSurface.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                        strong: TextStyle(
                          color: widget.color,
                          fontWeight: FontWeight.w700,
                        ),
                        listBullet: TextStyle(
                          color: widget.color,
                          fontWeight: FontWeight.bold,
                        ),
                        h1: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                        h2: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                        h3: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                        blockquote: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontStyle: FontStyle.italic
                        ),
                        code: TextStyle(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      builders: {
                        'latex': _LatexElementBuilder(
                          textStyle: TextStyle(color: colorScheme.onSurface),
                        ),
                      },
                      extensionSet: md.ExtensionSet(
                        [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                        [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, _LatexInlineSyntax()],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Hint
           Padding(
             padding: const EdgeInsets.only(bottom: 16),
             child: Text(
               'Geri çevirmek için dokun',
               style: TextStyle(
                 color: colorScheme.onSurface.withOpacity(0.4),
                 fontSize: 12,
               ),
             ),
           ),
        ],
      ),
    );
  }
}

// --- LaTeX Syntax Sınıfları ---

/// LaTeX inline syntax parser - $...$ ve $$...$$ formatlarını yakalar
class _LatexInlineSyntax extends md.InlineSyntax {
  _LatexInlineSyntax() : super(r'(\$\$[\s\S]*?\$\$)|(\$[^$]*\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final match0 = match.group(0)!;
    final isDisplay = match0.startsWith(r'$$');
    final raw = isDisplay
        ? match0.substring(2, match0.length - 2)
        : match0.substring(1, match0.length - 1);
    final el = md.Element.text('latex', raw);
    el.attributes['mathStyle'] = isDisplay ? 'display' : 'text';
    parser.addNode(el);
    return true;
  }
}

/// LaTeX element builder - matematik ifadelerini render eder
class _LatexElementBuilder extends MarkdownElementBuilder {
  final TextStyle? textStyle;
  _LatexElementBuilder({this.textStyle});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final bool isDisplay = element.attributes['mathStyle'] == 'display';
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: isDisplay ? Alignment.center : Alignment.centerLeft,
      child: Math.tex(
        element.textContent,
        textStyle: textStyle ?? preferredStyle,
        mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
        onErrorFallback: (err) => Text(
          element.textContent,
          style: (textStyle ?? preferredStyle)?.copyWith(color: Colors.red),
        ),
      ),
    );
  }
}
