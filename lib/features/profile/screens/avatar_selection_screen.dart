// lib/features/profile/screens/avatar_selection_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';

// Mevcut ve kilidi açılabilir avatar stilleri
const List<String> defaultAvatarStyles = [
  'adventurer',
  'adventurer-neutral',
  'avataaars',
  'big-ears',
  'bottts',
  'miniavs'
];

final selectedStyleProvider = StateProvider<String>((ref) {
  return ref.watch(userProfileProvider).value?.avatarStyle ?? defaultAvatarStyles.first;
});

final avatarSeedProvider = StateProvider<String>((ref) {
  return ref.watch(userProfileProvider).value?.avatarSeed ?? Random().nextInt(99999).toString();
});

class AvatarSelectionScreen extends ConsumerWidget {
  const AvatarSelectionScreen({super.key});

  Uri _getAvatarUri(String style, String seed) {
    return Uri.https('api.dicebear.com', '/9.x/$style/svg', {'seed': seed});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStyle = ref.watch(selectedStyleProvider);
    final avatarSeed = ref.watch(avatarSeedProvider);
    final user = ref.watch(userProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Avatar Atölyesi"),
        actions: [
          TextButton(
            onPressed: () async {
              final userId = ref.read(authControllerProvider).value!.uid;
              await ref.read(firestoreServiceProvider).updateUserAvatar(
                    userId: userId,
                    style: selectedStyle,
                    seed: avatarSeed,
                  );
              if (context.mounted) {
                context.pop();
              }
            },
            child: const Text("Kaydet"),
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 80,
            backgroundColor: AppTheme.lightSurfaceColor,
            child: ClipOval(
              child: SvgPicture.network(
                _getAvatarUri(selectedStyle, avatarSeed).toString(),
                fit: BoxFit.cover,
                placeholderBuilder: (context) => const CircularProgressIndicator(),
                height: 160,
                width: 160,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(avatarSeedProvider.notifier).state = Random().nextInt(99999).toString();
            },
            icon: const Icon(Icons.casino_rounded),
            label: const Text("Rastgele"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cardColor,
              foregroundColor: AppTheme.secondaryColor,
              side: const BorderSide(color: AppTheme.lightSurfaceColor),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(indent: 20, endIndent: 20),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: defaultAvatarStyles.length, // Şimdilik kilitli sistem yok
              itemBuilder: (context, index) {
                final style = defaultAvatarStyles[index];
                final isSelected = selectedStyle == style;

                return GestureDetector(
                  onTap: () => ref.read(selectedStyleProvider.notifier).state = style,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.secondaryColor : AppTheme.lightSurfaceColor,
                        width: 3,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SvgPicture.network(
                        _getAvatarUri(style, avatarSeed).toString(),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}