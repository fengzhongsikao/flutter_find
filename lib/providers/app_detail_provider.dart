import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flutter_app_info.dart';
import 'scanner_service_provider.dart';

final appDetailProvider = FutureProvider.family<FlutterAppDetail, String>(
  (ref, packageName) async {
    return ref.read(scannerServiceProvider).analyzePackage(packageName);
  },
);
