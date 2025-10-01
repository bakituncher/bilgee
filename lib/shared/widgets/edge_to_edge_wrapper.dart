// lib/shared/widgets/edge_to_edge_wrapper.dart
import 'package:flutter/material.dart';
import 'package:taktik/core/theme/app_theme.dart';

/// Android 15+ SDK 35 için edge-to-edge layout desteği sağlayan wrapper widget
class EdgeToEdgeWrapper extends StatelessWidget {
  const EdgeToEdgeWrapper({
    super.key,
    required this.child,
    this.enableStatusBarPadding = true,
    this.enableNavigationBarPadding = true,
    this.backgroundColor,
  });

  final Widget child;
  final bool enableStatusBarPadding;
  final bool enableNavigationBarPadding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final padding = EdgeInsets.only(
      top: enableStatusBarPadding ? mediaQuery.padding.top : 0,
      bottom: enableNavigationBarPadding ? mediaQuery.padding.bottom : 0,
    );

    return Container(
      color: backgroundColor ?? AppTheme.scaffoldBackgroundColor,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Scaffold için özel edge-to-edge wrapper
class EdgeToEdgeScaffold extends StatelessWidget {
  const EdgeToEdgeScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.backgroundColor,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.endDrawer,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Widget? endDrawer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppTheme.scaffoldBackgroundColor,
      drawer: drawer,
      endDrawer: endDrawer,
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          // Status bar için boşluk
          SizedBox(height: MediaQuery.of(context).padding.top),

          // AppBar varsa göster
          if (appBar != null) appBar!,

          // Ana içerik
          Expanded(child: body),

          // Bottom navigation bar varsa göster
          if (bottomNavigationBar != null) bottomNavigationBar!,

          // Navigation bar için boşluk
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
