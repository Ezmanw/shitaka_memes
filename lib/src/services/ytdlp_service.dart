import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'ffmpeg_service.dart';

class YtdlpNotFoundException implements Exception {
  final String message;
  YtdlpNotFoundException(this.message);
}

class YtdlpService {
  YtdlpService._();

  static String? _ytdlpPath;

  static Future<String> ytdlpPath() async {
    if (_ytdlpPath != null) return _ytdlpPath!;
    final found = await FfmpegService.findExecutable('yt-dlp');
    if (found == null) {
      throw YtdlpNotFoundException(
        'yt-dlp was not found on this system.\n\n'
        'Please ensure yt-dlp is installed in system PATH or placed in the application folder.',
      );
    }
    _ytdlpPath = found;
    return found;
  }

  static Future<File> downloadVideo(
    String url, {
    void Function(String line)? onProgress,
  }) async {
    final exe = await ytdlpPath();
    final tempDir = await getTemporaryDirectory();
    final time = DateTime.now().millisecondsSinceEpoch;
    final outPattern = '${tempDir.path}${Platform.pathSeparator}shitaka_yt_$time.%(ext)s';

    final args = [
      '--no-playlist',
      '--no-warnings',
      '-f', 'b[ext=mp4]/b/bv*+ba/b',
      '-o', outPattern,
      url.trim(),
    ];

    final process = await Process.start(exe, args);

    final completer = Completer<int>();

    process.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.trim().isNotEmpty) {
        onProgress?.call(line.trim());
      }
    });

    process.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.trim().isNotEmpty) {
        onProgress?.call(line.trim());
      }
    });

    process.exitCode.then((code) {
      if (!completer.isCompleted) completer.complete(code);
    });

    final exitCode = await completer.future;
    if (exitCode != 0) {
      throw Exception('yt-dlp failed with exit code $exitCode');
    }

    final list = tempDir.listSync().whereType<File>().where(
          (f) => f.path.contains('shitaka_yt_$time'),
        ).toList();

    if (list.isEmpty) {
      throw Exception('Downloaded file could not be found.');
    }

    return list.first;
  }

  static Future<File> downloadVideoToDirectory(
    String url,
    Directory targetDir, {
    void Function(String line)? onProgress,
  }) async {
    final exe = await ytdlpPath();
    final time = DateTime.now().millisecondsSinceEpoch;
    final outPattern =
        '${targetDir.path}${Platform.pathSeparator}%(title).100s_$time.%(ext)s';

    final args = [
      '--no-playlist',
      '--no-warnings',
      '-f',
      'b[ext=mp4]/b/bv*+ba/b',
      '-o',
      outPattern,
      url.trim(),
    ];

    final process = await Process.start(exe, args);
    final completer = Completer<int>();

    process.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.trim().isNotEmpty) {
        onProgress?.call(line.trim());
      }
    });

    process.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.trim().isNotEmpty) {
        onProgress?.call(line.trim());
      }
    });

    process.exitCode.then((code) {
      if (!completer.isCompleted) completer.complete(code);
    });

    final exitCode = await completer.future;
    if (exitCode != 0) {
      throw Exception('yt-dlp failed with exit code $exitCode');
    }

    final list = targetDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('_$time'))
        .toList();

    if (list.isEmpty) {
      throw Exception('Downloaded file could not be found.');
    }

    return list.first;
  }
}
