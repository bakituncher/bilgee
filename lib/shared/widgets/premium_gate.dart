import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/theme/app_theme.dart';

class PremiumGate extends ConsumerWidget {
  final Widget child;
  final String featureName;
  final IconData featureIcon;

  const PremiumGate({
    super.key,
    required this.child,
    this.featureName = 'Bu Özellik',
    this.featureIcon = Icons.auto_awesome_rounded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);

    return userProfile.when(
      data: (user) {
        if (user?.isPremium == true) {
          return child;
        } else {
          return _Paywall(
            featureName: featureName,
            featureIcon: featureIcon,
          );
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
    );
  }
}

class _Paywall extends StatelessWidget {
  final String featureName;
  final IconData featureIcon;

  const _Paywall({required this.featureName, required this.featureIcon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(featureName),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: Container(
        color: AppTheme.primaryColor.withOpacity(0.95),
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withOpacity(0.2),
                ),
                child: Icon(featureIcon, size: 60, color: Colors.amber),
              ),
              const SizedBox(height: 32),
              Text(
                '$featureName için Premium Gerekli',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Bu ve diğer tüm AI özelliklerine sınırsız erişim sağlamak için TaktikAI Premium\'a geçin.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Premium\'a Geç'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  context.push('/premium');
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                child: const Text('Geri Dön', style: TextStyle(color: Colors.white70)),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}