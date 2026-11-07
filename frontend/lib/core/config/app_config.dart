import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Build-time configuration. No production defaults are hardcoded:
/// pass `--dart-define=API_BASE_URL=...` explicitly.
class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.useDemoData});

  factory AppConfig.fromEnvironment() => const AppConfig(
        apiBaseUrl: String.fromEnvironment('API_BASE_URL'),
        // Explicit opt-in: --dart-define=USE_DEMO_DATA=true
        useDemoData: bool.fromEnvironment('USE_DEMO_DATA'),
      );

  final String apiBaseUrl;
  final bool useDemoData;
}

final appConfigProvider =
    Provider<AppConfig>((ref) => AppConfig.fromEnvironment());
