// lib/core/navigation/main_shell_routes.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/topic_performance_model.dart';
import 'package:taktik/features/arena/screens/arena_screen.dart';
import 'package:taktik/features/arena/screens/public_profile_screen.dart';
import 'package:taktik/features/coach/screens/ai_hub_screen.dart';
import 'package:taktik/features/coach/screens/analysis_strategy_screen.dart'; // YENİ: Analiz & Strateji ekranı
import 'package:taktik/features/coach/screens/coach_screen.dart';
import 'package:taktik/features/coach/screens/motivation_chat_screen.dart';
import 'package:taktik/features/coach/screens/select_subject_screen.dart';
import 'package:taktik/features/coach/screens/update_topic_performance_screen.dart';
import 'package:taktik/features/home/screens/add_test_screen.dart';
import 'package:taktik/features/home/screens/dashboard_screen.dart';
import 'package:taktik/features/home/screens/test_detail_screen.dart';
import 'package:taktik/features/home/screens/test_result_summary_screen.dart';
import 'package:taktik/features/pomodoro/pomodoro_screen.dart';
import 'package:taktik/features/profile/screens/profile_screen.dart';
import 'package:taktik/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:taktik/features/profile/screens/honor_wall_screen.dart';
import 'package:taktik/features/profile/models/badge_model.dart' as app_badge;
import 'package:taktik/features/stats/screens/stats_screen.dart';
import 'package:taktik/features/strategic_planning/screens/strategic_planning_screen.dart';
import 'package:taktik/features/strategic_planning/screens/strategy_review_screen.dart';
import 'package:taktik/features/weakness_workshop/models/saved_workshop_model.dart';
import 'package:taktik/features/weakness_workshop/screens/saved_workshop_detail_screen.dart';
import 'package:taktik/features/weakness_workshop/screens/saved_workshops_screen.dart';
import 'package:taktik/features/weakness_workshop/screens/weakness_workshop_screen.dart';
import 'package:taktik/shared/widgets/scaffold_with_nav_bar.dart';
import 'app_routes.dart';
import 'package:taktik/features/weakness_workshop/screens/workshop_stats_screen.dart';
import 'package:taktik/features/home/screens/weekly_plan_screen.dart';
import 'package:taktik/features/quests/screens/quests_screen.dart';
import 'package:taktik/features/profile/screens/avatar_selection_screen.dart'; // YENİ: Avatar ekranı import edildi
import 'package:taktik/features/profile/screens/follow_list_screen.dart'; // YENİ: Takip listesi ekranı import edildi
import 'transition_utils.dart';

StatefulShellRoute mainShellRoutes(GlobalKey<NavigatorState> rootNavigatorKey) {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) {
      return ScaffoldWithNavBar(navigationShell: navigationShell);
    },
    branches: [
      StatefulShellBranch(routes: [
        GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: const DashboardScreen()),
            routes: [
              GoRoute(
                path: AppRoutes.quests,
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: const QuestsScreen()),
              ),
              GoRoute(
                path: 'weekly-plan',
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: const WeeklyPlanScreen()),
              ),
              GoRoute(
                path: AppRoutes.addTest,
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: const AddTestScreen()),
              ),
              GoRoute(
                path: AppRoutes.testDetail,
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) {
                  final test = state.extra as TestModel?; // null güvenli
                  if (test == null) {
                    return buildPageWithFadeTransition(context: context, state: state, child: const Scaffold(body: Center(child: Text('Test verisi bulunamadı'))));
                  }
                  return buildPageWithFadeTransition(context: context, state: state, child: TestDetailScreen(test: test));
                },
              ),
              GoRoute(
                path: AppRoutes.testResultSummary,
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) {
                  final test = state.extra as TestModel?; // null güvenli
                  return buildPageWithFadeTransition(context: context, state: state, child: TestResultSummaryEntry(test: test));
                },
              ),
              GoRoute(
                path: AppRoutes.pomodoro,
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: const PomodoroScreen()),
              ),
              GoRoute(
                path: AppRoutes.stats,
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: const StatsScreen()),
              ),
            ]),
      ]),
      StatefulShellBranch(routes: [
        GoRoute(
            path: AppRoutes.coach,
            pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: CoachScreen(initialSubject: state.uri.queryParameters['subject'])),
            routes: [
              GoRoute(
                path: AppRoutes.selectSubject,
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: const SelectSubjectScreen()),
              ),
              GoRoute(
                path: AppRoutes.updateTopicPerformance,
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) {
                  final args = state.extra as Map<String, dynamic>;
                  return buildPageWithFadeTransition(context: context, state: state, child: UpdateTopicPerformanceScreen(
                    subject: args['subject'] as String,
                    topic: args['topic'] as String,
                    initialPerformance:
                    args['performance'] as TopicPerformanceModel,
                  ));
                },
              ),
            ]),
      ]),
      StatefulShellBranch(routes: [
        GoRoute(
            path: AppRoutes.aiHub,
            pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: const AiHubScreen()),
            routes: [
              GoRoute(
                  path: AppRoutes.strategicPlanning,
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: (context, state) =>
                  buildPageWithFadeTransition(context: context, state: state, child: const StrategicPlanningScreen()),
                  routes: [
                    GoRoute(
                      path: AppRoutes.strategyReview,
                      parentNavigatorKey: rootNavigatorKey,
                      pageBuilder: (context, state) {
                        final result = state.extra as Map<String, dynamic>;
                        return buildPageWithFadeTransition(context: context, state: state, child: StrategyReviewScreen(generationResult: result));
                      },
                    ),
                  ]),
              GoRoute(
                  path: AppRoutes.weaknessWorkshop,
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: (context, state) =>
                  buildPageWithFadeTransition(context: context, state: state, child: const WeaknessWorkshopScreen()),
                  routes: [
                    GoRoute(
                      path: 'stats',
                      parentNavigatorKey: rootNavigatorKey,
                      pageBuilder: (context, state) =>
                      buildPageWithFadeTransition(context: context, state: state, child: const WorkshopStatsScreen()),
                    ),
                    GoRoute(
                      path: AppRoutes.savedWorkshops,
                      parentNavigatorKey: rootNavigatorKey,
                      pageBuilder: (context, state) =>
                      buildPageWithFadeTransition(context: context, state: state, child: const SavedWorkshopsScreen()),
                    ),
                    GoRoute(
                      path: AppRoutes.savedWorkshopDetail,
                      parentNavigatorKey: rootNavigatorKey,
                      pageBuilder: (context, state) {
                        final workshop =
                        state.extra as SavedWorkshopModel;
                        return buildPageWithFadeTransition(context: context, state: state, child: SavedWorkshopDetailScreen(
                            workshop: workshop));
                      },
                    ),
                  ]),
              GoRoute(
                path: AppRoutes.motivationChat,
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) {
                  final prompt = state.extra;
                  return buildPageWithFadeTransition(context: context, state: state, child: MotivationChatScreen(initialPrompt: prompt));
                },
              ),
              GoRoute(
                path: AppRoutes.analysisStrategy, // YENİ rota
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: const AnalysisStrategyScreen()),
              ),
              GoRoute(
                path: AppRoutes.coachPushed,
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: CoachScreen(initialSubject: state.uri.queryParameters['subject'])),
              ),
            ]),
      ]),
      StatefulShellBranch(
          routes: [
            GoRoute(
                path: AppRoutes.arena,
                pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: const ArenaScreen()),
                routes: [
                  GoRoute(
                    path: ':userId',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) {
                      final userId = state.pathParameters['userId']!;
                      return buildPageWithFadeTransition(context: context, state: state, child: PublicProfileScreen(userId: userId));
                    },
                  )
                ]
            )
          ]),
      StatefulShellBranch(
          routes: [
            GoRoute(
                path: AppRoutes.profile,
                pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: const ProfileScreen()),
                routes: [
                  GoRoute(
                    path: 'edit',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: const EditProfileScreen()),
                  ),
                  GoRoute(
                    path: 'honor-wall',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) {
                      final allBadges = state.extra as List<app_badge.Badge>;
                      return buildPageWithFadeTransition(context: context, state: state, child: HonorWallScreen(allBadges: allBadges));
                    },
                  ),
                  // YENİ EKLENEN AVATAR ROTASI
                  GoRoute(
                    path: 'avatar-selection',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => buildPageWithFadeTransition(context: context, state: state, child: const AvatarSelectionScreen()),
                  ),
                  GoRoute(
                    path: 'follow-list',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) {
                      final mode = state.uri.queryParameters['mode'] ?? 'followers';
                      return buildPageWithFadeTransition(context: context, state: state, child: FollowListScreen(mode: mode));
                    },
                  ),
                ]),
          ]),
    ],
  );
}