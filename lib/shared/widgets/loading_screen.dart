// lib/shared/widgets/loading_screen.dart
import 'package:flutter/material.dart';
import 'package:bilge_ai/shared/widgets/app_loader.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppLoader();
  }
}