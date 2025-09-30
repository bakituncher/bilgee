// lib/features/home/widgets/security_health_card.dart
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/shared/widgets/section_header.dart';

class SecurityHealthCard extends ConsumerStatefulWidget {
  const SecurityHealthCard({super.key});

  @override
  ConsumerState<SecurityHealthCard> createState() => _SecurityHealthCardState();
}

class _SecurityHealthCardState extends ConsumerState<SecurityHealthCard> {
  Future<_AppCheckStatus>? _appCheckFuture;

  @override
  void initState() {
    super.initState();
    _appCheckFuture = _resolveAppCheck();
  }

  Future<_AppCheckStatus> _resolveAppCheck() async {
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      if (token == null || token.isEmpty) {
        return const _AppCheckStatus(status: _SecurityStatus.warning, message: 'Token doğrulaması bekleniyor');
      }
      return const _AppCheckStatus(status: _SecurityStatus.ok, message: 'Firebase App Check etkin');
    } catch (e) {
      return _AppCheckStatus(status: _SecurityStatus.alert, message: 'App Check doğrulanamadı: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.asData?.value;

    final emailVerified = user?.emailVerified ?? false;

    bool hasMfa = false;
    if (user != null) {
      try {
        final dynamic multiFactor = user.multiFactor;
        final dynamic factors = multiFactor.enrolledFactors;
        if (factors is List && factors.isNotEmpty) {
          hasMfa = true;
        }
      } catch (_) {
        // Multi-factor enrollment list isn't available on this platform yet.
        hasMfa = user.providerData.any((p) => p.providerId == 'phone');
      }
    }

    final hasPassword = user?.providerData.any((p) => p.providerId == 'password') ?? false;

    final indicators = <_Indicator>[];
    int score = 100;

    if (emailVerified) {
      indicators.add(const _Indicator(
        icon: Icons.mark_email_read_rounded,
        label: 'E-posta doğrulandı',
        status: _SecurityStatus.ok,
      ));
    } else {
      score -= 30;
      indicators.add(const _Indicator(
        icon: Icons.mark_email_unread_rounded,
        label: 'E-posta doğrulaması bekleniyor',
        status: _SecurityStatus.warning,
      ));
    }

    if (hasMfa) {
      indicators.add(const _Indicator(
        icon: Icons.verified_user_rounded,
        label: 'İki adımlı doğrulama aktif',
        status: _SecurityStatus.ok,
      ));
    } else {
      score -= 35;
      indicators.add(const _Indicator(
        icon: Icons.phonelink_lock_rounded,
        label: 'İki adımlı doğrulamayı etkinleştir',
        status: _SecurityStatus.warning,
      ));
    }

    if (hasPassword) {
      indicators.add(const _Indicator(
        icon: Icons.password_rounded,
        label: 'Şifre ile giriş aktif',
        status: _SecurityStatus.ok,
      ));
    }

    return FutureBuilder<_AppCheckStatus>(
      future: _appCheckFuture,
      builder: (context, snapshot) {
        final appCheckStatus = snapshot.data;
        if (appCheckStatus != null) {
          indicators.add(_Indicator(
            icon: Icons.security_rounded,
            label: appCheckStatus.message,
            status: appCheckStatus.status,
          ));
          if (appCheckStatus.status != _SecurityStatus.ok) {
            score -= 20;
          }
        }

        score = score.clamp(0, 100).toInt();
        final isHealthy = score >= 75;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: isHealthy ? 8 : 10,
          shadowColor: (isHealthy ? AppTheme.successColor : AppTheme.accentColor).withOpacity(0.35),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  icon: Icons.shield_moon_rounded,
                  title: 'Güvenlik Sağlığı',
                  subtitle: 'Hesabını ve verilerini korumak için önerilen adımlar.',
                  trailing: _ScoreBadge(score: score),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: indicators
                      .map((indicator) => _SecurityChip(indicator: indicator))
                      .toList(),
                ),
                const SizedBox(height: 18),
                _SecurityHint(
                  score: score,
                  hasMfa: hasMfa,
                  emailVerified: emailVerified,
                  onOpenSecurity: () => context.go('/settings'),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 280.ms).slideY(begin: .05, curve: Curves.easeOut);
      },
    );
  }
}

class _SecurityHint extends StatelessWidget {
  const _SecurityHint({
    required this.score,
    required this.hasMfa,
    required this.emailVerified,
    required this.onOpenSecurity,
  });

  final int score;
  final bool hasMfa;
  final bool emailVerified;
  final VoidCallback onOpenSecurity;

  @override
  Widget build(BuildContext context) {
    String message;
    IconData icon;
    Color color;

    if (score >= 75) {
      message = 'Güçlü görünüyorsun! Güvenlik ayarlarını düzenli kontrol etmeyi unutma.';
      icon = Icons.check_circle_rounded;
      color = AppTheme.successColor;
    } else if (!hasMfa) {
      message = 'Hesabın kritik adımları eksik. İki adımlı doğrulamayı şimdi aç.';
      icon = Icons.warning_amber_rounded;
      color = AppTheme.goldColor;
    } else if (!emailVerified) {
      message = 'E-postanı doğrulayarak oturum kurtarma seçeneklerini aktif et.';
      icon = Icons.mark_email_unread_rounded;
      color = AppTheme.goldColor;
    } else {
      message = 'Tüm güvenlik özelliklerinden emin olmak için ayarları gözden geçir.';
      icon = Icons.security_rounded;
      color = AppTheme.secondaryColor;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppTheme.lightSurfaceColor.withOpacity(0.25),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.secondaryTextColor,
                    height: 1.45,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onOpenSecurity,
            child: const Text('Ayarları Aç'),
          ),
        ],
      ),
    );
  }
}

class _SecurityChip extends StatelessWidget {
  const _SecurityChip({required this.indicator});

  final _Indicator indicator;

  @override
  Widget build(BuildContext context) {
    final color = indicator.status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withOpacity(0.18),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(indicator.icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            indicator.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final status = score >= 75
        ? _SecurityStatus.ok
        : score >= 40
            ? _SecurityStatus.warning
            : _SecurityStatus.alert;

    final color = status.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withOpacity(0.18),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$score / 100',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _Indicator {
  const _Indicator({
    required this.icon,
    required this.label,
    required this.status,
  });

  final IconData icon;
  final String label;
  final _SecurityStatus status;
}

enum _SecurityStatus { ok, warning, alert }

extension on _SecurityStatus {
  Color get color {
    switch (this) {
      case _SecurityStatus.ok:
        return AppTheme.successColor;
      case _SecurityStatus.warning:
        return AppTheme.goldColor;
      case _SecurityStatus.alert:
        return AppTheme.accentColor;
    }
  }

  IconData get icon {
    switch (this) {
      case _SecurityStatus.ok:
        return Icons.verified_rounded;
      case _SecurityStatus.warning:
        return Icons.warning_amber_rounded;
      case _SecurityStatus.alert:
        return Icons.dangerous_rounded;
    }
  }
}

class _AppCheckStatus {
  const _AppCheckStatus({required this.status, required this.message});

  final _SecurityStatus status;
  final String message;
}
