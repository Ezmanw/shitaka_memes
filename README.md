# Shitaka Memes

Compress the SHIT out of your memes. A native Linux desktop app built with **Flutter (Material 3)** and **FFmpeg** that crushes images and videos down to a handful of bytes.

## Features

- **Pick anything** — images (JPG, PNG, GIF, WebP, HEIC, BMP, TIFF…) and videos (MP4, MOV, AVI, MKV, WebM…)
- **Exact target size** — type a target in KB (down to 0.5 KB) and every file gets re-encoded until it fits, or the encoder physically can't go smaller
- **Aggressive compression loop** — repeatedly shrinks resolution, quality, frame rate and drops to grayscale until it hits the byte budget
- **Video muting** — audio is deleted by default, because that's how it should be
- **Live progress** — real FFmpeg frame/speed logs and per-file progress bars
- **History** — every job logged with before/after sizes and % annihilated
- **Pure Material 3** — `ColorScheme.fromSeed` theming, no custom assets, dark + light themes

Output files land in `~/Documents/shitaka_memes`.

## Requirements

- Linux desktop (GTK 3 development libraries)
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- `ffmpeg` (and `ffprobe`) on your `PATH` — e.g. `sudo apt install ffmpeg`

## Run it

```bash
flutter pub get
flutter run -d linux
```

## Build a release bundle

```bash
flutter build linux --release
# binary at build/linux/x64/release/bundle/shitaka_memes
```

## License

MIT