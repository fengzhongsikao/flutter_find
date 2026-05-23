import 'package:flutter/material.dart';

import '../services/scanner_service.dart';

class ScanProgressBanner extends StatelessWidget {
  const ScanProgressBanner({
    super.key,
    required this.progress,
    required this.onCancel,
  });

  final ScanProgress progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: progress.total > 0 ? progress.fraction : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                progress.total > 0
                    ? '正在扫描… ${progress.current}/${progress.total}'
                    : '正在扫描已安装应用…',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }
}
