import 'package:flutter/material.dart';

import 'theme.dart';

/// Logo resmi ZPP Reload (tanda Z perak di latar biru) dengan nama di sampingnya.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 44, this.showName = true, this.light = true});

  final double size;
  final bool showName;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [BoxShadow(color: Brand.deep.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/logo_mark.png', fit: BoxFit.cover, filterQuality: FilterQuality.medium),
    );
    if (!showName) return mark;

    final color = light ? Colors.white : Brand.deep;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.28),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'ZPP ',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text: 'Reload',
                style: TextStyle(color: light ? Brand.accentLight : Brand.accent, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          style: TextStyle(fontSize: size * 0.48, letterSpacing: 0.2),
        ),
      ],
    );
  }
}

/// Maskot ZPP. [pose]: 'mascot' (berdiri), 'mascot_wave' (melambai), 'mascot_thumbs' (jempol).
class Mascot extends StatelessWidget {
  const Mascot({super.key, this.pose = 'mascot', this.height = 160});

  final String pose;
  final double height;

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/$pose.png', height: height, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
}
