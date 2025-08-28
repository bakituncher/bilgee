// lib/shared/widgets/app_loader.dart
import 'package:flutter/material.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';

class AppLoader extends StatelessWidget {
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: CircularProgressIndicator(color: AppTheme.secondaryColor),
      ),
    );
  }
}