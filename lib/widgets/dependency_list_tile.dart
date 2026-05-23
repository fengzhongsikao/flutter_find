import 'package:flutter/material.dart';

import 'brand_icon.dart';

class DependencyListTile extends StatelessWidget {
  const DependencyListTile({
    super.key,
    required this.name,
    required this.onTap,
  });

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: const BrandIcon.dartIcon(size: 22),
      ),
      title: Text(name),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
