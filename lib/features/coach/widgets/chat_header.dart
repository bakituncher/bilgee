// lib/features/coach/widgets/chat_header.dart
import 'package:flutter/material.dart';

class ChatHeader extends StatelessWidget {
  final void Function(String text) onQuickTap;
  const ChatHeader({super.key, required this.onQuickTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sohbet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Hazırsan yazmaya başlayalım. Ben kısaca ve net yanıtlayacağım.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
