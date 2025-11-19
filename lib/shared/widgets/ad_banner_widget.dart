// lib/shared/widgets/ad_banner_widget.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:taktik/core/services/admob_service.dart';

/// Banner reklam widget'ı
/// Yaşa göre kişiselleştirilmiş/kişiselleştirilmemiş reklam gösterir
class AdBannerWidget extends StatefulWidget {
  final bool isUnder18;

  const AdBannerWidget({
    super.key,
    required this.isUnder18,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = AdMobService().createBannerAd(
      isUnder18: widget.isUnder18,
      onAdLoaded: (ad) {
        debugPrint('✅ Banner ad loaded');
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (ad, error) {
        debugPrint('❌ Banner ad failed to load: $error');
        ad.dispose();
        if (mounted) {
          setState(() {
            _isAdLoaded = false;
            _bannerAd = null;
          });
        }
      },
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      // Reklam yüklenene kadar boş alan
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

