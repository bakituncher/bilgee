// lib/core/navigation/auth_routes.dart
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/features/auth/presentation/login_screen.dart';
import 'package:bilge_ai/features/auth/presentation/register_screen.dart';
import 'app_routes.dart';

final authRoutes = [
  GoRoute(
    path: AppRoutes.login,
    // DÜZELTME: 'const' kaldırıldı. Bu, derleyicinin kafasının karışmasını önler.
    builder: (context, state) => LoginScreen(),
  ),
  GoRoute(
    path: AppRoutes.register,
    // DÜZELTME: 'const' kaldırıldı.
    builder: (context, state) => RegisterScreen(),
  ),
];