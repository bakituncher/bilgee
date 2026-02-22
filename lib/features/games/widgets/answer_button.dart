import 'package:flutter/material.dart';

class AnswerButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isCorrectAnswer;
  final bool isWrongAnswer;
  final VoidCallback? onTap;
  final bool isBigButton;

  const AnswerButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isCorrectAnswer,
    required this.isWrongAnswer,
    required this.onTap,
    this.isBigButton = false,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = Colors.white;
    Color textColor = const Color(0xFF1E1147); // Lacivert metin

    // Eğer doğru cevapsa ve cevap verildiyse yeşil yansın
    if (isCorrectAnswer) {
      backgroundColor = Colors.greenAccent.shade400;
      textColor = Colors.white;
    }

    // Eğer seçilmişse ve yanlışsa kırmızı yansın (üzerine yazar)
    if (isSelected && isWrongAnswer) {
      backgroundColor = Colors.redAccent;
      textColor = Colors.white;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: isBigButton ? 32 : 14,
          horizontal: 20,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            if (!isCorrectAnswer && !isWrongAnswer) // Cevap verilmediyse hafif gölge
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isBigButton ? 22 : 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}