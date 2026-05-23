import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flutter_app_info.dart';
import '../services/scanner_service.dart';
import 'scan_state.dart';
import 'scanner_service_provider.dart';

class ScanNotifier extends Notifier<ScanState> {
  StreamSubscription<dynamic>? _progressSub;

  @override
  ScanState build() {
    ref.onDispose(() {
      _progressSub?.cancel();
    });
    return ScanState.initial;
  }

  Future<void> startScan({bool excludeSystemApps = false}) async {
    if (state.isScanning) return;

    final scanner = ref.read(scannerServiceProvider);

    state = state.copyWith(
      isScanning: true,
      clearError: true,
      progress: const ScanProgress(current: 0, total: 0),
    );

    _progressSub?.cancel();
    _progressSub = scanner.scanProgressStream().listen((p) {
      state = state.copyWith(progress: p);
    });

    try {
      final results = await scanner.scanAll(
        excludeSystemApps: excludeSystemApps,
      );
      state = state.copyWith(
        rawApps: results,
        filteredApps: _filterAndSort(results, state.searchQuery, state.sortMode),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      _progressSub?.cancel();
      _progressSub = null;
      state = state.copyWith(isScanning: false);
    }
  }

  Future<void> cancelScan() async {
    await ref.read(scannerServiceProvider).cancelScan();
    _progressSub?.cancel();
    _progressSub = null;
    state = state.copyWith(isScanning: false);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredApps: _filterAndSort(state.rawApps, query, state.sortMode),
    );
  }

  void setSortMode(SortMode mode) {
    state = state.copyWith(
      sortMode: mode,
      filteredApps: _filterAndSort(state.rawApps, state.searchQuery, mode),
    );
  }

  List<FlutterAppSummary> _filterAndSort(
    List<FlutterAppSummary> apps,
    String query,
    SortMode sortMode,
  ) {
    var list = List<FlutterAppSummary>.from(apps);
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (a) =>
                a.appName.toLowerCase().contains(q) ||
                a.packageName.toLowerCase().contains(q),
          )
          .toList();
    }

    switch (sortMode) {
      case SortMode.name:
        list.sort(
          (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
        );
      case SortMode.flutterVersion:
        list.sort((a, b) {
          final va = _versionSortKey(a.flutterVersion);
          final vb = _versionSortKey(b.flutterVersion);
          return vb.compareTo(va);
        });
    }
    return list;
  }

  int _versionSortKey(String? version) {
    if (version == null || version.isEmpty || version == 'Unknown') {
      return -1;
    }
    final parts = version.split('.').map(int.tryParse).toList();
    var key = 0;
    for (var i = 0; i < parts.length && i < 4; i++) {
      key = key * 1000 + (parts[i] ?? 0);
    }
    return key;
  }
}

final scanProvider = NotifierProvider<ScanNotifier, ScanState>(
  ScanNotifier.new,
);
