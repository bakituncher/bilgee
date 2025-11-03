// lib/shared/widgets/app_loader.dart
import 'package:flutter/material.dart';

class AppLoader extends StatelessWidget {
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    // Sade, hızlı açılan loader: sadece logo ve hafif opak geçiş
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 400),
          builder: (context, v, child) => Opacity(opacity: v, child: child),
          child: Image.asset(
            'assets/images/logo.png',
            width: 160,
            height: 160,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => Icon(
              Icons.school,
              size: 96,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}

// Önceki karmaşık animasyon ve gölgelendirme kaldırıldı; açılışta takılma azaltılır.
