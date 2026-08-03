import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';

import 'settings_service.dart';

typedef ProgressCallback = void Function(double? fraction, String logLine);

class FfmpegNotFoundException implements Exception {
  final String message;
  FfmpegNotFoundException(this.message);
}

class CompressionResult {
  final int outputBytes;
  final String? thumbnailPath;
  final String? outputPath;

  const CompressionResult({
    required this.outputBytes,
    this.thumbnailPath,
    this.outputPath,
  });
}

class FfmpegService {
  FfmpegService._();

  static String? _ffmpegPath;
  static String? _ffprobePath;

  static Future<String?> findExecutable(String name) async {
    final exeName = Platform.isWindows ? '$name.exe' : name;

    // 1. Check in same directory as application binary
    try {
      final appDir = File(Platform.resolvedExecutable).parent;
      final localExe = File('${appDir.path}${Platform.pathSeparator}$exeName');
      if (await localExe.exists()) {
        return localExe.path;
      }
    } catch (_) {}

    // 2. Check system PATH using OS-appropriate lookup tool
    try {
      final command = Platform.isWindows ? 'where.exe' : 'which';
      final result = await Process.run(command, [exeName]);
      if (result.exitCode == 0) {
        final parts = (result.stdout as String)
            .trim()
            .split('\n')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) return parts.first;
      }
    } catch (_) {}

    return null;
  }

  static int targetBytesForKb(num kb) {
    return (kb * 1024).round().clamp(64, 1024 * 1024);
  }

  static Future<Directory> outputDirectory() async {
    final custom = SettingsService.instance.customOutputDir;
    if (custom != null && custom.trim().isNotEmpty) {
      final dir = Directory(custom);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}shitaka_memes_out');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> openPath(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {}
  }

  static Future<String> ffmpegPath() async {
    if (_ffmpegPath != null) return _ffmpegPath!;
    final found = await findExecutable('ffmpeg');
    if (found == null) {
      throw FfmpegNotFoundException(
        'ffmpeg was not found on this system.\n\n'
        'Please ensure ffmpeg is installed in system PATH or placed in the application folder.',
      );
    }
    _ffmpegPath = found;
    return found;
  }

  static Future<String?> ffprobePath() async {
    if (_ffprobePath != null) return _ffprobePath;
    _ffprobePath = await findExecutable('ffprobe');
    return _ffprobePath;
  }

  static Future<CompressionResult> compressImage({
    required String input,
    required String output,
    required int targetBytes,
    ProgressCallback? onProgress,
  }) async {
    final ffmpeg = await ffmpegPath();
    final target = targetBytes;
    int scale = 1024;
    int q = 8;
    bool gray = false;
    int current = -1;

    for (int i = 0; i < 18; i++) {
      final args = [
        '-y',
        '-hide_banner',
        '-loglevel', 'error',
        '-i', input,
        '-vf', "scale='trunc(min($scale,iw)/2)*2':-2${gray ? ',format=gray' : ''}",
        '-q:v', '$q',
        '-frames:v', '1',
        output,
      ];

      await Process.run(ffmpeg, args);
      current = await _fileSize(output);
      onProgress?.call(null, _imageLog(scale, q, current, target));

      if (current > 0 && current <= target) break;
      if (current <= 0) break;

      scale = (scale * 3) ~/ 4;
      q = math.min(31, q + 4);
      if (scale < 96) gray = true;
    }

    return CompressionResult(outputBytes: current > 0 ? current : 0);
  }

  static String _imageLog(int scale, int q, int size, int target) {
    final s = size < 0 ? '…' : '$size B';
    final pass = [
      'Assaulting the pixels (${scale}px, q=$q)…',
      'Current damage: $s / $target B',
      'The pixels never saw this coming…',
      'How small can it go? ($s so far)',
    ];
    return pass[math.Random().nextInt(pass.length)];
  }

  static Future<CompressionResult> compressVideo({
    required String input,
    required String output,
    required String? thumbnailOut,
    required int targetBytes,
    required bool mute,
    ProgressCallback? onProgress,
  }) async {
    final ffmpeg = await ffmpegPath();
    final ffprobe = await ffprobePath();

    final target = targetBytes;
    int scale = 640;
    int fps = 24;
    int crf = 30;
    int current = -1;

    double? duration;
    if (ffprobe != null) {
      final probe = await Process.run(ffprobe, [
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        input,
      ]);
      duration = double.tryParse((probe.stdout as String).trim());
    }

    for (int i = 0; i < 18; i++) {
      final args = [
        '-y',
        '-hide_banner',
        '-i', input,
        '-vf', "scale='trunc(min($scale,iw)/2)*2':-2,fps=$fps",
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-crf', '$crf',
        if (mute)
          '-an'
        else ...[
          '-c:a', 'aac',
          '-b:a', '12k',
        ],
        '-movflags', '+faststart',
        output,
      ];

      await _runStreaming(
        ffmpeg,
        args,
        duration: duration,
        onProgress: onProgress,
        onLine: (line) {
          onProgress?.call(null, line);
        },
      );

      current = await _fileSize(output);
      onProgress?.call(null, _videoLog(scale, crf, current, target));

      if (current > 0 && current <= target) break;
      if (current <= 0) break;

      scale = (scale * 3) ~/ 4;
      fps = math.max(2, fps - 4);
      crf = math.min(51, crf + 6);
    }

    String? thumb;
    if (thumbnailOut != null && await File(output).exists()) {
      try {
        await Process.run(ffmpeg, [
          '-y',
          '-hide_banner',
          '-loglevel', 'error',
          '-i', input,
          '-ss', '0',
          '-frames:v', '1',
          thumbnailOut,
        ]);
        if (await File(thumbnailOut).exists()) thumb = thumbnailOut;
      } catch (_) {
        thumb = null;
      }
    }

    return CompressionResult(
      outputBytes: current > 0 ? current : 0,
      thumbnailPath: thumb,
    );
  }

  static String _videoLog(int scale, int crf, int size, int target) {
    final s = size < 0 ? '…' : '$size B';
    final pass = [
      'Crushing the frame rate (${scale}px, crf $crf)…',
      'Negotiating with the encoder… $s',
      'The video is feeling really compressed rn…',
      'Frame budget: not looking good ($s / $target B)',
    ];
    return pass[math.Random().nextInt(pass.length)];
  }

  static Future<void> _runStreaming(
    String exe,
    List<String> args, {
    required double? duration,
    ProgressCallback? onProgress,
    void Function(String line)? onLine,
  }) async {
    final process = await Process.start(exe, args);
    final stderr = process.stderr.transform(
      const SystemEncoding().decoder,
    ).transform(const LineSplitter());

    await for (final line in stderr) {
      final time = _extractTime(line);
      if (time != null && duration != null && duration > 0) {
        onProgress?.call((time / duration).clamp(0.0, 1.0), _prettyLine(line));
      } else if (onLine != null && line.trim().isNotEmpty) {
        onLine(line);
      }
    }
    await process.exitCode;
  }

  static double? _extractTime(String line) {
    final match = RegExp(r'time=(\d+):(\d+):([\d.]+)').firstMatch(line);
    if (match == null) return null;
    final h = double.parse(match.group(1)!);
    final m = double.parse(match.group(2)!);
    final s = double.parse(match.group(3)!);
    return h * 3600 + m * 60 + s;
  }

  static String _prettyLine(String line) {
    final frame = RegExp(r'frame=\s*(\d+)').firstMatch(line);
    final fps = RegExp(r'fps=\s*([\d.]+)').firstMatch(line);
    final speed = RegExp(r'speed=\s*([\d.]+x)').firstMatch(line);
    if (frame != null || fps != null || speed != null) {
      return 'frame=${frame?.group(1) ?? '?'} '
          'fps=${fps?.group(1) ?? '?'} '
          'speed=${speed?.group(1) ?? '?'}';
    }
    return line.trim();
  }

  static Future<int> _fileSize(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return -1;
      return await f.length();
    } catch (_) {
      return -1;
    }
  }
}