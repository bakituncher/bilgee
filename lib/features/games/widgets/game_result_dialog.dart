import 'package:flutter/material.dart';

class GameResultDialog {
  static void show({
    required BuildContext context,
    required int score,
    required int totalQuestions,
    required VoidCallback onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Oyun Bitti!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Skorun: $score / ${totalQuestions * 10}',
              style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              score >= 70
                  ? 'Harika! Çok iyi gidiyorsun!'
                  : score >= 50
                      ? 'İyi gidiyorsun! Biraz daha pratik yaparsan mükemmel olacak!'
                      : 'Endişelenme, pratik yaparak gelişebilirsin!',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Ana Menü'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRetry();
            },
            child: const Text('Tekrar Oyna'),
          ),
        ],
      ),
    );
  }
}

