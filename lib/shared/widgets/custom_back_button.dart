// lib/shared/widgets/custom_back_button.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const CustomBackButton({
    super.key,
    this.onPressed,
    this.color
  });

  @override
  Widget build(BuildContext context) {
    // Tema parlaklığını kontrol et (Koyu mu, Açık mı?)
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Eğer dışarıdan özel bir renk verilmediyse:
    // Koyu modda -> Beyaz
    // Açık modda -> Siyah
    final iconColor = color ?? (isDark ? Colors.white : Colors.black);

    return IconButton(
      icon: Icon(
        Icons.arrow_back_rounded,
        color: iconColor,
        size: 24,
      ),
      tooltip: 'Geri',
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashRadius: 0.1,
      onPressed: onPressed ?? () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/home');
        }
      },
    );
  }
}