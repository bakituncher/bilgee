import 'package:flutter/material.dart';

class AnswerButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isCorrectAnswer;
  final bool isWrongAnswer;
  final VoidCallback? onTap;

  const AnswerButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isCorrectAnswer,
    required this.isWrongAnswer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = Colors.white;
    Color textColor = const Color(0xFF1E1147); // Lacivert metin

    if (isSelected) {
      if (isCorrectAnswer) {
        backgroundColor = Colors.greenAccent.shade400;
        textColor = Colors.white;
      } else {
        backgroundColor = Colors.redAccent;
        textColor = Colors.white;
      }
    } else if (isCorrectAnswer && isWrongAnswer == false && !isSelected) {
      // Opsiyonel: Eğer yanlış cevap seçilmişse doğru cevabı göstermek istersen bunu kullanabilirsin.
      // backgroundColor = Colors.greenAccent.withOpacity(0.5);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (!isSelected) // Seçili değilken hafif gölge
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}