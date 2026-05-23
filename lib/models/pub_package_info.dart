class PubPackageInfo {
  const PubPackageInfo({
    required this.name,
    this.description,
    required this.pubDevUrl,
    this.notFound = false,
  });

  final String name;
  final String? description;
  final String pubDevUrl;
  final bool notFound;

  static String pubDevUrlFor(String name) =>
      'https://pub.dev/packages/$name';
}
