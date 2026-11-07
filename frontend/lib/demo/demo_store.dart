// SYNTHETIC DEMO DATA STORAGE. Used only with --dart-define=USE_DEMO_DATA=true.
//
// Persistence choice: one folder `demo_data/` inside the app documents
// directory, holding `demo_materials.json` and `demo_photos/`. Photos are
// binary files anyway, so a single folder that can be deleted as a whole keeps
// reset trivial and keeps demo data physically apart from anything real
// (shared_preferences would need a second mechanism for the photos).
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

abstract class DemoStore {
  /// Raw JSON of the demo state, or null when nothing was saved yet.
  Future<String?> readState();
  Future<void> writeState(String json);

  /// Copies [bytes] into the app-private demo folder under a random name
  /// (never the gallery) and returns that file name.
  Future<String> savePhoto(Uint8List bytes, String extension);

  /// Absolute path of a saved photo, or null if it cannot be shown.
  Future<String?> photoPath(String fileName);

  /// Deletes every demo file.
  Future<void> clear();
}

String randomHex(int bytes, [Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(
      bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Used by tests and on web (no app folder there): nothing survives a restart.
class MemoryDemoStore implements DemoStore {
  String? _state;
  final Map<String, Uint8List> photos = {};

  @override
  Future<String?> readState() async => _state;

  @override
  Future<void> writeState(String json) async => _state = json;

  @override
  Future<String> savePhoto(Uint8List bytes, String extension) async {
    final name = 'demo_${randomHex(12)}.$extension';
    photos[name] = bytes;
    return name;
  }

  @override
  Future<String?> photoPath(String fileName) async => null;

  @override
  Future<void> clear() async {
    _state = null;
    photos.clear();
  }
}

class FileDemoStore implements DemoStore {
  /// [rootResolver] returns the demo folder (created on demand).
  FileDemoStore(this._rootResolver);

  final Future<Directory> Function() _rootResolver;
  Directory? _root;

  Future<Directory> _dir() async {
    final r = _root ??= await _rootResolver();
    if (!await r.exists()) await r.create(recursive: true);
    return r;
  }

  Future<File> _stateFile() async =>
      File('${(await _dir()).path}/demo_materials.json');

  Future<Directory> _photoDir() async {
    final d = Directory('${(await _dir()).path}/demo_photos');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  @override
  Future<String?> readState() async {
    final f = await _stateFile();
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<void> writeState(String json) async {
    final f = await _stateFile();
    // Write-then-rename so a crash never leaves a half-written file.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<String> savePhoto(Uint8List bytes, String extension) async {
    final name = 'demo_${randomHex(12)}.$extension';
    await File('${(await _photoDir()).path}/$name')
        .writeAsBytes(bytes, flush: true);
    return name;
  }

  @override
  Future<String?> photoPath(String fileName) async {
    // File names come from our own state file; refuse anything path-like.
    if (fileName.contains('/') || fileName.contains('..')) return null;
    final f = File('${(await _photoDir()).path}/$fileName');
    return await f.exists() ? f.path : null;
  }

  @override
  Future<void> clear() async {
    final d = await _dir();
    if (await d.exists()) await d.delete(recursive: true);
  }
}

/// Decodes persisted state; a corrupt file is treated as "no state" so the demo
/// restarts from the seed instead of crashing.
Map<String, dynamic>? decodeState(String? raw) {
  if (raw == null) return null;
  try {
    final v = jsonDecode(raw);
    return v is Map<String, dynamic> ? v : null;
  } catch (_) {
    return null;
  }
}
