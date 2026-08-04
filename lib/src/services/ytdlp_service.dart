import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'ffmpeg_service.dart';

class YtdlpNotFoundException implements Exception {
  final String message;
  YtdlpNotFoundException(this.message);

  @override
  String toString() => message;
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

  static bool isYoutubeUrl(String url) {
    return RegExp(r'(youtube\.com|youtu\.be)', caseSensitive: false).hasMatch(url);
  }

  static Future<File> downloadNativeStream(
    String url,
    Directory targetDir, {
    void Function(String line)? onProgress,
  }) async {
    final cleanUrl = url.trim();
    if (isYoutubeUrl(cleanUrl)) {
      final yt = YoutubeExplode();
      try {
        onProgress?.call('Fetching YouTube video info...');
        final video = await yt.videos.get(cleanUrl);
        final manifest = await yt.videos.streamsClient.getManifest(video.id);
        final streamInfo = manifest.muxed.withHighestBitrate();

        final safeTitle = video.title.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final time = DateTime.now().millisecondsSinceEpoch;
        final ext = streamInfo.container.name;
        final file = File('${targetDir.path}${Platform.pathSeparator}${safeTitle}_$time.$ext');

        onProgress?.call('Downloading stream (${streamInfo.videoQualityLabel})...');
        final stream = yt.videos.streamsClient.get(streamInfo);
        final sink = file.openWrite();

        int downloaded = 0;
        final total = streamInfo.size.totalBytes;

        await for (final chunk in stream) {
          downloaded += chunk.length;
          sink.add(chunk);
          if (total > 0) {
            final pct = ((downloaded / total) * 100).round();
            onProgress?.call('Downloading YouTube video ($pct%)…');
          }
        }

        await sink.flush();
        await sink.close();
        return file;
      } finally {
        yt.close();
      }
    } else {
      onProgress?.call('Downloading direct video stream...');
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(cleanUrl));
      final response = await request.close();

      final time = DateTime.now().millisecondsSinceEpoch;
      final ext = cleanUrl.contains('.webm') ? 'webm' : 'mp4';
      final file = File('${targetDir.path}${Platform.pathSeparator}video_$time.$ext');

      final sink = file.openWrite();
      int downloaded = 0;
      final total = response.contentLength;

      await for (final chunk in response) {
        downloaded += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          final pct = ((downloaded / total) * 100).round();
          onProgress?.call('Downloading file ($pct%)…');
        }
      }

      await sink.flush();
      await sink.close();
      return file;
    }
  }

  static Future<File> downloadVideo(
    String url, {
    void Function(String line)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();

    if ((await FfmpegService.findExecutable('yt-dlp')) == null) {
      return downloadNativeStream(url, tempDir, onProgress: onProgress);
    }

    final exe = await ytdlpPath();
    final time = DateTime.now().millisecondsSinceEpoch;
    final outPattern = '${tempDir.path}${Platform.pathSeparator}shitaka_yt_$time.%(ext)s';

    final args = [
      '--no-playlist',
      '--no-warnings',
      '-f', 'b[ext=mp4]/b/bv*+ba/b',
      '-o', outPattern,
      url.trim(),
    ];

    Process process;
    try {
      process = await Process.start(exe, args);
    } on ProcessException catch (_) {
      return downloadNativeStream(url, tempDir, onProgress: onProgress);
    }

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
      return downloadNativeStream(url, tempDir, onProgress: onProgress);
    }

    final list = tempDir.listSync().whereType<File>().where(
          (f) => f.path.contains('shitaka_yt_$time'),
        ).toList();

    if (list.isEmpty) {
      return downloadNativeStream(url, tempDir, onProgress: onProgress);
    }

    return list.first;
  }

  static Future<File> downloadVideoToDirectory(
    String url,
    Directory targetDir, {
    void Function(String line)? onProgress,
  }) async {
    if ((await FfmpegService.findExecutable('yt-dlp')) == null) {
      return downloadNativeStream(url, targetDir, onProgress: onProgress);
    }

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

    Process process;
    try {
      process = await Process.start(exe, args);
    } on ProcessException catch (_) {
      return downloadNativeStream(url, targetDir, onProgress: onProgress);
    }
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
      return downloadNativeStream(url, targetDir, onProgress: onProgress);
    }

    final list = targetDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('_$time'))
        .toList();

    if (list.isEmpty) {
      return downloadNativeStream(url, targetDir, onProgress: onProgress);
    }

    return list.first;
  }
}
