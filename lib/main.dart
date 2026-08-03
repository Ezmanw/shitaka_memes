import 'dart:io';

import 'package:flutter/material.dart';

import 'src/screens/about_screen.dart';
import 'src/screens/history_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/services/ffmpeg_service.dart';
import 'src/services/history_store.dart';
import 'src/services/settings_service.dart';
import 'src/services/size_formatter.dart';
import 'src/theme.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await HistoryStore.instance.load();
  await SettingsService.instance.load();

  if (args.isNotEmpty) {
    await _runCli(args);
    exit(0);
  }

  runApp(const ShitakaMemesApp());
}

Future<void> _runCli(List<String> args) async {
  if (args.contains('-h') || args.contains('--help')) {
    _printUsage();
    return;
  }

  final parser = _CliParser(args);
  final files = parser.files;
  final targetKb = parser.targetKb;
  final mute = parser.mute;
  final outputDir = parser.outputDir;

  if (files.isEmpty) {
    _printUsage();
    return;
  }

  print('Shitaka Memes CLI — crushing ${files.length} file(s)');
  print('Target: ${targetKb} KB | Mute: $mute');
  print('');

  try {
    await FfmpegService.ffmpegPath();
  } on FfmpegNotFoundException catch (e) {
    print('Error: ${e.message}');
    return;
  }

  final targetBytes = FfmpegService.targetBytesForKb(targetKb);
  final outDir = outputDir != null
      ? Directory(outputDir)
      : await FfmpegService.outputDirectory();
  if (!await outDir.exists()) {
    await outDir.create(recursive: true);
  }

  for (final file in files) {
    final f = File(file);
    if (!await f.exists()) {
      print('⚠  File not found: $file');
      continue;
    }

    final name = f.uri.pathSegments.last;
    final isVideo = _isVideo(file);
    final inputBytes = await f.length();

    print('Processing: $name (${formatBytes(inputBytes)})');

    final safeBase = name.replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ext = isVideo ? 'mp4' : 'jpg';
    final outputPath = '${outDir.path}${Platform.pathSeparator}SHIT-$safeBase.$ext';

    try {
      CompressionResult result;
      if (isVideo) {
        final thumbPath = '${outDir.path}${Platform.pathSeparator}THUMB-$safeBase.jpg';
        result = await FfmpegService.compressVideo(
          input: file,
          output: outputPath,
          thumbnailOut: thumbPath,
          targetBytes: targetBytes,
          mute: mute,
          onProgress: (fraction, line) {
            if (fraction != null) {
              print('\r  [${(fraction * 100).toStringAsFixed(0).padLeft(3)}%] $line');
            }
          },
        );
      } else {
        result = await FfmpegService.compressImage(
          input: file,
          output: outputPath,
          targetBytes: targetBytes,
          onProgress: (fraction, line) {
            print('  $line');
          },
        );
      }

      final reduction = inputBytes > 0
          ? ((1 - result.outputBytes / inputBytes) * 100).toStringAsFixed(1)
          : '0.0';
      print('  ✓ ${formatBytes(inputBytes)} → ${formatBytes(result.outputBytes)} (−$reduction%)');
      print('    Output: $outputPath');
      print('');
    } catch (e) {
      print('  ✗ Failed: $e');
      print('');
    }
  }

  print('Done. Output directory: ${outDir.path}');
}

void _printUsage() {
  print('''
Usage: shitaka_memes [options] <file1> [file2] ...

Options:
  -t, --target <KB>     Target size in KB (default: 10)
  -m, --mute            Mute video audio (default: true)
  -o, --output <dir>    Output directory (default: ~/Documents/shitaka_memes_out)
  -h, --help            Show this help

Examples:
  shitaka_memes meme.jpg
  shitaka_memes -t 5 meme.mp4
  shitaka_memes -t 100 -m false video.mp4 -o ~/out
''');
}

bool _isVideo(String path) {
  final lower = path.toLowerCase();
  final videoExts = {
    'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v', 'mpg', 'mpeg',
    'wmv', 'flv', '3gp', 'ogv', 'ts', 'mts', 'm2ts'
  };
  final dot = lower.lastIndexOf('.');
  if (dot == -1) return false;
  return videoExts.contains(lower.substring(dot + 1));
}

class ShitakaMemesApp extends StatelessWidget {
  const ShitakaMemesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        final seedColor = SettingsService.instance.seedColor;
        final themeMode = SettingsService.instance.themeMode;

        return MaterialApp(
          title: 'Shitaka Memes',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: buildLightTheme(seedColor),
          darkTheme: buildDarkTheme(seedColor),
          home: const RootScreen(),
        );
      },
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = const [
      HomeScreen(),
      HistoryScreen(),
      AboutScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.compress_outlined),
            selectedIcon: Icon(Icons.compress),
            label: 'Compress',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'About',
          ),
        ],
      ),
    );
  }
}

class _CliParser {
  final List<String> files;
  final double targetKb;
  final bool mute;
  final String? outputDir;

  _CliParser(List<String> args)
      : files = _parseFiles(args),
        targetKb = _parseTarget(args),
        mute = _parseMute(args),
        outputDir = _parseOutputDir(args);

  static List<String> _parseFiles(List<String> args) {
    final files = <String>[];
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg.startsWith('-')) {
        // Skip known flags with values
        if ((arg == '-t' || arg == '--target' || arg == '-o' || arg == '--output') && i + 1 < args.length) {
          i++; // skip the value
        }
        // -m/--mute might have a value or not
        if ((arg == '-m' || arg == '--mute') && i + 1 < args.length && !args[i + 1].startsWith('-')) {
          i++; // skip the value
        }
        continue;
      }
      files.add(arg);
    }
    return files;
  }

  static double _parseTarget(List<String> args) {
    for (var i = 0; i < args.length; i++) {
      if ((args[i] == '-t' || args[i] == '--target') && i + 1 < args.length) {
        return double.tryParse(args[i + 1]) ?? 10;
      }
    }
    return 10;
  }

  static bool _parseMute(List<String> args) {
    for (var i = 0; i < args.length; i++) {
      if ((args[i] == '-m' || args[i] == '--mute')) {
        if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
          return args[i + 1].toLowerCase() == 'true';
        }
        return true;
      }
    }
    return true;
  }

  static String? _parseOutputDir(List<String> args) {
    for (var i = 0; i < args.length; i++) {
      if ((args[i] == '-o' || args[i] == '--output') && i + 1 < args.length) {
        return args[i + 1];
      }
    }
    return null;
  }
}