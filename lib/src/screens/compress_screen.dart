import 'dart:io';

import 'package:flutter/material.dart';

import '../models/compression_job.dart';
import '../models/media_item.dart';
import '../services/ffmpeg_service.dart';
import '../services/history_store.dart';
import '../services/size_formatter.dart';

enum _Phase { queued, running, done, failed }

class _ItemState {
  _Phase phase = _Phase.queued;
  double? progress;
  String log = '';
  CompressionJob? job;
}

class CompressScreen extends StatefulWidget {
  final List<MediaItem> items;
  final int targetBytes;
  final bool mute;

  const CompressScreen({
    super.key,
    required this.items,
    required this.targetBytes,
    required this.mute,
  });

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  late final List<_ItemState> _states;
  bool _running = false;
  bool _allDone = false;

  @override
  void initState() {
    super.initState();
    _states = List.generate(widget.items.length, (_) => _ItemState());
    _start();
  }

  int get _doneCount =>
      _states.where((s) => s.phase == _Phase.done).length;

  int get _failedCount =>
      _states.where((s) => s.phase == _Phase.failed).length;

  Future<void> _start() async {
    setState(() => _running = true);
    final outDir = await FfmpegService.outputDirectory();

    for (int i = 0; i < widget.items.length; i++) {
      if (!mounted) return;
      final item = widget.items[i];
      final state = _states[i];

      setState(() {
        state.phase = _Phase.running;
        state.progress = null;
        state.log = 'Initializing…';
      });

      final safeBase = item.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final ext = item.isVideo ? 'mp4' : 'jpg';
      final outputPath = '${outDir.path}${Platform.pathSeparator}'
          'SHIT-${safeBase.replaceFirst(RegExp(r'\.[^.]+$'), '')}.$ext';

      try {
        CompressionResult result;
        if (item.isVideo) {
          final thumbPath = '${outDir.path}${Platform.pathSeparator}'
              'THUMB-${safeBase.replaceFirst(RegExp(r'\.[^.]+$'), '')}.jpg';
          result = await FfmpegService.compressVideo(
            input: item.path,
            output: outputPath,
            thumbnailOut: thumbPath,
            targetBytes: widget.targetBytes,
            mute: widget.mute,
            onProgress: (fraction, line) {
              if (!mounted) return;
              setState(() {
                state.progress = fraction;
                state.log = line;
              });
            },
          );
        } else {
          result = await FfmpegService.compressImage(
            input: item.path,
            output: outputPath,
            targetBytes: widget.targetBytes,
            onProgress: (fraction, line) {
              if (!mounted) return;
              setState(() {
                state.progress = fraction;
                state.log = line;
              });
            },
          );
        }

        final job = CompressionJob(
          fileName: item.name,
          isVideo: item.isVideo,
          inputBytes: item.sizeBytes,
          outputBytes: result.outputBytes,
          targetBytes: widget.targetBytes,
          success: result.outputBytes > 0,
          error: result.outputBytes > 0 ? null : 'Output was empty',
          outputPath: result.outputBytes > 0 ? outputPath : null,
          timestamp: DateTime.now(),
        );

        if (!mounted) return;
        setState(() {
          state.phase = job.success ? _Phase.done : _Phase.failed;
          state.progress = 1;
          state.job = job;
          state.log = '';
        });
        await HistoryStore.instance.add(job);
      } catch (e) {
        if (!mounted) return;
        final job = CompressionJob(
          fileName: item.name,
          isVideo: item.isVideo,
          inputBytes: item.sizeBytes,
          outputBytes: 0,
          targetBytes: widget.targetBytes,
          success: false,
          error: e.toString(),
          timestamp: DateTime.now(),
        );
        setState(() {
          state.phase = _Phase.failed;
          state.job = job;
          state.log = e.toString();
        });
        await HistoryStore.instance.add(job);
      }
    }

    if (!mounted) return;
    setState(() {
      _running = false;
      _allDone = true;
    });
  }

  Future<void> _openOutputFolder() async {
    final dir = await FfmpegService.outputDirectory();
    if (!mounted) return;
    if (Platform.isAndroid || (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)) {
      await _showOutputFolderModal(context, dir);
    } else {
      await FfmpegService.openPath(dir.path);
    }
  }

  void _showImagePreviewDialog(BuildContext context, String filePath, String fileName) {
    final file = File(filePath);
    final exists = file.existsSync();
    final sizeStr = exists ? formatBytes(file.lengthSync()) : 'Unknown size';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.image),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fileName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (exists)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Icon(Icons.broken_image, size: 48)),
                    ),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('File does not exist on disk.'),
              ),
            const SizedBox(height: 12),
            SelectableText(
              'Location: $filePath\nSize: $sizeStr',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOutputFolderModal(BuildContext context, Directory dir) async {
    final files = dir.existsSync() ? dir.listSync().whereType<File>().toList() : <File>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.folder),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Output Folder (${files.length} files)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            SelectableText(
              dir.path,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            if (files.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No compressed files found.')),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final file = files[i];
                    final name = file.path.split(Platform.pathSeparator).last;
                    final isImg = RegExp(r'\.(jpg|jpeg|png|webp|gif)$', caseSensitive: false).hasMatch(name);
                    return ListTile(
                      leading: Icon(isImg ? Icons.image : Icons.movie),
                      title: Text(name),
                      subtitle: Text(formatBytes(file.lengthSync())),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _showImagePreviewDialog(context, file.path, name);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_allDone ? 'Operation complete' : 'Operation in progress'),
        automaticallyImplyLeading: !_running,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _buildSummary(context),
            const SizedBox(height: 20),
            ...List.generate(_states.length, (i) {
              return Padding(
                padding: EdgeInsets.only(
                    bottom: i == _states.length - 1 ? 0 : 10),
                child: _buildItemCard(i),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final totalIn =
        widget.items.fold<int>(0, (a, b) => a + b.sizeBytes);
    final totalOut = _states.fold<int>(
      0,
      (a, s) => a + (s.job?.outputBytes ?? 0),
    );
    final reduction = totalIn <= 0
        ? 0
        : ((1 - totalOut / totalIn) * 100).clamp(0, 100).round();

    if (!_allDone) {
      final overall = _doneCount + _failedCount;
      final runningIndex =
          _states.indexWhere((s) => s.phase == _Phase.running);
      final runningProgress = runningIndex == -1
          ? 0.0
          : (_states[runningIndex].progress ?? 0.0);
      final fraction =
          overall == 0 ? 0.0 : (_doneCount + runningProgress) / widget.items.length;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Destroying $overall/${widget.items.length} files…',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: fraction.isNaN ? null : fraction,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Currently working: ${_states.indexWhere((s) => s.phase == _Phase.running) == -1 ? '—' : widget.items[_states.indexWhere((s) => s.phase == _Phase.running)].name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final successCount = _doneCount;
    final successIn = _states.fold<int>(0, (a, s) => a + (s.job?.inputBytes ?? 0));
    final successOut = _states.fold<int>(0, (a, s) => a + (s.job?.outputBytes ?? 0));

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.celebration, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Crime committed.',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _summaryStat(
                    scheme,
                    '$successCount/${widget.items.length}',
                    'compressed',
                  ),
                ),
                Expanded(
                  child: _summaryStat(
                    scheme,
                    formatBytes(successIn),
                    'came in',
                  ),
                ),
                Expanded(
                  child: _summaryStat(
                    scheme,
                    formatBytes(successOut),
                    'came out',
                  ),
                ),
                Expanded(
                  child: _summaryStat(
                    scheme,
                    reduction == 0 ? '0%' : '$reduction%',
                    'annihilated',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onPrimaryContainer,
                  foregroundColor: scheme.primaryContainer,
                ),
                onPressed: _openOutputFolder,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open output folder'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryStat(ColorScheme scheme, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: scheme.onPrimaryContainer,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(int index) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final item = widget.items[index];
    final state = _states[index];

    final (icon, color) = switch (state.phase) {
      _Phase.queued => (Icons.schedule, scheme.onSurfaceVariant),
      _Phase.running => (Icons.hourglass_top, scheme.primary),
      _Phase.done => (Icons.check_circle, scheme.primary),
      _Phase.failed => (Icons.error, scheme.error),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: state.job?.outputPath != null
            ? () => _showImagePreviewDialog(
                  context,
                  state.job!.outputPath!,
                  item.name,
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (state.phase == _Phase.running)
                        Text(
                          state.progress == null
                              ? 'working…'
                              : '${(state.progress! * 100).round()}%',
                          style: textTheme.labelMedium
                              ?.copyWith(color: scheme.primary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (state.phase == _Phase.running)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: LinearProgressIndicator(
                        value: state.progress,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  if (state.log.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.log,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (state.job != null &&
                      state.phase != _Phase.failed) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          formatBytes(state.job!.inputBytes),
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward, size: 14),
                        ),
                        Text(
                          formatBytes(state.job!.outputBytes),
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '−${state.job!.reductionPercent}%',
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (state.job != null &&
                      state.phase == _Phase.failed) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.job!.error ?? 'Failed',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: scheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
