import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:light_compressor_v2/light_compressor_v2.dart' as lc;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart' as vc;

import 'settings_service.dart';

typedef ProgressCallback = void Function(double? fraction, String logLine);

class FfmpegNotFoundException implements Exception {
  final String message;
  FfmpegNotFoundException(this.message);

  @override
  String toString() => message;
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

    // 1b. Check in application support directory
    try {
      final supportDir = await getApplicationSupportDirectory();
      final supportExe = File('${supportDir.path}${Platform.pathSeparator}$exeName');
      if (await supportExe.exists()) {
        return supportExe.path;
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

  static Future<void> downloadFfmpegAuto({
    void Function(String status)? onProgress,
  }) async {
    final supportDir = await getApplicationSupportDirectory();
    if (!await supportDir.exists()) {
      await supportDir.create(recursive: true);
    }

    if (Platform.isWindows) {
      onProgress?.call('Fetching FFmpeg static build for Windows...');
      final zipPath = '${supportDir.path}${Platform.pathSeparator}ffmpeg_temp.zip';
      final extractDir = '${supportDir.path}${Platform.pathSeparator}ffmpeg_temp_dir';

      final script = '''
        Invoke-WebRequest -Uri "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip" -OutFile "$zipPath"
        Expand-Archive -Path "$zipPath" -DestinationPath "$extractDir" -Force
        \$fExe = Get-ChildItem -Path "$extractDir" -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
        \$fpExe = Get-ChildItem -Path "$extractDir" -Recurse -Filter "ffprobe.exe" | Select-Object -First 1
        Copy-Item -Path \$fExe.FullName -Destination "${supportDir.path}" -Force
        Copy-Item -Path \$fpExe.FullName -Destination "${supportDir.path}" -Force
        Remove-Item -Path "$zipPath" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$extractDir" -Recurse -Force -ErrorAction SilentlyContinue
      ''';

      final process = await Process.run('powershell', ['-Command', script]);
      if (process.exitCode != 0) {
        throw Exception('Failed to download FFmpeg: ${process.stderr}');
      }
    } else {
      throw Exception('Automatic download is supported on Windows. Please install FFmpeg via your package manager.');
    }

    _ffmpegPath = null;
    _ffprobePath = null;
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
    if (Platform.isAndroid) return 'ffmpeg';
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
    final isGif = input.toLowerCase().endsWith('.gif') || output.toLowerCase().endsWith('.gif');

    if (Platform.isAndroid || (await findExecutable('ffmpeg')) == null) {
      if (isGif) {
        return compressGifDart(
          input: input,
          output: output,
          targetBytes: targetBytes,
          onProgress: onProgress,
        );
      }
      return compressImageDart(
        input: input,
        output: output,
        targetBytes: targetBytes,
        onProgress: onProgress,
      );
    }

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
        output,
      ];

      try {
        await Process.run(ffmpeg, args);
        current = await _fileSize(output);
        onProgress?.call(null, _imageLog(scale, q, current, target));

        if (current > 0 && current <= target) break;
        if (current <= 0) break;
      } on ProcessException catch (_) {
        if (isGif) {
          return compressGifDart(
            input: input,
            output: output,
            targetBytes: targetBytes,
            onProgress: onProgress,
          );
        }
        return compressImageDart(
          input: input,
          output: output,
          targetBytes: targetBytes,
          onProgress: onProgress,
        );
      }

      scale = (scale * 3) ~/ 4;
      q = math.min(31, q + 4);
      if (scale < 96) gray = true;
    }

    return CompressionResult(outputBytes: current > 0 ? current : 0);
  }

  static Future<CompressionResult> compressGifDart({
    required String input,
    required String output,
    required int targetBytes,
    ProgressCallback? onProgress,
  }) async {
    try {
      final bytes = await File(input).readAsBytes();
      final decoded = img.decodeGif(bytes) ?? img.decodeImage(bytes);
      if (decoded == null) {
        await File(input).copy(output);
        return CompressionResult(outputBytes: await _fileSize(output));
      }

      int width = decoded.width;
      int current = -1;

      for (int i = 0; i < 18; i++) {
        final resized = (width < decoded.width)
            ? img.copyResize(decoded, width: width)
            : decoded;

        final encoded = img.encodeGif(resized);
        await File(output).writeAsBytes(encoded);
        current = encoded.length;

        onProgress?.call(null, _imageLog(width, 10, current, targetBytes));

        if (current > 0 && current <= targetBytes) break;

        width = (width * 3) ~/ 4;
        if (width < 48) break;
      }

      return CompressionResult(outputBytes: current > 0 ? current : 0);
    } catch (_) {
      try {
        await File(input).copy(output);
        return CompressionResult(outputBytes: await _fileSize(output));
      } catch (_) {
        return CompressionResult(outputBytes: 0);
      }
    }
  }

  static Future<CompressionResult> compressImageDart({
    required String input,
    required String output,
    required int targetBytes,
    ProgressCallback? onProgress,
  }) async {
    try {
      final bytes = await File(input).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        await File(input).copy(output);
        return CompressionResult(outputBytes: await _fileSize(output));
      }

      int width = decoded.width;
      int quality = 85;
      int current = -1;

      for (int i = 0; i < 18; i++) {
        final resized = (width < decoded.width)
            ? img.copyResize(decoded, width: width)
            : decoded;

        final encoded = img.encodeJpg(resized, quality: quality);
        await File(output).writeAsBytes(encoded);
        current = encoded.length;

        onProgress?.call(null, _imageLog(width, quality, current, targetBytes));

        if (current > 0 && current <= targetBytes) break;

        width = (width * 3) ~/ 4;
        quality = math.max(10, quality - 15);
        if (width < 64) break;
      }

      return CompressionResult(outputBytes: current > 0 ? current : 0);
    } catch (_) {
      try {
        await File(input).copy(output);
        return CompressionResult(outputBytes: await _fileSize(output));
      } catch (_) {
        return CompressionResult(outputBytes: 0);
      }
    }
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
    if (Platform.isAndroid || (await findExecutable('ffmpeg')) == null) {
      try {
        onProgress?.call(null, 'Assaulting video frames natively...');

        final inputSize = File(input).existsSync() ? File(input).lengthSync() : 0;

        // 0. Primary Android Engine: FFmpegKit (Full FFmpeg libx264 engine)
        if (Platform.isAndroid) {
          try {
            onProgress?.call(null, 'Encoding video with FFmpeg engine...');

            final target = targetBytes;
            int scale = 640;
            int fps = 24;
            int crf = 30;

            if (target < 2 * 1024 * 1024) {
              scale = 480;
              fps = 20;
              crf = 34;
            } else if (target < 8 * 1024 * 1024) {
              scale = 640;
              fps = 24;
              crf = 30;
            } else if (target < 25 * 1024 * 1024) {
              scale = 854;
              fps = 24;
              crf = 28;
            } else {
              scale = 1280;
              fps = 30;
              crf = 24;
            }

            final audioArg = mute ? '-an' : '-c:a aac -b:a 96k';
            final cmd = '-y -i "$input" -vf "scale=w=\'min(iw,$scale)\':h=-2,fps=$fps" -c:v libx264 -crf $crf -preset ultrafast $audioArg "$output"';

            final session = await FFmpegKit.execute(cmd);
            final returnCode = await session.getReturnCode();

            if (ReturnCode.isSuccess(returnCode)) {
              final size = await _fileSize(output);
              if (size > 0 && (inputSize == 0 || size < inputSize)) {
                String? thumb;
                if (thumbnailOut != null) {
                  try {
                    final thumbCmd = '-y -ss 00:00:01 -i "$input" -vframes 1 "$thumbnailOut"';
                    await FFmpegKit.execute(thumbCmd);
                    if (File(thumbnailOut).existsSync()) {
                      thumb = thumbnailOut;
                    }
                  } catch (_) {}
                }

                onProgress?.call(1.0, 'Finished FFmpeg video compression!');
                return CompressionResult(
                  outputBytes: size,
                  thumbnailPath: thumb,
                  outputPath: output,
                );
              }
            }
          } catch (e) {
            onProgress?.call(null, 'FFmpegKit failed, falling back to MediaCodec: $e');
          }
        }

        // 1. Secondary Engine: LightCompressor (Android native MediaCodec with explicit resolution downscaling)
        try {
          final lightCompressor = lc.LightCompressor();

          lc.VideoQuality quality;
          int w;
          int h;

          if (targetBytes < 2 * 1024 * 1024) {
            quality = lc.VideoQuality.very_low;
            w = 480;
            h = 270;
          } else if (targetBytes < 8 * 1024 * 1024) {
            quality = lc.VideoQuality.low;
            w = 640;
            h = 360;
          } else if (targetBytes < 25 * 1024 * 1024) {
            quality = lc.VideoQuality.medium;
            w = 960;
            h = 540;
          } else {
            quality = lc.VideoQuality.high;
            w = 1280;
            h = 720;
          }

          final response = await lightCompressor.compressVideo(
            path: input,
            videoQuality: quality,
            android: lc.AndroidConfig(isSharedStorage: false),
            ios: lc.IOSConfig(saveInGallery: false),
            video: lc.Video(
              videoName: 'SHIT_${DateTime.now().millisecondsSinceEpoch}.mp4',
              videoWidth: w,
              videoHeight: h,
            ),
            isMinBitrateCheckEnabled: false,
            disableAudio: mute,
          );

          if (response is lc.OnSuccess) {
            final dest = response.destinationPath;
            if (dest.isNotEmpty && File(dest).existsSync()) {
              final compressedFile = File(dest);
              final compSize = compressedFile.lengthSync();

              if (compSize > 0 && (inputSize == 0 || compSize < inputSize)) {
                final outFile = File(output);
                await outFile.parent.create(recursive: true);
                await compressedFile.copy(output);
                final size = await _fileSize(output);

                String? thumb;
                if (thumbnailOut != null) {
                  try {
                    final thumbFile = await vc.VideoCompress.getFileThumbnail(input);
                    if (thumbFile.existsSync()) {
                      await File(thumbnailOut).parent.create(recursive: true);
                      await thumbFile.copy(thumbnailOut);
                      thumb = thumbnailOut;
                    }
                  } catch (_) {}
                }

                onProgress?.call(1.0, 'Finished native video compression!');
                return CompressionResult(
                  outputBytes: size,
                  thumbnailPath: thumb,
                  outputPath: output,
                );
              }
            }
          }
        } catch (_) {}

        // 2. Tertiary Engine: VideoCompress (Native MediaCodec 480p/540p)
        vc.MediaInfo? info;
        try {
          final vcQuality = targetBytes < 5 * 1024 * 1024
              ? vc.VideoQuality.LowQuality
              : vc.VideoQuality.MediumQuality;

          info = await vc.VideoCompress.compressVideo(
            input,
            quality: vcQuality,
            deleteOrigin: false,
            includeAudio: !mute,
          );
        } catch (_) {}

        File? sourceFile;
        if (info != null) {
          if (info.file != null && info.file!.existsSync()) {
            sourceFile = info.file;
          } else if (info.path != null && File(info.path!).existsSync()) {
            sourceFile = File(info.path!);
          }
        }

        if (sourceFile != null && sourceFile.existsSync()) {
          final compSize = sourceFile.lengthSync();
          if (compSize > 0 && (inputSize == 0 || compSize < inputSize)) {
            final outFile = File(output);
            await outFile.parent.create(recursive: true);
            await sourceFile.copy(output);
            final size = await _fileSize(output);

            String? thumb;
            if (thumbnailOut != null) {
              try {
                final thumbFile = await vc.VideoCompress.getFileThumbnail(input);
                if (thumbFile.existsSync()) {
                  await File(thumbnailOut).parent.create(recursive: true);
                  await thumbFile.copy(thumbnailOut);
                  thumb = thumbnailOut;
                }
              } catch (_) {}
            }

            onProgress?.call(1.0, 'Finished native video compression!');
            return CompressionResult(
              outputBytes: size,
              thumbnailPath: thumb,
              outputPath: output,
            );
          }
        }
      } catch (e) {
        onProgress?.call(null, 'Error during native compression: $e');
      }

      // If native compression failed to compress the video below input size, return 0 bytes to prevent false success claims
      onProgress?.call(null, 'Native compression failed to compress video!');
      return CompressionResult(outputBytes: 0);
    }
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
    Process process;
    try {
      process = await Process.start(exe, args);
    } on ProcessException catch (_) {
      throw FfmpegNotFoundException(
        'FFmpeg executable process is not available on this device.\n\n'
        'On Android, please use yt-dlp "Save Direct (No Compression)" or run Shitaka Memes on Desktop.',
      );
    }
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