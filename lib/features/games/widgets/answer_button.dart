import 'package:flutter/material.dart';

class AnswerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isCorrectAnswer;
  final bool isWrongAnswer;
  final VoidCallback? onTap;

  const AnswerButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isCorrectAnswer,
    required this.isWrongAnswer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color backgroundColor;
    Color borderColor;
    Color textColor;

    if (isSelected) {
      // Kullanıcı bu butona tıkladı
      if (isCorrectAnswer) {
        // Doğru cevap verdi - yeşil
        backgroundColor = Colors.green.withAlpha(51);
        borderColor = Colors.green;
        textColor = Colors.green;
      } else {
        // Yanlış cevap verdi - kırmızı
        backgroundColor = Colors.red.withAlpha(51);
        borderColor = Colors.red;
        textColor = Colors.red;
      }
    } else {
      // Kullanıcı bu butona tıklamadı - normal görünüm (nötr renk)
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      borderColor = theme.colorScheme.outline.withAlpha(76);
      textColor = theme.colorScheme.onSurface;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

