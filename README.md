# Flutter Find

在 Android 设备上扫描已安装应用，识别由 Flutter 框架构建的 App，并展示 Flutter/Dart 版本与第三方依赖信息。

## 功能

- 启动后自动扫描设备上的全部应用
- 识别 Flutter 应用（`libflutter.so`、`flutter_assets` 等特征）
- 主页列表：浏览、按名称或 Flutter 版本排序、搜索
- 应用详情：名称、图标、版本、包名、Flutter/Dart 版本、依赖列表
- 依赖详情：包名、pub.dev 描述、跳转官方链接

## 环境要求

- Flutter SDK（建议 stable）
- Android 设备或模拟器（API 21+）
- 侧载安装；需要 `QUERY_ALL_PACKAGES` 权限以枚举全部应用

## 运行

```bash
flutter pub get
flutter run
```

## 检测说明

| 信息 | 来源 |
|------|------|
| 是否为 Flutter App | APK 内 `libflutter.so` 或 `assets/flutter_assets/` |
| Flutter 版本 | `libflutter.so` 字符串 + 可选 engine 映射表 |
| Dart 版本 | `libflutter.so` 内嵌字符串 |
| 依赖包名 | `assets/flutter_assets/NOTICES.Z`（双 gzip 解压）及 `packages/` 路径 |
| 依赖描述 | [pub.dev API](https://pub.dev/api/packages/{name})（需联网） |

Release APK 通常不包含 `pubspec.lock`，依赖详情不展示精确版本号；版本历史请在 pub.dev 查看。

## 权限

- `QUERY_ALL_PACKAGES`：枚举已安装应用
- `INTERNET`：拉取 pub.dev 包描述

## 项目结构

```
lib/           # Flutter UI（Riverpod 状态管理 + go-router 路由）
android/.../   # Kotlin 扫描器（ZipFile、版本解析、NOTICES 解析）
```

## License

MIT
