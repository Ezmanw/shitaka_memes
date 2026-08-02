import 'package:flutter/material.dart';

import '../services/ffmpeg_service.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String? _ffmpegPath;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final p = await FfmpegService.ffmpegPath();
      if (mounted) setState(() => _ffmpegPath = p);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('ABOUT')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.local_fire_department,
                  size: 52,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Shitaka Memes',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'v1.0.0 · the pixel eraser',
                style: textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What is this?',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Shitaka Memes is a native desktop app that exists '
                      'to compress the absolute SHIT out of your images and '
                      'videos. It repeatedly re-encodes your files with '
                      'ffmpeg, shrinking resolution, quality and frame rate '
                      'until each file is reduced to a handful of bytes.',
                      style: textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const Divider(height: 28),
                    Text(
                      'How compression works',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Every file gets re-encoded in a loop. Each pass '
                      'lowers the resolution and cranks up the quality '
                      'destruction until the output fits inside your chosen '
                      'byte budget — right down to double digits. '
                      'Videos also get their audio removed by default.',
                      style: textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Powered by',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _poweredRow(scheme, Icons.memory,
                        'Flutter 3 · Material 3'),
                    const SizedBox(height: 12),
                    _poweredRow(scheme, Icons.play_circle_outline,
                        'ffmpeg${_ffmpegPath == null ? '' : ' · $_ffmpegPath'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'No pixels were harmed in the making of this app.\n'
                'They were absolutely destroyed by it.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _poweredRow(ColorScheme scheme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
