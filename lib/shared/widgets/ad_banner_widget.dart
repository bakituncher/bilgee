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

  @override
  void didUpdateWidget(covariant AdBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Premium durumu değişti mi?
    if (widget.isPremium != oldWidget.isPremium) {
      if (widget.isPremium) {
        // Kullanıcı Premium oldu: Reklamı hemen dispose et ve gizle
        _disposeAd();
      } else {
        // Kullanıcı Premium'dan çıktı: Reklamı yükle
        _loadAd();
      }
    }
    // Yaş bilgisi değişti mi? (Premium değilse yeniden yüklemeyi tetikleyebilir)
    else if (!widget.isPremium && widget.dateOfBirth != oldWidget.dateOfBirth) {
      // Yaş değiştiğinde, daha uygun (COPPA vs) reklam göstermek için yeniden yükle
      _disposeAd();
      _loadAd();
    }
  }

  void _loadAd() {
    // Eğer zaten yüklü veya yükleniyorsa tekrar çağırma (basit kontrol)
    if (_bannerAd != null) return;

    // Service premium kontrolünü kendi içinde de yapıyor ve null dönüyor,
    // ancak biz widget seviyesinde de kontrol ediyoruz.
    final ad = AdMobService().createBannerAd(
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
        ad.dispose(); // Hata durumunda dispose çağrılmalı
        if (mounted) {
          setState(() {
            _isAdLoaded = false;
            _bannerAd = null;
          });
        }
      },
      dateOfBirth: widget.dateOfBirth,
    );

    if (ad != null) {
      _bannerAd = ad;
      _bannerAd?.load();
    }
  }

  void _disposeAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
    if (mounted) {
      setState(() {}); // UI'ı güncelle (shrink olması için)
    }
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
