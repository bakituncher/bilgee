// lib/core/navigation/onboarding_routes.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/features/onboarding/screens/exam_selection_screen.dart';
import 'package:taktik/features/onboarding/screens/availability_screen.dart';
import 'package:taktik/features/onboarding/screens/profile_completion_screen.dart';
import 'package:taktik/features/onboarding/screens/intro_screen.dart';
import 'app_routes.dart';
import 'transition_utils.dart';

List<RouteBase> onboardingRoutes(GlobalKey<NavigatorState> rootNavigatorKey) {
  return [
    GoRoute(
      path: '/intro', // Hardcoded path or add to AppRoutes if preferred
      name: 'Intro',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context,
        state: state,
        child: const IntroScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileCompletion,
      name: 'ProfileCompletion',
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context,
        state: state,
        child: const ProfileCompletionScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.examSelection,
      name: 'ExamSelection',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context,
        state: state,
        child: const ExamSelectionScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.availability,
      name: 'Availability',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context,
        state: state,
        child: const AvailabilityScreen(),
      ),
    ),
  ];
}
