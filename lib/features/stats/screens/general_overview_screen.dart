// lib/features/stats/screens/general_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/services/admob_service.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/stats/widgets/overview_content.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/utils/age_helper.dart';

/// Redesigned General Overview Screen with sector-level education analytics
/// Features: Modern design, comprehensive metrics, interactive charts, elegant UI
class GeneralOverviewScreen extends ConsumerStatefulWidget {
  const GeneralOverviewScreen({super.key});

  @override
  ConsumerState<GeneralOverviewScreen> createState() => _GeneralOverviewScreenState();
}

class _GeneralOverviewScreenState extends ConsumerState<GeneralOverviewScreen> {
  @override
  void initState() {
    super.initState();
    // Show interstitial ad on screen entry (only for non-premium users)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProfileProvider).value;
      if (user != null) {
        final isUnder18 = AgeHelper.isUnder18(user.dateOfBirth);
        final isPremium = user.isPremium;
        AdMobService().showInterstitialAd(isUnder18: isUnder18, isPremium: isPremium);
      }
    });
  }

  Future<void> _handleBack(BuildContext context) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final testsAsync = ref.watch(testsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Genel Bakış',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          tooltip: 'Geri',
          onPressed: () => _handleBack(context),
        ),
      ),
      body: userAsync.when(
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
    );
  }
}

