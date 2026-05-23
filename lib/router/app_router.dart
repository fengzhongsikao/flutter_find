import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/dependency_detail_screen.dart';
import '../screens/detail_screen.dart';
import '../screens/home_screen.dart';
import '../screens/unsupported_platform_screen.dart';
import 'app_routes.dart';

final isAndroidProvider = Provider<bool>((ref) => true);

final goRouterProvider = Provider<GoRouter>((ref) {
  final isAndroid = ref.watch(isAndroidProvider);

  return GoRouter(
    initialLocation: isAndroid ? AppRoutes.home : AppRoutes.unsupported,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.unsupported,
        builder: (context, state) => const UnsupportedPlatformScreen(),
      ),
      GoRoute(
        path: AppRoutes.appDetail,
        builder: (context, state) {
          final packageName = state.pathParameters['packageName']!;
          return DetailScreen(packageName: packageName);
        },
      ),
      GoRoute(
        path: AppRoutes.dependencyDetail,
        builder: (context, state) {
          final packageName = state.pathParameters['packageName']!;
          return DependencyDetailScreen(packageName: packageName);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('页面不存在')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.error?.toString() ?? '未知错误'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
  );
});
