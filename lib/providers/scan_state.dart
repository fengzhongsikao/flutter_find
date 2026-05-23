import '../models/flutter_app_info.dart';
import '../services/scanner_service.dart';

class ScanState {
  const ScanState({
    this.rawApps = const [],
    this.filteredApps = const [],
    this.isScanning = false,
    this.progress,
    this.error,
    this.searchQuery = '',
    this.sortMode = SortMode.name,
  });

  final List<FlutterAppSummary> rawApps;
  final List<FlutterAppSummary> filteredApps;
  final bool isScanning;
  final ScanProgress? progress;
  final String? error;
  final String searchQuery;
  final SortMode sortMode;

  List<FlutterAppSummary> get apps => filteredApps;
  int get totalFound => rawApps.length;

  static const initial = ScanState();

  ScanState copyWith({
    List<FlutterAppSummary>? rawApps,
    List<FlutterAppSummary>? filteredApps,
    bool? isScanning,
    ScanProgress? progress,
    String? error,
    bool clearError = false,
    String? searchQuery,
    SortMode? sortMode,
  }) {
    return ScanState(
      rawApps: rawApps ?? this.rawApps,
      filteredApps: filteredApps ?? this.filteredApps,
      isScanning: isScanning ?? this.isScanning,
      progress: progress ?? this.progress,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      sortMode: sortMode ?? this.sortMode,
    );
  }
}
