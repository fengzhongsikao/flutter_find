import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [isAndroidProvider.overrideWithValue(Platform.isAndroid)],
      child: const FlutterFindApp(),
    ),
  );
}
