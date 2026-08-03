import 'dart:io';

import 'package:flutter/material.dart';

import '../models/compression_job.dart';
import '../services/history_store.dart';
import '../services/size_formatter.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  void _openFile(BuildContext context, String? path, String fileName) {
    if (path == null || !File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File does not exist on disk.')),
      );
      return;
    }

    final file = File(path);
    final sizeStr = formatBytes(file.lengthSync());

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
            ),
            const SizedBox(height: 12),
            SelectableText(
              'Location: $path\nSize: $sizeStr',
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

  void _confirmClear(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_forever_outlined),
        title: const Text('Wipe all history?'),
        content: const Text(
          'This removes every record of the crimes committed. '
          'The crushed files stay on disk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              HistoryStore.instance.clear();
            },
            child: const Text('Wipe'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HISTORY'),
        actions: [
          ValueListenableBuilder<List<CompressionJob>>(
            valueListenable: HistoryStore.instance.jobs,
            builder: (context, jobs, _) => jobs.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Wipe history',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () => _confirmClear(context),
                  ),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<CompressionJob>>(
        valueListenable: HistoryStore.instance.jobs,
        builder: (context, jobs, _) {
          if (jobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.history_toggle_off,
                      size: 36,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No crimes yet.',
                    style: textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Compress something and it will show up here.',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _buildJobCard(context, jobs[index]),
          );
        },
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, CompressionJob job) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onTap: () => _openFile(context, job.outputPath, job.fileName),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            job.isVideo ? Icons.movie_rounded : Icons.image_rounded,
            color: scheme.primary,
          ),
        ),
        title: Text(
          job.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${formatTimestamp(job.timestamp)} · target ${(job.targetBytes / 1024).toStringAsFixed(1)} KB',
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(
              job.success
                  ? '${formatBytes(job.inputBytes)} → ${formatBytes(job.outputBytes)}'
                  : 'Failed',
              style: textTheme.bodySmall?.copyWith(
                color: job.success ? scheme.primary : scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: job.success
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '−${job.reductionPercent}%',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              )
            : Icon(Icons.error_outline, color: scheme.error),
      ),
    );
  }
}
