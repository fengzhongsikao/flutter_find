import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pub_package_info.dart';
import '../providers/pub_dev_provider.dart';
import '../widgets/brand_icon.dart';

class DependencyDetailScreen extends ConsumerWidget {
  const DependencyDetailScreen({super.key, required this.packageName});

  final String packageName;

  Future<void> _openPubDev(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(pubPackageInfoProvider(packageName));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandIcon.dartIcon(size: 24),
            const SizedBox(width: 10),
            Flexible(child: Text(packageName)),
          ],
        ),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
      ),
      body: infoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DependencyDetailContent(
          packageName: packageName,
          info: PubPackageInfo(
            name: packageName,
            pubDevUrl: PubPackageInfo.pubDevUrlFor(packageName),
          ),
          loadError: error.toString(),
          onOpenPubDev: () =>
              _openPubDev(context, PubPackageInfo.pubDevUrlFor(packageName)),
          onRetry: () async {
            ref.invalidate(pubPackageInfoProvider(packageName));
            await ref.read(pubPackageInfoProvider(packageName).future);
          },
        ),
        data: (info) => _DependencyDetailContent(
          packageName: packageName,
          info: info,
          onOpenPubDev: () => _openPubDev(context, info.pubDevUrl),
          onRetry: () async {
            ref.invalidate(pubPackageInfoProvider(packageName));
            await ref.read(pubPackageInfoProvider(packageName).future);
          },
        ),
      ),
    );
  }
}

class _DependencyDetailContent extends StatelessWidget {
  const _DependencyDetailContent({
    required this.packageName,
    required this.info,
    required this.onOpenPubDev,
    required this.onRetry,
    this.loadError,
  });

  final String packageName;
  final PubPackageInfo info;
  final Future<void> Function() onOpenPubDev;
  final Future<void> Function() onRetry;
  final String? loadError;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '包名',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  packageName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '描述',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_descriptionText()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.link),
            title: const Text('官方链接'),
            subtitle: Text(
              info.pubDevUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: onOpenPubDev,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onOpenPubDev,
          icon: const Icon(Icons.open_in_browser),
          label: const Text('在 pub.dev 中打开'),
        ),
        if (loadError != null) ...[
          const SizedBox(height: 16),
          TextButton(onPressed: () => onRetry(), child: const Text('重新加载描述')),
        ],
      ],
    );
  }

  String _descriptionText() {
    if (info.notFound) {
      return '该包可能未发布至 pub.dev（私有依赖、git 依赖或 path 依赖）。';
    }
    if (loadError != null &&
        (info.description == null || info.description!.isEmpty)) {
      return '无法获取描述，请检查网络连接后重试。';
    }
    final desc = info.description;
    if (desc == null || desc.isEmpty) {
      return '暂无描述';
    }
    return desc;
  }
}
