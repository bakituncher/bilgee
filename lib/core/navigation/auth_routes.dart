// lib/core/navigation/auth_routes.dart
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/features/auth/presentation/login_screen.dart';
import 'package:bilge_ai/features/auth/presentation/register_screen.dart';
import 'package:bilge_ai/features/auth/presentation/verify_email_screen.dart';
import 'app_routes.dart';
import 'transition_utils.dart';

final authRoutes = [
  GoRoute(
    path: AppRoutes.login,
    pageBuilder: (context, state) => buildPageWithFadeTransition(
      context: context,
      state: state,
      child: LoginScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.register,
    pageBuilder: (context, state) => buildPageWithFadeTransition(
      context: context,
      state: state,
      child: RegisterScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.verifyEmail,
    pageBuilder: (context, state) => buildPageWithFadeTransition(
      context: context,
      state: state,
      child: const VerifyEmailScreen(),
    ),
  ),
];