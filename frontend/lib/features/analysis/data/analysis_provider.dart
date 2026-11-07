import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../materials/data/material_repository.dart';
import '../models/analysis_models.dart';

/// Source of analyses. The screen depends only on this interface, so the demo
/// implementation can never be mixed with API calls.
abstract class AnalysisProvider {
  Future<AnalysisStart> start(String materialId);
  Future<Analysis> get(String analysisId);
}

/// ai-schema.md 11.1/11.2: the request carries only `material_id`; the server
/// picks the stored photos and the input version itself.
class ApiAnalysisProvider implements AnalysisProvider {
  ApiAnalysisProvider(this._client);
  final ApiClient _client;

  @override
  Future<AnalysisStart> start(String materialId) => apiCall(() async {
        final r = await _client.dio
            .post<Object>('/ai/analyze', data: {'material_id': materialId});
        return AnalysisStart.fromJson(r.data);
      });

  @override
  Future<Analysis> get(String analysisId) => apiCall(() async {
        final r = await _client.dio.get<Object>('/ai/analyses/$analysisId');
        return Analysis.fromJson(r.data);
      });
}

typedef FixtureLoader = Future<String> Function();

Future<String> _loadBundledFixture() =>
    rootBundle.loadString('assets/demo/demo-analysis.json');

/// Prepared example for the offline demo. Makes no network calls. It mimics the
/// server rules it can: no photos -> 409 NO_IMAGES, version change -> stale.
class DemoAnalysisProvider implements AnalysisProvider {
  DemoAnalysisProvider({
    required MaterialRepository materials,
    FixtureLoader? loadFixture,
    this.delay = const Duration(milliseconds: 1200),
  })  : _materials = materials,
        _load = loadFixture ?? _loadBundledFixture;

  final MaterialRepository _materials;
  final FixtureLoader _load;
  final Duration delay;
  final Map<String, ({String materialId, int version, int polls})> _jobs = {};
  int _seq = 0;

  @override
  Future<AnalysisStart> start(String materialId) async {
    final m = await _materials.get(materialId);
    if (m.images.isEmpty) {
      throw const ApiException(
        code: 'PRECONDITION_FAILED',
        message: 'Добавьте хотя бы одно фото партии.',
        statusCode: 409,
        details: {'reason': 'NO_IMAGES'},
      );
    }
    final id = 'demo-analysis-${_seq++}';
    _jobs[id] = (materialId: materialId, version: m.version, polls: 0);
    return AnalysisStart(analysisId: id, status: AnalysisStatus.pending);
  }

  @override
  Future<Analysis> get(String analysisId) async {
    final job = _jobs[analysisId];
    if (job == null) {
      throw const ApiException(
          code: 'NOT_FOUND', message: 'Анализ не найден.', statusCode: 404);
    }
    _jobs[analysisId] = (
      materialId: job.materialId,
      version: job.version,
      polls: job.polls + 1
    );
    final fixture = jsonDecode(await _load()) as Map<String, dynamic>;
    if (job.polls == 0) {
      // First poll shows progress, as a real job would.
      await Future<void>.delayed(delay);
      return Analysis(
        id: analysisId,
        materialId: job.materialId,
        status: AnalysisStatus.running,
        inputVersion: job.version,
        isCurrent: true,
      );
    }
    final current = (await _materials.get(job.materialId)).version;
    return Analysis.fromJson({
      ...fixture,
      'id': analysisId,
      'material_id': job.materialId,
      'input_version': job.version,
      'is_current': current == job.version,
      'mode': 'demo',
    });
  }
}
