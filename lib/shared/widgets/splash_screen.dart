import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the FutureProvider that provides the SharedPreferences instance.
    final asyncPrefs = ref.watch(sharedPreferencesProvider);

    return asyncPrefs.when(
      data: (prefs) {
        // Once we have the prefs instance, we can decide where to go.
        // We use a post-frame callback to ensure the build method completes
        // before we try to navigate.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final hasSeen = prefs.getBool('hasSeenWelcomeScreen') ?? false;
          if (hasSeen) {
            context.go(AppRoutes.loading);
          } else {
            context.go(AppRoutes.preAuthWelcome);
          }
        });

        // While the navigation is happening, show a loader.
        return const Scaffold(body: LogoLoader());
      },
      loading: () => const Scaffold(body: LogoLoader()),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Text('Hata: $err'),
        ),
      ),
    );
  }
}
