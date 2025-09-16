import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LogoLoader extends StatelessWidget {
  const LogoLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/images/logo.png',
        width: 150,
      )
      .animate(onPlay: (controller) => controller.repeat(reverse: true))
      .fade(duration: 1200.ms, begin: 0.5, end: 1.0, curve: Curves.easeInOut),
    );
  }
}
