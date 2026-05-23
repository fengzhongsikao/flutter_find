import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/flutter_app_info.dart';
import '../providers/scan_provider.dart';
import '../providers/scan_state.dart';
import '../router/app_routes.dart';
import '../widgets/app_list_tile.dart';
import '../widgets/brand_icon.dart';
import '../widgets/scan_progress_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        ref.read(scanProvider.notifier).startScan();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scan = ref.watch(scanProvider);
    final notifier = ref.read(scanProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandIcon.app(size: 28),
            SizedBox(width: 10),
            Text('Flutter Find'),
          ],
        ),
        actions: [
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onSelected: notifier.setSortMode,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: SortMode.name,
                child: Row(
                  children: [
                    if (scan.sortMode == SortMode.name)
                      const Icon(Icons.check, size: 18),
                    const SizedBox(width: 8),
                    const Text('按名称'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortMode.flutterVersion,
                child: Row(
                  children: [
                    if (scan.sortMode == SortMode.flutterVersion)
                      const Icon(Icons.check, size: 18),
                    const SizedBox(width: 8),
                    const Text('按 Flutter 版本'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (scan.isScanning && scan.progress != null)
            ScanProgressBanner(
              progress: scan.progress!,
              onCancel: notifier.cancelScan,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索应用名称或包名',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: scan.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          notifier.setSearchQuery('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: notifier.setSearchQuery,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '已发现 ${scan.totalFound} 个 Flutter 应用',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          if (scan.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(child: Text(scan.error!)),
                      TextButton(
                        onPressed: () => notifier.startScan(),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(child: _buildList(context, scan, notifier)),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    ScanState scan,
    ScanNotifier notifier,
  ) {
    if (scan.isScanning && scan.apps.isEmpty) {
      return const Center(child: Text('正在扫描设备上的应用…'));
    }
    if (!scan.isScanning && scan.apps.isEmpty && scan.error == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BrandIcon.flutter(size: 64),
            const SizedBox(height: 16),
            const Text('未发现 Flutter 应用'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => notifier.startScan(),
              child: const Text('重新扫描'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => notifier.startScan(),
      child: ListView.separated(
        itemCount: scan.apps.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final app = scan.apps[index];
          return AppListTile(
            app: app,
            onTap: () => context.push(AppRoutes.appDetailPath(app.packageName)),
          );
        },
      ),
    );
  }
}
