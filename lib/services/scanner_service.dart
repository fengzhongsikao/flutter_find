import 'dart:async';

import 'package:flutter/services.dart';

import '../models/flutter_app_info.dart';

class ScanProgress {
  const ScanProgress({required this.current, required this.total});

  final int current;
  final int total;

  double get fraction => total > 0 ? current / total : 0;
}

class ScannerService {
  ScannerService._();
  static final ScannerService instance = ScannerService._();

  static const _channel = MethodChannel('com.example.flutter_find/scanner');
  static const _progressChannel = EventChannel(
    'com.example.flutter_find/scan_progress',
  );

  StreamSubscription<dynamic>? _progressSub;

  Stream<ScanProgress> scanProgressStream() {
    return _progressChannel.receiveBroadcastStream().map((event) {
      final map = event as Map<dynamic, dynamic>;
      return ScanProgress(
        current: (map['current'] as num?)?.toInt() ?? 0,
        total: (map['total'] as num?)?.toInt() ?? 0,
      );
    });
  }

  Future<List<FlutterAppSummary>> scanAll({bool excludeSystemApps = false}) async {
    final result = await _channel.invokeMethod<List<dynamic>>(
      'scanAll',
      {'excludeSystemApps': excludeSystemApps},
    );
    return (result ?? [])
        .map((e) => FlutterAppSummary.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  Future<FlutterAppDetail> analyzePackage(String packageName) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'analyzePackage',
      {'packageName': packageName},
    );
    if (result == null) {
      throw PlatformException(
        code: 'NOT_FOUND',
        message: 'Package not found: $packageName',
      );
    }
    return FlutterAppDetail.fromMap(result);
  }

  Future<void> cancelScan() async {
    await _channel.invokeMethod<void>('cancelScan');
  }

  void dispose() {
    _progressSub?.cancel();
  }
}
