import 'package:flutter/material.dart';

import '../services/ffmpeg_service.dart';
import '../services/settings_service.dart';
import '../services/ytdlp_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _dirController;

  String? _ffmpegStatus;
  String? _ffprobeStatus;
  String? _ytdlpStatus;

  static const List<Map<String, dynamic>> _colorPresets = [
    {'name': 'Cyber Lime', 'color': Color(0xFF8BC34A)},
    {'name': 'Electric Violet', 'color': Color(0xFF9C27B0)},
    {'name': 'Hot Pink', 'color': Color(0xFFE91E63)},
    {'name': 'Cyber Cyan', 'color': Color(0xFF00BCD4)},
    {'name': 'Emerald Green', 'color': Color(0xFF4CAF50)},
    {'name': 'Flame Amber', 'color': Color(0xFFFF9800)},
    {'name': 'Crimson Red', 'color': Color(0xFFF44336)},
    {'name': 'Deep Indigo', 'color': Color(0xFF3F51B5)},
  ];

  @override
  void initState() {
    super.initState();
    _dirController = TextEditingController(
      text: SettingsService.instance.customOutputDir ?? '',
    );
    _checkExecutables();
  }

  @override
  void dispose() {
    _dirController.dispose();
    super.dispose();
  }

  Future<void> _checkExecutables() async {
    final ffmpeg = await FfmpegService.findExecutable('ffmpeg');
    final ffprobe = await FfmpegService.findExecutable('ffprobe');
    final ytdlp = await FfmpegService.findExecutable('yt-dlp');

    if (mounted) {
      setState(() {
        _ffmpegStatus = ffmpeg ?? 'Not found';
        _ffprobeStatus = ffprobe ?? 'Not found';
        _ytdlpStatus = ytdlp ?? 'Not found';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        final currentSeed = SettingsService.instance.seedColor;
        final currentMode = SettingsService.instance.themeMode;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Options & Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // --- Section 1: Color Scheme ---
              Text('Theme Color Palette', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pick your primary accent color:',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _colorPresets.map((preset) {
                          final color = preset['color'] as Color;
                          final isSelected = currentSeed.value == color.value;

                          return InkWell(
                            onTap: () => SettingsService.instance.setSeedColor(color),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: scheme.onSurface, width: 3)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: isSelected
                                  ? Icon(Icons.check, color: Colors.white)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- Section 2: Theme Mode ---
              Text('Appearance Mode', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode),
                        label: Text('Dark'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.settings_brightness),
                        label: Text('System'),
                      ),
                    ],
                    selected: {currentMode},
                    onSelectionChanged: (set) {
                      if (set.isNotEmpty) {
                        SettingsService.instance.setThemeMode(set.first);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- Section 3: Custom Output Directory ---
              Text('Default Output Location', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Where compressed memes land (leave empty for default):',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _dirController,
                        decoration: InputDecoration(
                          hintText: 'e.g. C:\\CompressedMemes or ~/Documents/shitaka_memes_out',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.save),
                            onPressed: () {
                              SettingsService.instance.setCustomOutputDir(
                                _dirController.text,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Output location updated!'),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reset to Default'),
                            onPressed: () {
                              _dirController.clear();
                              SettingsService.instance.setCustomOutputDir(null);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- Section 4: Executable Diagnostics ---
              Text('Core Executables Status', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildExeTile('FFmpeg (Encoder)', _ffmpegStatus),
                      const Divider(),
                      _buildExeTile('FFprobe (Metadata)', _ffprobeStatus),
                      const Divider(),
                      _buildExeTile('yt-dlp (Downloader)', _ytdlpStatus),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExeTile(String name, String? path) {
    final isFound = path != null && path != 'Not found';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isFound ? Icons.check_circle_outline : Icons.warning_amber_rounded,
        color: isFound ? Colors.green : Colors.orange,
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        path ?? 'Checking...',
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
