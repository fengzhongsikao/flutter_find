import 'dart:typed_data';

class FlutterAppSummary {
  const FlutterAppSummary({
    required this.packageName,
    required this.appName,
    required this.versionName,
    required this.versionCode,
    this.icon,
    this.flutterVersion,
    this.dartVersion,
  });

  final String packageName;
  final String appName;
  final String versionName;
  final int versionCode;
  final Uint8List? icon;
  final String? flutterVersion;
  final String? dartVersion;

  factory FlutterAppSummary.fromMap(Map<dynamic, dynamic> map) {
    final iconRaw = map['icon'];
    return FlutterAppSummary(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      versionName: map['versionName'] as String? ?? '',
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
      icon: iconRaw is List ? Uint8List.fromList(iconRaw.cast<int>()) : null,
      flutterVersion: map['flutterVersion'] as String?,
      dartVersion: map['dartVersion'] as String?,
    );
  }

  FlutterAppSummary copyWith({
    String? flutterVersion,
    String? dartVersion,
  }) {
    return FlutterAppSummary(
      packageName: packageName,
      appName: appName,
      versionName: versionName,
      versionCode: versionCode,
      icon: icon,
      flutterVersion: flutterVersion ?? this.flutterVersion,
      dartVersion: dartVersion ?? this.dartVersion,
    );
  }
}

class FlutterDependency {
  const FlutterDependency({required this.name});

  final String name;

  factory FlutterDependency.fromMap(Map<dynamic, dynamic> map) {
    return FlutterDependency(name: map['name'] as String? ?? '');
  }
}

class FlutterAppDetail extends FlutterAppSummary {
  const FlutterAppDetail({
    required super.packageName,
    required super.appName,
    required super.versionName,
    required super.versionCode,
    super.icon,
    super.flutterVersion,
    super.dartVersion,
    required this.dependencies,
  });

  final List<FlutterDependency> dependencies;

  factory FlutterAppDetail.fromMap(Map<dynamic, dynamic> map) {
    final depsRaw = map['dependencies'] as List<dynamic>? ?? [];
    return FlutterAppDetail(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      versionName: map['versionName'] as String? ?? '',
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
      icon: map['icon'] is List
          ? Uint8List.fromList((map['icon'] as List).cast<int>())
          : null,
      flutterVersion: map['flutterVersion'] as String?,
      dartVersion: map['dartVersion'] as String?,
      dependencies: depsRaw
          .map((e) => FlutterDependency.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
    );
  }
}

enum SortMode { name, flutterVersion }
