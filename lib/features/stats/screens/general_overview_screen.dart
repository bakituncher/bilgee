// lib/features/stats/screens/general_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/stats/widgets/overview_content.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';

/// Redesigned General Overview Screen with sector-level education analytics
/// Features: Modern design, comprehensive metrics, interactive charts, elegant UI
class GeneralOverviewScreen extends ConsumerStatefulWidget {
  const GeneralOverviewScreen({super.key});

  @override
  ConsumerState<GeneralOverviewScreen> createState() => _GeneralOverviewScreenState();
}

class _GeneralOverviewScreenState extends ConsumerState<GeneralOverviewScreen> {

  Future<void> _handleBack(BuildContext context) async {
    // Ana sayfaya (Dashboard) yönlendir
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final testsAsync = ref.watch(testsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false, // Sistemin otomatik kapatmasını engelle
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Geri tuşuna basılınca Ana Sayfaya (Dashboard) git
        context.go(AppRoutes.home);
      },
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0A0F1A)
            : const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xFF0A0F1A),
                      const Color(0xFF0A0F1A).withOpacity(0.95),
                      const Color(0xFF0A0F1A).withOpacity(0.0),
                    ]
                  : [
                      const Color(0xFFF8FAFC),
                      const Color(0xFFF8FAFC).withOpacity(0.95),
                      const Color(0xFFF8FAFC).withOpacity(0.0),
                    ],
              stops: const [0.0, 0.7, 1.0],
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF10B981),
                    Color(0xFF059669),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Genel Bakış',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                size: 18,
              ),
            ),
            tooltip: 'Geri',
            onPressed: () => _handleBack(context),
          ),
        ),
      ),
      body: SafeArea(
        child: userAsync.when(
          data: (user) {
            if (user == null) {
              return const Center(child: Text('Kullanıcı verisi yüklenemedi'));
            }

            final tests = testsAsync.valueOrNull ?? [];
            return OverviewContent(user: user, tests: tests, isDark: isDark);
          },
          loading: () => const LogoLoader(),
          error: (e, s) => Center(
            child: Text(
              'Hata: $e',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

