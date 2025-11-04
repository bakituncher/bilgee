import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the FutureProvider that provides the SharedPreferences instance.
    final asyncPrefs = ref.watch(sharedPreferencesProvider);
    final authState = ref.watch(authControllerProvider);

    return asyncPrefs.when(
      data: (prefs) {
        // Once we have the prefs instance, we can decide where to go.
        // We use a post-frame callback to ensure the build method completes
        // before we try to navigate.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final hasSeen = prefs.getBool('hasSeenWelcomeScreen') ?? false;
          final isLoggedIn = authState.hasValue && authState.value != null;
          final isEmailVerified = authState.value?.emailVerified ?? false;

          // Eğer kullanıcı giriş yapmış ve email doğrulanmışsa, her seferinde premium ekranına yönlendir
          if (hasSeen && isLoggedIn && isEmailVerified) {
            context.go('/premium');
          } else if (hasSeen) {
            context.go(AppRoutes.loading);
          } else {
            context.go(AppRoutes.preAuthWelcome);
          }
        });

        // While the navigation is happening, show a loader.
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: const LogoLoader(),
        );
      },
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const LogoLoader(),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Text('Hata: $err'),
        ),
      ),
    );
  }
}
