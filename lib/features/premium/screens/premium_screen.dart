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

    // Otomatik geri dönüş dinleyicisini kaldırdık; navigasyon sadece işlem akışında yapılacak
    // ref.listen<bool>(premiumStatusProvider, (previous, next) {
    //   if (next == true) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(content: Text('Premium üyeliğiniz aktif!')),
    //     );
    //     _handleBack(context);
    //   }
    // });

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
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildPerksList(),
            const SizedBox(height: 18),
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.secondaryColor, Colors.amber]),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 40, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TaktikAI Premium', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.w800)),
                Text('Odakta kal, daha hızlı ilerle', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.primaryColor.withOpacity(0.9))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerksList() {
    const perks = [
      (Icons.bolt_rounded, 'Hızlı Öneriler', 'Anında kişiselleştirilmiş çalışma önerileri'),
      (Icons.auto_awesome_rounded, 'Akıllı Planlama', 'Yoğunluğa göre dinamik program revizyonu'),
      (Icons.insights_rounded, 'Derin Analizler', 'Zayıflık tespiti ve mikro hedefler'),
      (Icons.workspace_premium_rounded, 'Öncelikli Erişim', 'Yeni özelliklere erken erişim'),
    ];

    return ListView.separated(
      itemCount: perks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) {
        final (icon, title, desc) = perks[i];
        return Card(
          elevation: 6,
          shadowColor: AppTheme.lightSurfaceColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            leading: Icon(icon, color: AppTheme.secondaryColor),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(desc, style: const TextStyle(color: AppTheme.secondaryTextColor)),
          ),
        );
      },
    );
  }

  Widget _buildPurchaseOptions(BuildContext context, WidgetRef ref, Offerings? offerings) {
    // Offerings null ise gösterilecek bir şey yok
    if (offerings == null) {
      return const Center(
        child: Text(
          'Satın alma seçenekleri şu anda mevcut değil.\nLütfen daha sonra tekrar deneyin.',
          textAlign: TextAlign.center,
        ),
      );
    }

    // current boş ya da paketsizse, all içinden paketi olan ilk offering’i seç
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

    // 1) En güvenilir: packageType kısayolları
    Package? monthly = offering.monthly;
    Package? yearly = offering.annual;

    // 2) Özel tanımlı paket kimlikleri (RevenueCat Portal):
    monthly ??= offering.getPackage('aylik-normal');
    yearly ??= offering.getPackage('yillik-normal');

    // 3) availablePackages içinden packageType'a göre seç (null-safe)
    if (monthly == null) {
      final byTypeMonthly = offering.availablePackages.where((p) => p.packageType == PackageType.monthly);
      if (byTypeMonthly.isNotEmpty) monthly = byTypeMonthly.first;
    }
    if (yearly == null) {
      final byTypeYearly = offering.availablePackages.where((p) => p.packageType == PackageType.annual);
      if (byTypeYearly.isNotEmpty) yearly = byTypeYearly.first;
    }

    // 4) Ürün kimliğine göre geniş arama (SKU tam eşleşmiyorsa):
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

    // Eğer halen yoksa, elde ne varsa göster (kullanıcı bir şey seçebilsin)
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

    return Column(
      children: [
        if (monthly != null) ...[
          () {
            final m = monthly!;
            return _PurchaseOptionCard(
              package: m,
              title: 'Aylık',
              subtitle: m.storeProduct.priceString,
              isTrial: true,
              onTap: () => _purchasePackage(context, ref, m),
            );
          }(),
          const SizedBox(height: 12),
        ],
        if (yearly != null)
          () {
            final y = yearly!;
            return _PurchaseOptionCard(
              package: y,
              title: 'Yıllık',
              subtitle: y.storeProduct.priceString,
              isBestValue: true,
              onTap: () => _purchasePackage(context, ref, y),
            );
          }(),
      ],
    );
  }

  Future<void> _purchasePackage(BuildContext context, WidgetRef ref, Package package) async {
    // Basit bir loading göstergesi (UI donmasın ve çift tık önlensin)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final outcome = await RevenueCatService.makePurchase(package);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // loading kapat

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

class _PurchaseOptionCard extends StatelessWidget {
  const _PurchaseOptionCard({
    required this.package,
    required this.title,
    required this.subtitle,
    this.isTrial = false,
    this.isBestValue = false,
    required this.onTap,
  });

  final Package package;
  final String title;
  final String subtitle;
  final bool isTrial;
  final bool isBestValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: isBestValue ? const BorderSide(color: AppTheme.secondaryColor, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (isBestValue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('En İyi Değer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: Theme.of(context).textTheme.headlineSmall),
              if (isTrial) ...[
                const SizedBox(height: 8),
                const Text('7 gün ücretsiz deneme', style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}