import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pub_package_info.dart';

class PubDevService {
  PubDevService._();
  static final PubDevService instance = PubDevService._();

  final Map<String, PubPackageInfo> _cache = {};

  Future<PubPackageInfo> fetchPackageInfo(String name) async {
    final cached = _cache[name];
    if (cached != null) return cached;

    final url = Uri.parse('https://pub.dev/api/packages/$name');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) {
        final info = PubPackageInfo(
          name: name,
          description: null,
          pubDevUrl: PubPackageInfo.pubDevUrlFor(name),
          notFound: true,
        );
        _cache[name] = info;
        return info;
      }
      if (response.statusCode != 200) {
        throw PubDevException('HTTP ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      String? description = json['description'] as String?;
      final latest = json['latest'] as Map<String, dynamic>?;
      if (description == null || description.isEmpty) {
        final pubspec = latest?['pubspec'] as Map<String, dynamic>?;
        description = pubspec?['description'] as String?;
      }

      final info = PubPackageInfo(
        name: name,
        description: description?.trim().isEmpty ?? true
            ? null
            : description?.trim(),
        pubDevUrl: PubPackageInfo.pubDevUrlFor(name),
      );
      _cache[name] = info;
      return info;
    } on PubDevException {
      rethrow;
    } catch (e) {
      throw PubDevException(e.toString());
    }
  }
}

class PubDevException implements Exception {
  PubDevException(this.message);
  final String message;

  @override
  String toString() => message;
}
