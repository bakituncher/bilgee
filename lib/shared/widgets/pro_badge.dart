import 'package:flutter/material.dart';

/// PRO kullanıcıları için altın renkli rozet widget'ı
class ProBadge extends StatelessWidget {
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;
  final double borderRadius;
  final double borderWidth;

  const ProBadge({
    super.key,
    this.fontSize = 9,
    this.horizontalPadding = 6,
    this.verticalPadding = 2,
    this.borderRadius = 6,
    this.borderWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.amber.withOpacity(0.5),
          width: borderWidth,
        ),
      ),
      child: Text(
        'PRO',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: Colors.amber,
        ),
      ),
    );
  }
}

