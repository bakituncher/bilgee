import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback için gerekli

class ScoreSlider extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;
  final ValueChanged<double>? onChanged; // Nullable yaptık (Disable durumu için)
  final String? unit;
  final double? totalQuestions; // Görsel doluluk için toplam soru sayısı

  const ScoreSlider({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.onChanged,
    this.unit,
    this.totalQuestions, // Opsiyonel - verilmezse eski davranış korunur
  });

  @override
  Widget build(BuildContext context) {
    // 1. Mantık Koruması: Max değer 0 veya daha küçükse slider bozulmasın diye 1 kabul edilir.
    // Ancak kullanıcı etkileşimi aşağıda engellenecektir.
    final double safeMax = max <= 0 ? 1.0 : max;

    // 2. Etkileşim Kontrolü: Eğer max 0 ise (örn: tüm sorular doğruysa, yanlış slider'ı 0 olmalı)
    // widget etkileşime kapanmalıdır.
    final bool isInteractive = max > 0;

    // 3. Görsel Doluluk Kontrolü: totalQuestions verilmişse, görsel max ona göre ayarlanır
    // Örnek: 40 soru, doğru max=40 → visualMax=40
    //        40 soru, yanlış max=10 → visualMax=40 (görsel olarak aynı referans)
    final double visualMax = totalQuestions ?? safeMax;


    return Opacity(
      // Pasif durumdaysa (max=0) widget'ı hafif soluklaştırarak kullanıcıya ipucu ver.
      opacity: isInteractive ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.1 : 0.08
            ),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Header: Etiket ve Değer Rozeti ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                    ),
                  ),
                  _buildValueBadge(context),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // --- Slider Alanı ---
            SizedBox(
              height: 36,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6.0,
                  trackShape: const RoundedRectSliderTrackShape(),
                  activeTrackColor: color,
                  inactiveTrackColor: color.withOpacity(0.15),
                  thumbColor: Colors.white,
                  thumbShape: _CustomThumbShape(
                      thumbColor: color,
                      thumbRadius: 12,
                      isInteractive: isInteractive,
                  ),
                  overlayColor: color.withOpacity(0.12),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 22.0),
                  tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 0),
                ),
                child: Slider(
                  value: value,
                  min: 0,
                  max: visualMax,
                  // divisions: null kullanarak sürekli (continuous) slider yap
                  // Bu sayede her değer seçilebilir, sonra yuvarlarız
                  divisions: null,
                  // Eğer interaktif değilse onChanged null olur ve slider kilitlenir.
                  onChanged: isInteractive
                      ? (newValue) {
                    // Değeri tam sayıya yuvarla ve gerçek max'a göre sınırla
                    final double roundedValue = newValue.roundToDouble().clamp(0, safeMax);

                    // UX: Sadece tam sayı değiştiğinde titreşim ver (performans için)
                    if (roundedValue.toInt() != value.toInt()) {
                      HapticFeedback.selectionClick();
                    }
                    if (onChanged != null) {
                      onChanged!(roundedValue);
                    }
                  }
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Değerin gösterildiği renkli kutucuk
  Widget _buildValueBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: value.toInt().toString(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
            if (unit != null)
              TextSpan(
                text: unit,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Özel Slider Başlığı (Thumb) Tasarımı ---
// İçi beyaz, dışı renkli halkalı ve gölgeli modern tasarım.
class _CustomThumbShape extends SliderComponentShape {
  final double thumbRadius;
  final Color thumbColor;
  final bool isInteractive;

  const _CustomThumbShape({
    required this.thumbRadius,
    required this.thumbColor,
    this.isInteractive = true,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
      PaintingContext context,
      Offset center, {
        required Animation<double> activationAnimation,
        required Animation<double> enableAnimation,
        required bool isDiscrete,
        required TextPainter labelPainter,
        required RenderBox parentBox,
        required SliderThemeData sliderTheme,
        required TextDirection textDirection,
        required double value,
        required double textScaleFactor,
        required Size sizeWithOverflow,
      }) {
    final Canvas canvas = context.canvas;

    // Eğer slider pasifse (kilitliyse) başlığı çizme veya gri çiz
    if (!isInteractive) {
      final Paint paintDisabled = Paint()
        ..color = Colors.grey.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, thumbRadius * 0.6, paintDisabled);
      return;
    }

    // 1. Gölge Katmanı (Derinlik)
    final Path shadowPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: thumbRadius));
    canvas.drawShadow(shadowPath, Colors.black.withOpacity(0.2), 3.0, true);

    // 2. Dış Halka (Ana Renk)
    final Paint paintOuter = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, thumbRadius, paintOuter);

    // 3. İç Daire (Beyaz)
    final Paint paintInner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    // Dış halkanın kalınlığını belirleyen oran (0.6 = %60'ı beyaz)
    canvas.drawCircle(center, thumbRadius * 0.6, paintInner);
  }
}

