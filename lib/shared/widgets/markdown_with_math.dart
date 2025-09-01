// lib/shared/widgets/markdown_with_math.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart' as fmd;
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// Inline LaTeX: $ ... $
class _TexInlineSyntax extends md.InlineSyntax {
  _TexInlineSyntax() : super(r"\$(.+?)\$");
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = match.group(1) ?? '';
    parser.addNode(md.Element.text('tex', content));
    return true;
  }
}

/// Block-like LaTeX: $$ ... $$ (single-line or same paragraph)
class _TexDoubleDollarSyntax extends md.InlineSyntax {
  _TexDoubleDollarSyntax() : super(r"\$\$([^$]+?)\$\$");
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = match.group(1) ?? '';
    parser.addNode(md.Element.text('tex', content));
    return true;
  }
}

class _TexBuilder extends fmd.MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final expr = element.textContent.trim();
    if (expr.isEmpty) return const SizedBox.shrink();
    return Math.tex(
      expr,
      textStyle: preferredStyle,
      mathStyle: MathStyle.text,
    );
  }
}

class MarkdownWithMath extends StatelessWidget {
  final String data;
  final fmd.MarkdownStyleSheet? styleSheet;
  final EdgeInsets padding;
  final md.ExtensionSet? extensionSet;
  const MarkdownWithMath({super.key, required this.data, this.styleSheet, this.padding = const EdgeInsets.all(0), this.extensionSet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: fmd.MarkdownBody(
        data: data,
        selectable: false,
        styleSheet: styleSheet ?? fmd.MarkdownStyleSheet.fromTheme(Theme.of(context)),
        builders: {'tex': _TexBuilder()},
        inlineSyntaxes: [
          _TexDoubleDollarSyntax(),
          _TexInlineSyntax(),
        ],
        extensionSet: extensionSet ?? md.ExtensionSet.gitHubFlavored,
      ),
    );
  }
}
