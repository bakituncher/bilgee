// lib/shared/widgets/ad_banner_widget.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:taktik/core/services/admob_service.dart';

/// Banner reklam widget'ı
/// Premium kullanıcılara reklam gösterilmez
/// 18 yaşından küçüklere kişiselleştirilmemiş reklam gösterilir
class AdBannerWidget extends StatefulWidget {
  final bool isPremium;
  final DateTime? dateOfBirth;

  const AdBannerWidget({
    super.key,
    this.isPremium = false,
    this.dateOfBirth,
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
    // Premium kullanıcılara reklam yükleme
    if (!widget.isPremium) {
      _loadAd();
    }
  }

  void _loadAd() {
    _bannerAd = AdMobService().createBannerAd(
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
      dateOfBirth: widget.dateOfBirth,
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
    // Premium kullanıcılara hiç reklam gösterme
    if (widget.isPremium) {
      return const SizedBox.shrink();
    }

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

