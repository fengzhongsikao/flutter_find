import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pub_package_info.dart';
import '../services/pub_dev_service.dart';

final pubDevServiceProvider = Provider<PubDevService>(
  (ref) => PubDevService.instance,
);

final pubPackageInfoProvider =
    FutureProvider.family<PubPackageInfo, String>((ref, packageName) async {
  return ref.read(pubDevServiceProvider).fetchPackageInfo(packageName);
});
