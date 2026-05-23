import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../generated/assets.dart';

class BrandIcon extends StatelessWidget {
  const BrandIcon({
    super.key,
    required this.asset,
    this.size = 24,
    this.isSvg = true,
  });

  const BrandIcon.flutter({super.key, this.size = 24})
      : asset = Assets.svgsFlutter,
        isSvg = true;

  const BrandIcon.dartIcon({super.key, this.size = 24})
      : asset = Assets.svgsDart,
        isSvg = true;

  const BrandIcon.app({super.key, this.size = 24})
      : asset = 'assets/icon/icon.png',
        isSvg = false;

  final String asset;
  final double size;
  final bool isSvg;

  @override
  Widget build(BuildContext context) {
    if (isSvg) {
      return SvgPicture.asset(asset, width: size, height: size);
    }
    return Image.asset(asset, width: size, height: size);
  }
}
