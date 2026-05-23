import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_find/app.dart';
import 'package:flutter_find/router/app_router.dart';

void main() {
  testWidgets('Unsupported platform shows message', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAndroidProvider.overrideWithValue(false),
        ],
        child: const FlutterFindApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('仅支持 Android'), findsOneWidget);
  });
}
