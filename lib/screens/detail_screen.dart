import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/flutter_app_info.dart';
import '../providers/app_detail_provider.dart';
import '../providers/scan_provider.dart';
import '../router/app_routes.dart';
import '../widgets/brand_icon.dart';
import '../widgets/dependency_list_tile.dart';

class DetailScreen extends ConsumerWidget {
  const DetailScreen({super.key, required this.packageName});

  final String packageName;

  FlutterAppSummary _summaryFromScan(WidgetRef ref) {
    final scan = ref.watch(scanProvider);
    for (final app in scan.rawApps) {
      if (app.packageName == packageName) return app;
    }
    return FlutterAppSummary(
      packageName: packageName,
      appName: packageName,
      versionName: '',
      versionCode: 0,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = _summaryFromScan(ref);
    final detailAsync = ref.watch(appDetailProvider(packageName));

    return Scaffold(
      appBar: AppBar(
        title: Text(app.appName),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DetailBody(
          app: app,
          detail: FlutterAppDetail(
            packageName: app.packageName,
            appName: app.appName,
            versionName: app.versionName,
            versionCode: app.versionCode,
            icon: app.icon,
            flutterVersion: app.flutterVersion,
            dartVersion: app.dartVersion,
            dependencies: const [],
          ),
          error: error.toString(),
          onRefresh: () async {
            ref.invalidate(appDetailProvider(packageName));
            await ref.read(appDetailProvider(packageName).future);
          },
        ),
        data: (detail) => _DetailBody(
          app: detail,
          detail: detail,
          onRefresh: () async {
            ref.invalidate(appDetailProvider(packageName));
            await ref.read(appDetailProvider(packageName).future);
          },
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.app,
    required this.detail,
    this.error,
    required this.onRefresh,
  });

  final FlutterAppSummary app;
  final FlutterAppDetail detail;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!),
              ),
            ),
          _SectionCard(
            title: 'App 信息',
            children: [
              _InfoRow(
                label: '应用名称',
                child: Row(
                  children: [
                    _AppIconSmall(icon: app.icon),
                    const SizedBox(width: 12),
                    Expanded(child: Text(app.appName)),
                  ],
                ),
              ),
              _InfoRow(label: '版本号', value: app.versionName),
              _InfoRow(label: '包名', value: app.packageName),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Flutter 信息',
            children: [
              _InfoRow(
                label: 'Flutter 版本',
                child: Row(
                  children: [
                    const BrandIcon.flutter(size: 18),
                    const SizedBox(width: 8),
                    Text(app.flutterVersion ?? 'Unknown'),
                  ],
                ),
              ),
              _InfoRow(
                label: 'Dart 版本',
                child: Row(
                  children: [
                    const BrandIcon.dartIcon(size: 18),
                    const SizedBox(width: 8),
                    Text(app.dartVersion ?? '—'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '第三方依赖 (${detail.dependencies.length})',
            children: [
              if (detail.dependencies.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('未解析到依赖包，或该应用未包含 NOTICES 文件'),
                )
              else
                ...detail.dependencies.map(
                  (dep) => DependencyListTile(
                    name: dep.name,
                    onTap: () =>
                        context.push(AppRoutes.dependencyDetailPath(dep.name)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value, this.child});

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          child ?? Text(value ?? '—'),
        ],
      ),
    );
  }
}

class _AppIconSmall extends StatelessWidget {
  const _AppIconSmall({this.icon});

  final Uint8List? icon;

  @override
  Widget build(BuildContext context) {
    if (icon != null && icon!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(icon!, width: 40, height: 40),
      );
    }
    return const Icon(Icons.android, size: 40);
  }
}
