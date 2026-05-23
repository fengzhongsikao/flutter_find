import 'package:flutter/material.dart';

import '../widgets/brand_icon.dart';

class UnsupportedPlatformScreen extends StatelessWidget {
  const UnsupportedPlatformScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandIcon.flutter(size: 28),
            SizedBox(width: 10),
            Text('Flutter Find'),
          ],
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandIcon.flutter(size: 64),
              SizedBox(height: 24),
              Text(
                'Flutter Find 仅支持 Android 平台。\n'
                '请在 Android 设备上安装并运行本应用。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
