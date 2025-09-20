// lib/shared/widgets/loading_screen.dart
import 'package:flutter/material.dart';
import 'package:taktik/shared/widgets/app_loader.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppLoader();
  }
}