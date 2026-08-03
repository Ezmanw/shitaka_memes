<p align="center">
  <img src="https://img.shields.io/badge/Shitaka%20Memes-v1.0.0-8BC34A?style=for-the-badge&logo=flutter&logoColor=white" alt="Shitaka Memes v1.0.0">
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20Windows%20%7C%20macOS-8BC34A?style=for-the-badge&logo=linux&logoColor=white" alt="Platforms">
  <img src="https://img.shields.io/badge/Built%20with-Flutter%203.32-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License">
</p>

<h1 align="center">Shitaka Memes</h1>

<p align="center"><strong>Compress the SHIT out of your memes.</strong></p>

<p align="center">A native <strong>Material 3</strong> app that crushes images and videos down to a handful of bytes using <strong>FFmpeg</strong>. Type a target size in KB and every file gets re-encoded until it fits — down to a handful of bytes.</p>

---

## 📥 Download (v1.0.0)

| Platform | Download | Size |
|---|---|---|
| **Linux (.deb)** | [`shitaka-memes_1.0.0_amd64.deb`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/shitaka-memes_1.0.0_amd64.deb) | 13 MB |
| **Linux (.rpm)** | [`shitaka-memes-1.0.0-1.x86_64.rpm`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/shitaka-memes-1.0.0-1.x86_64.rpm) | 8.7 MB |
| **Linux (AppImage)** | [`Shitaka_Memes-1.0.0-x86_64.AppImage`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/Shitaka_Memes-1.0.0-x86_64.AppImage) | 29 MB |
| **Linux (tar.gz)** | [`shitaka-memes-1.0.0-linux-x64.tar.gz`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/shitaka-memes-1.0.0-linux-x64.tar.gz) | 18 MB |
| **Windows (x64)** | [`shitaka-memes-windows-x64.zip`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/shitaka-memes-windows-x64.zip) | — |
| **macOS (Apple Silicon/Intel)** | [`shitaka-memes-macos.zip`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/shitaka-memes-macos.zip) | — |

> **Linux quick install:** `sudo ./install.sh` (auto-detects your distro)

---

## ✨ Features

- **Exact target size** — enter any KB value (0.5 → 1024 KB)
- **Aggressive re-encode loop** — shrinks resolution, quality, fps, drops to grayscale to hit the byte budget
- **Video muting** — audio is deleted by default
- **Live FFmpeg progress** — real frame/speed logs and per-file progress bars
- **History** — every job logged with before/after sizes and % annihilated
- **Pure Material 3** — `ColorScheme.fromSeed` theming, zero custom assets, dark + light themes
- **CLI mode** — crush files straight from the terminal, no GUI needed

---

## 🖥 Command Line Usage

The same binary doubles as a CLI. Pass any files/options and it runs headless — great for scripting:

```bash
# Crush a file to 10 KB (default)
shitaka_memes meme.png

# Target a specific size in KB
shitaka_memes -t 5 meme.jpg

# Crush several files at once, mute a video, pick an output dir
shitaka_memes -t 20 -m true clip.mp4 pic.jpg -o ~/compressed

# Show help
shitaka_memes --help
```

| Flag | Description | Default |
|---|---|---|
| `-t, --target <KB>` | Target size in KB | `10` |
| `-m, --mute [true\|false]` | Strip video audio | `true` |
| `-o, --output <dir>` | Output directory | `~/Documents/shitaka_memes` |
| `-h, --help` | Show usage | — |

Outputs are written as `SHIT-<name>.jpg` / `SHIT-<name>.mp4` (videos also get a `THUMB-<name>.jpg`). The CLI works on every platform the app builds for.

---

## 🛠 Requirements

| Platform | Needs |
|---|---|
| **Linux** | `ffmpeg` + `ffprobe` on PATH (`sudo apt install ffmpeg`) |
| **Windows / macOS** | FFmpeg bundled automatically by CI |

---

## 🏃 Run from Source

```bash
# Linux
flutter pub get
flutter run -d linux

# Windows (on Windows)
flutter pub get
flutter run -d windows

# macOS (on macOS)
flutter pub get
flutter run -d macos
```

## 📦 Build Release Bundles

```bash
# Linux
flutter build linux --release

# Windows (on Windows)
flutter build windows --release

# macOS (on macOS)
flutter build macos --release
```

---

## 🤖 CI / Auto-Builds

A GitHub Actions workflow (`.github/workflows/release.yml`) builds **Linux, Windows & macOS** automatically:

- **On every push to `main`** → artifacts uploaded as GitHub Actions artifacts (7-day retention)
- **On every tag `v*`** → binaries attached to the GitHub Release

| Runner | Trigger | Artifact |
|---|---|---|
| `ubuntu-latest` | push to main / tag | `shitaka-memes-linux-x64.tar.gz` |
| `windows-latest` | push to main / tag | `shitaka-memes-windows-x64.zip` (`.exe` + libs) |
| `macos-latest` | push to main / tag | `shitaka-memes-macos.zip` (`.app`) |

---

## 📂 Output Location

- **Linux:** `~/Documents/shitaka_memes/`
- **Windows:** App install directory
- **macOS:** `~/Documents/shitaka_memes/`

---

## 📜 License

MIT — see [LICENSE](LICENSE)