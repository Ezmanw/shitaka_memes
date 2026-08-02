import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/compression_job.dart';

class HistoryStore {
  HistoryStore._();
  static final HistoryStore instance = HistoryStore._();

  static const int _maxEntries = 200;
  final ValueNotifier<List<CompressionJob>> jobs = ValueNotifier([]);
  File? _file;

  Future<File> _ensureFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}history.json');
    _file = file;
    return file;
  }

  Future<void> load() async {
    try {
      final file = await _ensureFile();
      if (!await file.exists()) return;
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>? ?? [];
      jobs.value = list
          .map((e) => CompressionJob.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<void> add(CompressionJob job) async {
    final current = List<CompressionJob>.from(jobs.value)
      ..insert(0, job);
    if (current.length > _maxEntries) {
      current.removeRange(_maxEntries, current.length);
    }
    jobs.value = current;
    await _save();
  }

  Future<void> clear() async {
    jobs.value = [];
    await _save();
  }

  Future<void> _save() async {
    try {
      final file = await _ensureFile();
      final encoded = jsonEncode(
        jobs.value.map((j) => j.toJson()).toList(),
      );
      await file.writeAsString(encoded);
    } catch (_) {}
  }
}
