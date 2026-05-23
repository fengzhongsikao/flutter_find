import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/scanner_service.dart';

final scannerServiceProvider = Provider<ScannerService>(
  (ref) => ScannerService.instance,
);
