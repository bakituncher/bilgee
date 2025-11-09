import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/data/providers/firestore_providers.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the FutureProvider that provides the SharedPreferences instance.
    final asyncPrefs = ref.watch(sharedPreferencesProvider);
    final authState = ref.watch(authControllerProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return asyncPrefs.when(
      data: (prefs) {
        final hasSeen = prefs.getBool('hasSeenWelcomeScreen') ?? false;
        final isLoggedIn = authState.hasValue && authState.value != null;
        final isEmailVerified = authState.value?.emailVerified ?? false;

        // Eğer kullanıcı giriş yapmış ve email doğrulanmışsa
        if (hasSeen && isLoggedIn && isEmailVerified) {
          // User profile'ın yüklenmesini bekle
          return userProfileAsync.when(
            data: (userProfile) {
              // Profile yüklendikten sonra premium durumuna göre yönlendir
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final isPremium = userProfile?.isPremium ?? false;

                if (isPremium) {
                  context.go(AppRoutes.home);
                } else {
                  context.go('/premium');
                }
              });

              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: const LogoLoader(),
              );
            },
            loading: () => Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: const LogoLoader(),
            ),
            error: (err, stack) {
              // Hata durumunda premium ekranına yönlendir
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go('/premium');
              });

              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: const LogoLoader(),
              );
            },
          );
        }

        // Kullanıcı giriş yapmamışsa veya email doğrulanmamışsa
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (hasSeen) {
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
