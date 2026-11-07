import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../materials/providers/material_providers.dart';
import '../data/analysis_provider.dart';
import '../models/analysis_models.dart';

/// Demo or API, chosen only by USE_DEMO_DATA; never a fallback for errors.
final analysisBackendProvider = Provider<AnalysisProvider>((ref) {
  if (ref.watch(appConfigProvider).useDemoData) {
    return DemoAnalysisProvider(
        materials: ref.watch(materialRepositoryProvider));
  }
  return ApiAnalysisProvider(ref.watch(apiClientProvider));
});

/// Polling parameters (ai-schema.md 11.3: 2 s interval, 90 s ceiling).
class PollingConfig {
  const PollingConfig({
    this.interval = const Duration(seconds: 2),
    this.ceiling = const Duration(seconds: 90),
  });
  final Duration interval;
  final Duration ceiling;
}

final pollingConfigProvider =
    Provider<PollingConfig>((_) => const PollingConfig());

enum AnalysisPhase { idle, starting, polling, done, timedOut, failed }

class AnalysisState {
  const AnalysisState({
    this.phase = AnalysisPhase.idle,
    this.analysis,
    this.analysisId,
    this.startError,
    this.pollError,
    this.failedAttempts = 0,
    this.retryAfterSeconds,
  });

  final AnalysisPhase phase;
  final Analysis? analysis;
  final String? analysisId;

  /// Error of POST /ai/analyze (409 NO_IMAGES, 429, network ...).
  final ApiException? startError;

  /// Error of a status request; the job itself may still be running.
  final ApiException? pollError;
  final int failedAttempts;
  final int? retryAfterSeconds;

  bool get busy =>
      phase == AnalysisPhase.starting || phase == AnalysisPhase.polling;

  AnalysisState copyWith({
    AnalysisPhase? phase,
    Analysis? analysis,
    String? analysisId,
    ApiException? startError,
    bool clearStartError = false,
    ApiException? pollError,
    bool clearPollError = false,
    int? failedAttempts,
    int? retryAfterSeconds,
    bool clearRetryAfter = false,
  }) =>
      AnalysisState(
        phase: phase ?? this.phase,
        analysis: analysis ?? this.analysis,
        analysisId: analysisId ?? this.analysisId,
        startError: clearStartError ? null : (startError ?? this.startError),
        pollError: clearPollError ? null : (pollError ?? this.pollError),
        failedAttempts: failedAttempts ?? this.failedAttempts,
        retryAfterSeconds: clearRetryAfter
            ? null
            : (retryAfterSeconds ?? this.retryAfterSeconds),
      );
}

class AnalysisController
    extends AutoDisposeFamilyNotifier<AnalysisState, String> {
  Timer? _timer;
  Timer? _countdown;
  Duration _elapsed = Duration.zero;
  bool _disposed = false;

  @override
  AnalysisState build(String materialId) {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      _countdown?.cancel();
    });
    return const AnalysisState();
  }

  AnalysisProvider get _backend => ref.read(analysisBackendProvider);

  /// Starts a new job. Ignored while a request or job is in flight, so a double
  /// tap cannot create two analyses.
  Future<void> start() async {
    if (state.busy || state.retryAfterSeconds != null) return;
    _timer?.cancel();
    state = AnalysisState(
      phase: AnalysisPhase.starting,
      failedAttempts: state.failedAttempts,
    );
    try {
      final s = await _backend.start(arg);
      if (_disposed) return;
      state = state.copyWith(
          phase: AnalysisPhase.polling, analysisId: s.analysisId);
      _elapsed = Duration.zero;
      _schedulePoll();
    } catch (e) {
      if (_disposed) return;
      final err = e is ApiException ? e : ApiException.network();
      state = AnalysisState(
        phase: AnalysisPhase.failed,
        startError: err,
        failedAttempts: state.failedAttempts,
        retryAfterSeconds: err.statusCode == 429 ? err.retryAfterSeconds : null,
      );
      if (state.retryAfterSeconds != null) _startCountdown();
    }
  }

  /// "Проверить снова": resumes polling of the same analysis after the ceiling.
  void resume() {
    if (state.phase != AnalysisPhase.timedOut || state.analysisId == null) {
      return;
    }
    state = state.copyWith(phase: AnalysisPhase.polling, clearPollError: true);
    _elapsed = Duration.zero;
    _poll();
  }

  void _schedulePoll() {
    _timer?.cancel();
    _timer = Timer(ref.read(pollingConfigProvider).interval, _poll);
  }

  Future<void> _poll() async {
    final id = state.analysisId;
    if (id == null || _disposed) return;
    final cfg = ref.read(pollingConfigProvider);
    try {
      final a = await _backend.get(id);
      if (_disposed) return;
      if (a.status.isActive) {
        state = state.copyWith(analysis: a, clearPollError: true);
      } else {
        final failed = a.status.isFailure;
        state = state.copyWith(
          phase: failed ? AnalysisPhase.failed : AnalysisPhase.done,
          analysis: a,
          clearPollError: true,
          failedAttempts: failed ? state.failedAttempts + 1 : 0,
        );
        return;
      }
    } catch (e) {
      if (_disposed) return;
      // A failed status request is not a failed job: keep polling until the ceiling.
      state = state.copyWith(
          pollError: e is ApiException ? e : ApiException.network());
    }
    _elapsed += cfg.interval;
    if (_elapsed >= cfg.ceiling) {
      state = state.copyWith(phase: AnalysisPhase.timedOut);
      return;
    }
    _schedulePoll();
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = (state.retryAfterSeconds ?? 0) - 1;
      if (left <= 0) {
        t.cancel();
        state = state.copyWith(clearRetryAfter: true);
      } else {
        state = state.copyWith(retryAfterSeconds: left);
      }
    });
  }
}

final analysisControllerProvider = AutoDisposeNotifierProviderFamily<
    AnalysisController, AnalysisState, String>(AnalysisController.new);
