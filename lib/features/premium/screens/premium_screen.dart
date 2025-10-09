// lib/features/premium/screens/premium_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/providers/premium_provider.dart';

class PremiumView extends ConsumerWidget {
  const PremiumView({super.key});

  Future<void> _handleBack(BuildContext context) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offeringsAsyncValue = ref.watch(offeringsProvider);
    final isPremium = ref.watch(premiumStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Geri',
          onPressed: () => _handleBack(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            const _MinimalHero(),
            const SizedBox(height: 16),
            _buildBenefitsList(context),
            const SizedBox(height: 22),
            offeringsAsyncValue.when(
              data: (offerings) => _buildPurchaseOptions(context, ref, offerings),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Hata: $error')),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                await ref.read(premiumStatusProvider.notifier).restorePurchases();
                if (context.mounted) {
                  final isPremium = ref.read(premiumStatusProvider);
                  final msg = isPremium ? 'Satın alımlar geri yüklendi. Premium aktif.' : 'Aktif satın alım bulunamadı.';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  if (isPremium) {
                    _handleBack(context);
                  }
                }
              },
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Satın alımları geri yükle'),
            ),
            const SizedBox(height: 8),
            const _TrustBadges(),
          ],
        ),
      ),
    );
  }

  // Klasik fayda listesi (check ikonlarıyla)
  Widget _buildBenefitsList(BuildContext context) {
    const items = [
      ('Sınırsız AI yanıtları', Icons.check_circle_outline_rounded),
      ('Kişiselleştirilmiş planlar', Icons.check_circle_outline_rounded),
      ('Gerçek zamanlı koçluk', Icons.check_circle_outline_rounded),
      ('Detaylı analiz ve içgörüler', Icons.check_circle_outline_rounded),
    ];

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                Icon(item.$2, color: AppTheme.successColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // SATIN ALMA SEÇENEKLERİ (iki plan kartı: Aylık/Yıllık)
  Widget _buildPurchaseOptions(BuildContext context, WidgetRef ref, Offerings? offerings) {
    if (offerings == null) {
      return const Center(
        child: Text(
          'Satın alma seçenekleri şu anda mevcut değil.\nLütfen daha sonra tekrar deneyin.',
          textAlign: TextAlign.center,
        ),
      );
    }

    Offering? selected = offerings.current;
    if (selected == null || selected.availablePackages.isEmpty) {
      final candidates = offerings.all.values.where((o) => o.availablePackages.isNotEmpty);
      if (candidates.isNotEmpty) {
        selected = candidates.first;
      }
    }

    if (selected == null) {
      return const Center(child: Text('Geçerli bir abonelik planı bulunamadı.'));
    }

    final offering = selected;

    Package? monthly = offering.monthly;
    Package? yearly = offering.annual;

    monthly ??= offering.getPackage('aylik-normal');
    yearly ??= offering.getPackage('yillik-normal');

    if (monthly == null) {
      final byTypeMonthly = offering.availablePackages.where((p) => p.packageType == PackageType.monthly);
      if (byTypeMonthly.isNotEmpty) monthly = byTypeMonthly.first;
    }
    if (yearly == null) {
      final byTypeYearly = offering.availablePackages.where((p) => p.packageType == PackageType.annual);
      if (byTypeYearly.isNotEmpty) yearly = byTypeYearly.first;
    }

    if (monthly == null) {
      final byIdMonthly = offering.availablePackages.where(
        (p) => p.storeProduct.identifier.contains('premium_aylik') ||
                p.identifier.contains('aylik') ||
                p.identifier.contains('monthly'),
      );
      if (byIdMonthly.isNotEmpty) monthly = byIdMonthly.first;
    }
    if (yearly == null) {
      final byIdYearly = offering.availablePackages.where(
        (p) => p.storeProduct.identifier.contains('premium_yillik') ||
                p.identifier.contains('yillik') ||
                p.identifier.contains('annual') ||
                p.identifier.contains('year'),
      );
      if (byIdYearly.isNotEmpty) yearly = byIdYearly.first;
    }

    if (monthly == null && yearly == null && offering.availablePackages.isNotEmpty) {
      if (offering.availablePackages.length == 1) {
        monthly = offering.availablePackages.first;
      } else {
        monthly = offering.availablePackages.first;
        yearly = offering.availablePackages.skip(1).first;
      }
    }

    if (monthly == null && yearly == null) {
      return const Center(child: Text('Geçerli bir abonelik planı bulunamadı.'));
    }

    double? savePercent;
    if (monthly != null && yearly != null) {
      final m = monthly!.storeProduct.price;
      final y = yearly!.storeProduct.price;
      if (m > 0 && (m * 12) > 0 && y > 0) {
        final ratio = 1 - (y / (m * 12));
        if (ratio > 0.01) savePercent = (ratio * 100).floorToDouble();
      }
    }

    return Column(
      children: [
        if (monthly != null) ...[
          _PurchaseOptionCard(
            package: monthly!,
            title: 'Aylık',
            subtitle: monthly!.storeProduct.priceString,
            tag: 'Popüler',
            onTap: () => _purchasePackage(context, ref, monthly!),
          ),
          const SizedBox(height: 12),
        ],
        if (yearly != null)
          _PurchaseOptionCard(
            package: yearly!,
            title: 'Yıllık',
            subtitle: yearly!.storeProduct.priceString,
            tag: savePercent != null ? 'En İyi Değer • %${savePercent!.toStringAsFixed(0)} Tasarruf' : 'En İyi Değer',
            highlight: true,
            onTap: () => _purchasePackage(context, ref, yearly!),
          ),
      ],
    );
  }

  Future<void> _purchasePackage(BuildContext context, WidgetRef ref, Package package) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final outcome = await RevenueCatService.makePurchase(package);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (outcome.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Satın alma iptal edildi.')),
        );
        return;
      }

      if (outcome.success && outcome.info != null) {
        ref.read(premiumStatusProvider.notifier).updateFromCustomerInfo(outcome.info!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Satın alma başarılı. Premium aktif!')),
        );
        _handleBack(context);
        return;
      }

      final errMsg = outcome.error ?? 'Bilinmeyen bir hata oluştu.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Satın alma başarısız: $errMsg')),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Satın alma sırasında bir hata oluştu: $e')),
      );
    }
  }
}

// ——— Sade kahraman alanı ———
class _MinimalHero extends StatelessWidget {
  const _MinimalHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Premium\'a Geç',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tüm yapay zeka özelliklerine sınırsız erişim.\n7 gün ücretsiz dene, dilediğinde iptal et.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.secondaryTextColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _PurchaseOptionCard extends StatelessWidget {
  const _PurchaseOptionCard({
    required this.package,
    required this.title,
    required this.subtitle,
    this.tag,
    this.highlight = false,
    required this.onTap,
  });

  final Package package;
  final String title;
  final String subtitle;
  final String? tag;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: highlight ? 12 : 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: highlight ? const BorderSide(color: AppTheme.secondaryColor, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (tag != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag!,
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.successColor),
                  SizedBox(width: 6),
                  Text('İstediğin zaman iptal et', style: TextStyle(color: AppTheme.secondaryTextColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ——— GÜVEN ROZETLERİ ———
class _TrustBadges extends StatelessWidget {
  const _TrustBadges();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        SizedBox(height: 4),
        _TrustRow(icon: Icons.verified_user_rounded, text: 'Gizli ücret yok'),
        SizedBox(height: 4),
        _TrustRow(icon: Icons.lock_open_rounded, text: 'Güvenli ödeme • App Store / Google Play'),
      ],
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppTheme.secondaryTextColor, size: 16),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: AppTheme.secondaryTextColor)),
      ],
    );
  }
}


