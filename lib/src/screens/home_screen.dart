import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/media_item.dart';
import '../services/ffmpeg_service.dart';
import '../services/size_formatter.dart';
import '../services/ytdlp_service.dart';
import 'compress_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<MediaItem> _files = [];

  final TextEditingController _kbController = TextEditingController(text: '10');
  bool _mute = true;
  bool _checkedFfmpeg = false;
  String? _ffmpegError;

  @override
  void initState() {
    super.initState();
    _checkFfmpeg();
  }

  @override
  void dispose() {
    _kbController.dispose();
    super.dispose();
  }

  Future<void> _checkFfmpeg() async {
    try {
      await FfmpegService.ffmpegPath();
      if (mounted) setState(() => _ffmpegError = null);
    } on FfmpegNotFoundException catch (e) {
      if (mounted) setState(() => _ffmpegError = e.message);
    } catch (_) {}
    _checkedFfmpeg = true;
  }

  Future<void> _showYtdlpDialog() async {
    final urlController = TextEditingController();
    String? statusLog;
    bool downloading = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !downloading,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final scheme = Theme.of(context).colorScheme;
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.link),
                  SizedBox(width: 8),
                  Text('Import Web Video (yt-dlp)'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paste any video URL (YouTube, TikTok, Twitter/X, Instagram, etc.):',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      enabled: !downloading,
                      decoration: const InputDecoration(
                        hintText: 'https://www.youtube.com/watch?v=...',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                    ),
                    if (downloading) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLog ?? 'Starting download...',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!downloading)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                FilledButton.icon(
                  icon: Icon(downloading ? Icons.downloading : Icons.download),
                  label: Text(downloading ? 'Downloading...' : 'Fetch & Add'),
                  onPressed: downloading
                      ? null
                      : () async {
                          final url = urlController.text.trim();
                          if (url.isEmpty) return;

                          setDialogState(() {
                            downloading = true;
                            statusLog = 'Connecting to yt-dlp...';
                          });

                          try {
                            final file = await YtdlpService.downloadVideo(
                              url,
                              onProgress: (line) {
                                setDialogState(() => statusLog = line);
                              },
                            );

                            final name = file.path.split(Platform.pathSeparator).last;
                            final size = await file.length();

                            final item = MediaItem(
                              path: file.path,
                              name: name,
                              isVideo: true,
                              sizeBytes: size,
                            );

                            if (mounted) {
                              setState(() {
                                _files.add(item);
                              });
                            }

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (e) {
                            setDialogState(() {
                              downloading = false;
                              statusLog = 'Error: $e';
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
    urlController.dispose();
  }

  Future<void> _pickFiles() async {
    const typeGroupImage = XTypeGroup(
      label: 'Images',
      extensions: [
        'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp',
        'tiff', 'tif', 'heic', 'heif', 'jfif',
      ],
    );
    const typeGroupVideo = XTypeGroup(
      label: 'Videos',
      extensions: [
        'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v',
        'mpg', 'mpeg', 'wmv', 'flv', '3gp', 'ogv', 'ts',
      ],
    );

    final files = await openFiles(
      acceptedTypeGroups: [typeGroupImage, typeGroupVideo],
    );

    if (files.isEmpty) return;

    final items = <MediaItem>[];
    for (final f in files) {
      final name = f.name;
      final size = await _fileLength(f.path);
      items.add(MediaItem(
        path: f.path,
        name: name,
        isVideo: MediaItem.isVideoPath(f.path),
        sizeBytes: size,
      ));
    }

    if (!mounted) return;
    setState(() {
      _files
        ..clear()
        ..addAll(items);
    });
  }

  Future<int> _fileLength(String path) async {
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }

  void _removeFile(int index) {
    setState(() => _files.removeAt(index));
  }

  void _goCompress() {
    if (_files.isEmpty || _ffmpegError != null) return;
    final targetBytes = _targetBytesFromInput();
    if (targetBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a target size in KB first (1–1024).'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompressScreen(
          items: List<MediaItem>.from(_files),
          targetBytes: targetBytes,
          mute: _mute,
        ),
      ),
    );
  }

  int? _targetBytesFromInput() {
    final parsed = int.tryParse(_kbController.text.trim());
    if (parsed == null || parsed <= 0) return null;
    return FfmpegService.targetBytesForKb(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shitaka Memes'),
        actions: [
          IconButton(
            tooltip: 'Options & Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(context),
          ),
        ],
      ),
      body: _checkedFfmpeg && _ffmpegError != null
          ? _buildNoFfmpeg(scheme, textTheme)
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _buildHero(scheme, textTheme),
                  const SizedBox(height: 20),
                  _buildPickArea(scheme, textTheme),
                  if (_files.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSelectedFiles(scheme, textTheme),
                  ],
                  const SizedBox(height: 24),
                  _buildSettings(scheme, textTheme),
                  const SizedBox(height: 28),
                  _buildGoButton(scheme),
                ],
              ),
            ),
    );
  }

  Widget _buildNoFfmpeg(ColorScheme scheme, TextTheme textTheme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: scheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'ffmpeg is missing',
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _ffmpegError ?? '',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: _checkFfmpeg,
                  child: const Text('Check again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(ColorScheme scheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.local_fire_department,
            size: 36,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Compress the SHIT\nout of your memes.',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'FFmpeg-powered destruction for images and videos. '
          'Crushes files down to a handful of bytes.',
          style: textTheme.bodyLarge
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildPickArea(ColorScheme scheme, TextTheme textTheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  '1 · Add your material',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.folder_open),
                    label: Text(
                      _files.isEmpty
                          ? 'Pick files'
                          : 'Replace selection',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showYtdlpDialog,
                    icon: const Icon(Icons.link),
                    label: const Text('Paste URL'),
                  ),
                ),
              ],
            ),
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statChip(scheme, Icons.image_outlined,
                      '${_files.where((f) => !f.isVideo).length} images'),
                  _statChip(scheme, Icons.movie_outlined,
                      '${_files.where((f) => f.isVideo).length} videos'),
                  _statChip(
                    scheme,
                    Icons.data_usage,
                    formatBytes(_files.fold<int>(0, (a, b) => a + b.sizeBytes)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statChip(ColorScheme scheme, IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 18, color: scheme.onSecondaryContainer),
      label: Text(label),
      backgroundColor: scheme.secondaryContainer,
      labelStyle: TextStyle(
        color: scheme.onSecondaryContainer,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
    );
  }

  Widget _buildSelectedFiles(ColorScheme scheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.upload_file, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              'Selected files',
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_files.length, (i) {
          final f = _files[i];
          return Padding(
            padding: EdgeInsets.only(bottom: i == _files.length - 1 ? 0 : 8),
            child: _fileCard(scheme, textTheme, f, i),
          );
        }),
      ],
    );
  }

  Widget _fileCard(
      ColorScheme scheme, TextTheme textTheme, MediaItem f, int index) {
    return Card(
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            f.isVideo ? Icons.movie_rounded : Icons.image_rounded,
            color: scheme.primary,
          ),
        ),
        title: Text(
          f.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${f.isVideo ? 'Video' : 'Image'} · ${formatBytes(f.sizeBytes)}',
          style: textTheme.bodySmall,
        ),
        trailing: IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.close),
          onPressed: () => _removeFile(index),
        ),
      ),
    );
  }

  Widget _buildSettings(ColorScheme scheme, TextTheme textTheme) {
  final targetBytes = _targetBytesFromInput();
  return Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                '2 · Dial in the destruction',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _kbController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,4}(\.\d{0,2})?'),
                    ),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Target size',
                    helperText: 'Max bytes per file',
                    counterText: '',
                    prefixIcon: const Icon(Icons.data_usage),
                    suffixText: 'KB',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: targetBytes == null
                        ? scheme.errorContainer
                        : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        targetBytes == null
                            ? '—'
                            : formatBytes(targetBytes),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: targetBytes == null
                              ? scheme.onErrorContainer
                              : scheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        'target',
                        style: textTheme.labelSmall?.copyWith(
                          color: targetBytes == null
                              ? scheme.onErrorContainer.withValues(alpha: 0.7)
                              : scheme.onPrimaryContainer
                                  .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kb in const ['0.5', '1', '2', '5', '10', '20', '50'])
                ChoiceChip(
                  label: Text('$kb KB'),
                  selected: _kbController.text.trim() == kb,
                  onSelected: (_) {
                    _kbController.text = kb;
                    setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _mute,
            onChanged: (v) => setState(() => _mute = v),
            title: const Text(
              'Mute videos',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Audio gets deleted. As it should be.'),
            secondary: const Icon(Icons.volume_off_outlined),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildGoButton(ColorScheme scheme) {
    final enabled = _files.isNotEmpty && _ffmpegError == null;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: enabled ? _goCompress : null,
        icon: const Icon(Icons.local_fire_department),
        label: Text(
          _files.isEmpty
              ? 'ADD FILES TO BEGIN'
              : 'COMPRESS THE SHIT OUT OF ${_files.length} FILE${_files.length == 1 ? '' : 'S'}',
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.local_fire_department),
        title: const Text('How Shitaka works'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Pick as many images and videos as you want.\n'
            '2. Pick a destruction level — higher levels = fewer bytes.\n'
            '3. Hit the big button and let ffmpeg do the crimes.\n\n'
            'Shitaka repeatedly re-encodes each file, shrinking '
            'resolution and quality until it hits the target size, '
            'down to the double digits. Files land in '
            '~/Documents/shitaka_memes_out and every job is logged in History.\n\n'
            'Level 10 is irreversible. Your pixels will never recover.',
            style: TextStyle(height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
