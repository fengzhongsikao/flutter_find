import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/flutter_app_info.dart';
import 'brand_icon.dart';

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.app,
    required this.onTap,
  });

  final FlutterAppSummary app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _AppIcon(icon: app.icon),
      title: Text(app.appName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('v${app.versionName}', style: Theme.of(context).textTheme.bodySmall),
          if (app.flutterVersion != null)
            Text(
              'Flutter ${app.flutterVersion}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({this.icon});

  final Uint8List? icon;

  @override
  Widget build(BuildContext context) {
    if (icon != null && icon!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(icon!, width: 48, height: 48, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const BrandIcon.flutter(size: 28),
    );
  }
}
