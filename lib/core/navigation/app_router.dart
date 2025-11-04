// lib/core/navigation/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/features/home/screens/library_screen.dart';
import 'package:taktik/features/settings/screens/settings_screen.dart';
import 'package:taktik/shared/widgets/loading_screen.dart';
import 'app_routes.dart';
import 'auth_routes.dart';
import 'onboarding_routes.dart';
import 'main_shell_routes.dart';
import 'package:taktik/features/blog/screens/blog_screen.dart';
import 'package:taktik/features/premium/screens/premium_screen.dart' as premium;
import 'package:taktik/features/premium/screens/tool_offer_screen.dart';
import 'package:taktik/features/premium/screens/ai_tools_offer_screen.dart';
import 'package:taktik/features/stats/screens/general_overview_screen.dart';
import 'package:taktik/features/stats/screens/stats_premium_offer_screen.dart';
import '../../features/blog/screens/blog_admin_editor_screen.dart';
import 'package:taktik/features/blog/screens/blog_detail_screen.dart';
import 'package:taktik/features/admin/screens/question_reports_screen.dart';
import 'package:taktik/features/admin/screens/question_report_detail_screen.dart';
import 'package:taktik/features/admin/screens/push_composer_screen.dart';
import 'package:taktik/features/admin/screens/admin_panel_screen.dart';
import 'package:taktik/features/admin/screens/user_management_screen.dart';
import 'package:taktik/shared/notifications/notification_center_screen.dart';
import 'package:taktik/features/profile/screens/user_search_screen.dart';
import 'package:taktik/shared/widgets/splash_screen.dart';
import 'package:taktik/data/providers/admin_providers.dart';
import 'transition_utils.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  final listenable = ValueNotifier<bool>(false);
  ref.listen(authControllerProvider, (_, __) => listenable.value = !listenable.value);
  ref.listen(userProfileProvider, (_, __) => listenable.value = !listenable.value);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: listenable,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authControllerProvider);
      final userProfileState = ref.read(userProfileProvider);
      final location = state.matchedLocation;

      // Allow splash and welcome screens to be shown without auth
      if (location == '/' || location == AppRoutes.preAuthWelcome) {
        return null;
      }

      final isLoggedIn = authState.hasValue && authState.value != null;
      final onAuthScreen = location == AppRoutes.login || location == AppRoutes.register || location == AppRoutes.verifyEmail;

      // If the user is not logged in, redirect to the login screen.
      if (!isLoggedIn) {
        return onAuthScreen ? null : AppRoutes.login;
      }

      // If the user is logged in but their email is not verified, redirect to the verify email screen.
      final isEmailVerified = authState.value?.emailVerified ?? false;
      if (!isEmailVerified) {
        return location == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail;
      }

      // If there was an error fetching the user profile, something is wrong. Log them out.
      if (userProfileState.hasError) {
        return AppRoutes.login;
      }

      // If the user is logged in, proceed with onboarding checks.
      if (userProfileState.hasValue && userProfileState.value != null) {
        final user = userProfileState.value!;

        // Onboarding Step 1: Profile Completion
        if (!user.profileCompleted) {
          return location == AppRoutes.profileCompletion ? null : AppRoutes.profileCompletion;
        }

        // Onboarding Step 2: Exam Selection
        if (user.selectedExam == null || user.selectedExam!.isEmpty) {
          return location == AppRoutes.examSelection ? null : AppRoutes.examSelection;
        }

        // Onboarding Step 3: Availability
        if (user.weeklyAvailability.isEmpty) {
          return location == AppRoutes.availability ? null : AppRoutes.availability;
        }

        // **** HATAYI ÇÖZEN ANA MANTIK ****
        // If the user is fully onboarded and tries to go to login, register, or the loading screen,
        // redirect them to the home screen.
        // This *allows* them to visit other setup screens (like /exam-selection from settings)
        // without being redirected.
        if (location == AppRoutes.login || location == AppRoutes.register || location == AppRoutes.loading) {
          return AppRoutes.home;
        }

        // Admin Panel Access Control
        final isAdmin = ref.read(adminClaimProvider).valueOrNull ?? false;
        if (location.startsWith('/admin') && !isAdmin) {
          return AppRoutes.home;
        }
      }

      // If none of the above conditions are met, allow navigation.
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.loading,
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const LoadingScreen(),
        ),
      ),
      GoRoute(
          path: AppRoutes.library,
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (context, state) => buildPageWithFadeTransition(
            context: context,
            state: state,
            child: const LibraryScreen(),
          )
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      // Blog ve Premium (üst seviye sayfalar)
      GoRoute(
        path: '/blog',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const BlogScreen(),
        ),
      ),
      GoRoute(
        path: '/blog/:slug',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return buildPageWithFadeTransition(
            context: context,
            state: state,
            child: BlogDetailScreen(slug: slug),
          );
        },
      ),
      GoRoute(
        path: '/premium',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const premium.PremiumScreen(),
        ),
      ),
       GoRoute(
        path: '/ai-hub/offer',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final args = extra is Map<String, dynamic> ? extra : const <String, dynamic>{};
          return buildPageWithFadeTransition(
            context: context,
            state: state,
            child: ToolOfferScreen(
              title: (args['title'] as String?) ?? 'Premium Teklif',
              subtitle: (args['subtitle'] as String?) ?? 'Premium özelliklerin kilidini aç',
              icon: (args['icon'] as IconData?) ?? Icons.auto_awesome,
              color: (args['color'] as Color?) ?? Colors.blueAccent,
              heroTag: (args['heroTag'] as String?) ?? 'offer-default',
              marketingTitle: (args['marketingTitle'] as String?) ?? 'Sınavda her zaman önde olun',
              marketingSubtitle: (args['marketingSubtitle'] as String?) ?? 'Akıllı planlama, zayıf noktaları kapatma ve daha fazlası.',
              redirectRoute: args['redirectRoute'] as String?,
            ),
          );
        },
      ),
      GoRoute(
        path: '/ai-tools-offer',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const AIToolsOfferScreen(),
        ),
      ),
      GoRoute(
        path: '/stats/overview',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const GeneralOverviewScreen(),
        ),
      ),
      GoRoute(
        path: '/stats-premium-offer',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const StatsPremiumOfferScreen(),
        ),
      ),
      // Bildirim Merkezi
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const NotificationCenterScreen(),
        ),
      ),
      // Admin: Cevher Bildirimleri
      GoRoute(
        path: '/admin/panel',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const AdminPanelScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/user-management',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const UserManagementScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/reports',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const QuestionReportsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/reports/:qhash',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final qhash = state.pathParameters['qhash']!;
          return buildPageWithFadeTransition(
            context: context,
            state: state,
            child: QuestionReportDetailScreen(qhash: qhash),
          );
        },
      ),
      GoRoute(
        path: '/admin/push-composer',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const PushComposerScreen(),
        ),
      ),
      GoRoute(
        path: '/blog/admin/new',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const BlogAdminEditorScreen(),
        ),
      ),
      GoRoute(
        path: '/blog/admin/edit/:slug',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return buildPageWithFadeTransition(
            context: context,
            state: state,
            child: BlogAdminEditorScreen(initialSlug: slug),
          );
        },
      ),
      GoRoute(
        path: '/user-search',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithFadeTransition(
          context: context,
          state: state,
          child: const UserSearchScreen(),
        ),
      ),
      ...authRoutes,
      ...onboardingRoutes(rootNavigatorKey),
      mainShellRoutes(rootNavigatorKey),
    ],
  );
});
