// lib/core/navigation/main_shell_routes.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/models/topic_performance_model.dart';
import 'package:bilge_ai/features/arena/screens/arena_screen.dart';
import 'package:bilge_ai/features/arena/screens/public_profile_screen.dart';
import 'package:bilge_ai/features/coach/screens/ai_hub_screen.dart';
import 'package:bilge_ai/features/coach/screens/coach_screen.dart';
import 'package:bilge_ai/features/coach/screens/motivation_chat_screen.dart';
import 'package:bilge_ai/features/coach/screens/update_topic_performance_screen.dart';
import 'package:bilge_ai/features/home/screens/add_test_screen.dart';
import 'package:bilge_ai/features/home/screens/dashboard_screen.dart';
import 'package:bilge_ai/features/home/screens/test_detail_screen.dart';
import 'package:bilge_ai/features/home/screens/test_result_summary_screen.dart';
import 'package:bilge_ai/features/pomodoro/pomodoro_screen.dart';
import 'package:bilge_ai/features/profile/screens/profile_screen.dart';
import 'package:bilge_ai/features/profile/screens/honor_wall_screen.dart';
import 'package:bilge_ai/features/profile/models/badge_model.dart' as app_badge;
import 'package:bilge_ai/features/stats/screens/stats_screen.dart';
import 'package:bilge_ai/features/strategic_planning/screens/command_center_screen.dart';
import 'package:bilge_ai/features/strategic_planning/screens/strategic_planning_screen.dart';
import 'package:bilge_ai/features/strategic_planning/screens/strategy_review_screen.dart';
import 'package:bilge_ai/features/weakness_workshop/models/saved_workshop_model.dart';
import 'package:bilge_ai/features/weakness_workshop/screens/saved_workshop_detail_screen.dart';
import 'package:bilge_ai/features/weakness_workshop/screens/saved_workshops_screen.dart';
import 'package:bilge_ai/features/weakness_workshop/screens/weakness_workshop_screen.dart';
import 'package:bilge_ai/shared/widgets/scaffold_with_nav_bar.dart';
import 'app_routes.dart';
import 'package:bilge_ai/features/weakness_workshop/screens/workshop_stats_screen.dart';
import 'package:bilge_ai/features/home/screens/weekly_plan_screen.dart';
import 'package:bilge_ai/features/quests/screens/quests_screen.dart';
import 'package:bilge_ai/features/profile/screens/avatar_selection_screen.dart'; // YENİ: Avatar ekranı import edildi

StatefulShellRoute mainShellRoutes(GlobalKey<NavigatorState> rootNavigatorKey) {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) {
      return ScaffoldWithNavBar(navigationShell: navigationShell);
    },
    branches: [
      StatefulShellBranch(routes: [
        GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const DashboardScreen(),
            routes: [
              GoRoute(
                path: AppRoutes.quests,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const QuestsScreen(),
              ),
              GoRoute(
                path: 'weekly-plan',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const WeeklyPlanScreen(),
              ),
              GoRoute(
                path: AppRoutes.addTest,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const AddTestScreen(),
              ),
              GoRoute(
                path: AppRoutes.testDetail,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final test = state.extra as TestModel?; // null güvenli
                  if (test == null) {
                    return const Scaffold(body: Center(child: Text('Test verisi bulunamadı')));
                  }
                  return TestDetailScreen(test: test);
                },
              ),
              GoRoute(
                path: AppRoutes.testResultSummary,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final test = state.extra as TestModel?; // null güvenli
                  return TestResultSummaryEntry(test: test);
                },
              ),
              GoRoute(
                path: AppRoutes.pomodoro,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const PomodoroScreen(),
              ),
              GoRoute(
                path: AppRoutes.stats,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const StatsScreen(),
              ),
            ]),
      ]),
      StatefulShellBranch(routes: [
        GoRoute(
            path: AppRoutes.coach,
            builder: (context, state) => CoachScreen(initialSubject: state.uri.queryParameters['subject']),
            routes: [
              GoRoute(
                path: AppRoutes.updateTopicPerformance,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final args = state.extra as Map<String, dynamic>;
                  return UpdateTopicPerformanceScreen(
                    subject: args['subject'] as String,
                    topic: args['topic'] as String,
                    initialPerformance:
                    args['performance'] as TopicPerformanceModel,
                  );
                },
              ),
            ]),
      ]),
      StatefulShellBranch(routes: [
        GoRoute(
            path: AppRoutes.aiHub,
            builder: (context, state) => const AiHubScreen(),
            routes: [
              GoRoute(
                  path: AppRoutes.strategicPlanning,
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) =>
                  const StrategicPlanningScreen(),
                  routes: [
                    GoRoute(
                      path: AppRoutes.strategyReview,
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) {
                        final result = state.extra as Map<String, dynamic>;
                        return StrategyReviewScreen(generationResult: result);
                      },
                    ),
                  ]),
              GoRoute(
                  path: AppRoutes.commandCenter,
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) =>
                      CommandCenterScreen(user: state.extra as UserModel)),
              GoRoute(
                  path: AppRoutes.weaknessWorkshop,
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) =>
                  const WeaknessWorkshopScreen(),
                  routes: [
                    GoRoute(
                      path: 'stats',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) =>
                      const WorkshopStatsScreen(),
                    ),
                    GoRoute(
                      path: AppRoutes.savedWorkshops,
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) =>
                      const SavedWorkshopsScreen(),
                    ),
                    GoRoute(
                      path: AppRoutes.savedWorkshopDetail,
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) {
                        final workshop =
                        state.extra as SavedWorkshopModel;
                        return SavedWorkshopDetailScreen(
                            workshop: workshop);
                      },
                    ),
                  ]),
              GoRoute(
                path: AppRoutes.motivationChat,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final prompt = state.extra as Object?;
                  return MotivationChatScreen(initialPrompt: prompt);
                },
              ),
              GoRoute(
                path: AppRoutes.coachPushed,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => CoachScreen(initialSubject: state.uri.queryParameters['subject']),
              ),
            ]),
      ]),
      StatefulShellBranch(
          routes: [
            GoRoute(
                path: AppRoutes.arena,
                builder: (context, state) => const ArenaScreen(),
                routes: [
                  GoRoute(
                    path: ':userId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final userId = state.pathParameters['userId']!;
                      return PublicProfileScreen(userId: userId);
                    },
                  )
                ]
            )
          ]),
      StatefulShellBranch(
          routes: [
            GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'honor-wall',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final allBadges = state.extra as List<app_badge.Badge>;
                      return HonorWallScreen(allBadges: allBadges);
                    },
                  ),
                  // YENİ EKLENEN AVATAR ROTASI
                  GoRoute(
                    path: 'avatar-selection',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const AvatarSelectionScreen(),
                  ),
                ]),
          ]),
    ],
  );
}