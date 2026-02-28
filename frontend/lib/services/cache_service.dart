import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheService {
  String? _cacheDir;

  Future<String> get _dir async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = '${appDir.path}/brew_haiku_cache';
    final dir = Directory(_cacheDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _cacheDir!;
  }

  String _keyToFile(String key) => key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  Future<void> write(String key, dynamic data) async {
    final dir = await _dir;
    final file = File('$dir/${_keyToFile(key)}.json');
    await file.writeAsString(jsonEncode({
      'data': data,
      'cachedAt': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  Future<T?> read<T>(String key, {Duration? maxAge}) async {
    try {
      final dir = await _dir;
      final file = File('$dir/${_keyToFile(key)}.json');
      if (!await file.exists()) return null;

      final content = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (maxAge != null) {
        final cachedAt = content['cachedAt'] as int;
        final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
        if (age > maxAge.inMilliseconds) return null;
      }
      return content['data'] as T?;
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String key) async {
    try {
      final dir = await _dir;
      final file = File('$dir/${_keyToFile(key)}.json');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
