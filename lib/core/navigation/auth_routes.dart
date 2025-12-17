// lib/core/navigation/auth_routes.dart
import 'package:go_router/go_router.dart';
import 'package:taktik/features/auth/presentation/login_screen.dart';
import 'package:taktik/features/auth/presentation/register_screen.dart';
import 'package:taktik/features/auth/presentation/verify_email_screen.dart';
import 'package:taktik/features/auth/presentation/pre_auth_welcome_screen.dart';
import 'app_routes.dart';
import 'transition_utils.dart';

final authRoutes = [
  GoRoute(
    path: AppRoutes.preAuthWelcome,
    name: 'PreAuthWelcome',
    pageBuilder: (context, state) => buildPageWithFadeTransition(
      context: context,
      state: state,
      child: const PreAuthWelcomeScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.login,
    name: 'Login',
    pageBuilder: (context, state) => buildPageWithFadeTransition(
      context: context,
      state: state,
      child: const LoginScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.register,
    name: 'Register',
    pageBuilder: (context, state) => buildPageWithFadeTransition(
      context: context,
      state: state,
      child: const RegisterScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.verifyEmail,
    name: 'VerifyEmail',
    pageBuilder: (context, state) => buildPageWithFadeTransition(
      context: context,
      state: state,
      child: const VerifyEmailScreen(),
    ),
  ),
];