import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../generated/assets.dart';

class BrandIcon extends StatelessWidget {
  const BrandIcon({
    super.key,
    required this.asset,
    this.size = 24,
  });

  const BrandIcon.flutter({super.key, this.size = 24})
      : asset = Assets.svgsFlutter;

  const BrandIcon.dartIcon({super.key, this.size = 24})
      : asset = Assets.svgsDart;

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(asset, width: size, height: size);
  }
}
