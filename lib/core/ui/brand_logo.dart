import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// The Nexora wordmark + gradient glyph. Used in auth, sidebar, splash.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 40,
    this.showWordmark = true,
    this.onDark = false,
  });

  final double size;
  final bool showWordmark;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final labelColor = onDark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.bolt_rounded, color: Colors.white, size: size * 0.6),
        ),
        if (showWordmark) ...[
          const SizedBox(width: 12),
          Text(
            'Nexora',
            style: TextStyle(
              fontSize: size * 0.55,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: labelColor,
            ),
          ),
        ],
      ],
    );
  }
}
