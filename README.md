<p align="center">
  <img src="https://img.shields.io/badge/Shitaka%20Memes-v1.2.0-8BC34A?style=for-the-badge&logo=flutter&logoColor=white" alt="Shitaka Memes v1.2.0">
  <img src="https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS%20(untested)-8BC34A?style=for-the-badge&logo=flutter&logoColor=white" alt="Platforms">
  <img src="https://img.shields.io/badge/Built%20with-Flutter%203-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License">
</p>

<h1 align="center">Shitaka Memes</h1>

<p align="center"><strong>Compress the SHIT out of your memes.</strong></p>

<p align="center">A multiplatform <strong>Material 3</strong> desktop app that crushes images and videos down to a handful of bytes using <strong>FFmpeg</strong> and <strong>pure Dart engines</strong>. Type a target size in KB and every file gets re-encoded until it fits — down to a handful of bytes.</p>

---

## 📥 Download (v1.2.0)

| Platform | Download | Format |
|---|---|---|
| 🪟 **Windows** | [`shitaka-memes-windows-setup.exe`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.2.0/shitaka-memes-windows-setup.exe) | Setup Installer (with FFmpeg & yt-dlp) |
| 🪟 **Windows Portable** | [`shitaka-memes-windows-x64.zip`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.2.0/shitaka-memes-windows-x64.zip) | Portable `.zip` |
| 🐧 **Linux** | [`shitaka-memes-linux-x64.tar.gz`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.2.0/shitaka-memes-linux-x64.tar.gz) | `.tar.gz` bundle |
| 🍎 **macOS (untested)** | [`shitaka-memes-macos.zip`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.2.0/shitaka-memes-macos.zip) | `.app` bundle |

---

## ✨ Features

- **Exact target size** — enter any KB value (1 → 1024 KB).
- **Aggressive re-encode loop** — shrinks resolution, quality, fps, drops to grayscale to hit the byte budget.
- **🖥 Desktop Navigation**:
  - Responsive **collapsible NavigationRail sidebar** on wide desktop screens (>= 640px) with expandable menu toggle.
  - Bottom `NavigationBar` fallback on narrow views.
- **📹 yt-dlp Web Video Integration**:
  - Paste any web video URL to fetch and compress, or save uncompressed videos directly!
  - Automatic 1-click FFmpeg downloader for Windows.
- **🎨 Options & Dynamic Color Theming**:
  - Material 3 vibrant color palette picker (8 custom colors).
  - Dark / Light / System theme modes.
  - Custom output directory selector with reset button and native folder browser.
- **Video muting** — audio is deleted by default.
- **History log** — every job recorded with before/after sizes and % annihilated.

---

## 🛠 Platform Requirements

| Platform | Requirements |
|---|---|
| **Windows** | Bundled automatically in setup installer / portable zip. 1-click auto-download inside app if missing. |
| **Linux** | `ffmpeg` + `ffprobe` on PATH (`sudo apt install ffmpeg`). |
| **macOS (untested)** | `ffmpeg` on PATH (`brew install ffmpeg`). |

---

## 🏃 Run from Source

```bash
# Windows
flutter run -d windows

# Linux
flutter run -d linux

# macOS (untested)
flutter run -d macos
```

---

## 📂 Output Location

- **Windows:** `Documents\shitaka_memes_out\`
- **Linux:** `~/Documents/shitaka_memes_out/`
- **macOS:** `~/Documents/shitaka_memes_out/`

---

## 📜 License

MIT — see [LICENSE](LICENSE)