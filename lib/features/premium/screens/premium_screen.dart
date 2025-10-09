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

    // If the user is already premium, redirect them.
    ref.listen<bool>(premiumStatusProvider, (previous, next) {
      if (next == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium üyeliğiniz aktif!')),
        );
        _handleBack(context);
      }
    });

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
    if (offerings?.current == null) {
      return const Center(
        child: Text(
          'Satın alma seçenekleri şu anda mevcut değil.\nLütfen daha sonra tekrar deneyin.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final offering = offerings!.current!;
    final monthly = offering.getPackage('premium_aylik');
    final yearly = offering.getPackage('premium_yillik');

    if (monthly == null && yearly == null) {
      return const Center(child: Text('Geçerli bir abonelik planı bulunamadı.'));
    }

    return Column(
      children: [
        if (monthly != null)
          _PurchaseOptionCard(
            package: monthly,
            title: 'Aylık',
            subtitle: monthly.storeProduct.priceString,
            isTrial: true,
            onTap: () => _purchasePackage(context, ref, monthly),
          ),
        const SizedBox(height: 12),
        if (yearly != null)
          _PurchaseOptionCard(
            package: yearly,
            title: 'Yıllık',
            subtitle: yearly.storeProduct.priceString,
            isBestValue: true,
            onTap: () => _purchasePackage(context, ref, yearly),
          ),
      ],
    );
  }

  Future<void> _purchasePackage(BuildContext context, WidgetRef ref, Package package) async {
    try {
      final success = await RevenueCatService.makePurchase(package);
      if (success && context.mounted) {
        // The listener will handle the premium status update and navigation.
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Satın alma sırasında bir hata oluştu: $e')),
        );
      }
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