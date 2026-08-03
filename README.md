<p align="center">
  <img src="https://img.shields.io/badge/Shitaka%20Memes-v1.0.0-8BC34A?style=for-the-badge&logo=flutter&logoColor=white" alt="Shitaka Memes v1.0.0">
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20Android-8BC34A?style=for-the-badge&logo=linux&logoColor=white" alt="Platforms">
  <img src="https://img.shields.io/badge/Built%20with-Flutter%203.32-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License">
</p>

<h1 align="center">Shitaka Memes</h1>

<p align="center"><strong>Compress the SHIT out of your memes.</strong></p>

<p align="center">A native <strong>Material 3</strong> app that crushes images and videos down to a handful of bytes using <strong>FFmpeg</strong>. Type a target size in KB and every file gets re-encoded until it fits — down to a handful of bytes.</p>

---

## 📥 Download

| Platform | Download | Size |
|---|---|---|
| **Linux (.deb)** | [`shitaka-memes_1.0.0_amd64.deb`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/shitaka-memes_1.0.0_amd64.deb) | 13 MB |
| **Linux (.rpm)** | [`shitaka-memes-1.0.0-1.x86_64.rpm`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/shitaka-memes-1.0.0-1.x86_64.rpm) | 8.7 MB |
| **Linux (AppImage)** | [`Shitaka_Memes-1.0.0-x86_64.AppImage`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/Shitaka_Memes-1.0.0-x86_64.AppImage) | 29 MB |
| **Linux (tar.gz)** | [`shitaka-memes-1.0.0-linux-x64.tar.gz`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/shitaka-memes-1.0.0-linux-x64.tar.gz) | 18 MB |
| **Android (universal)** | [`shitaka-memes-1.0.0-android-universal.apk`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/shitaka-memes-1.0.0-android-universal.apk) | 22 MB |
| **Android (arm64)** | [`shitaka-memes-1.0.0-android-arm64.apk`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/shitaka-memes-1.0.0-android-arm64.apk) | 14 MB |
| **Android (armv7)** | [`shitaka-memes-1.0.0-android-armeabi-v7a.apk`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/shitaka-memes-1.0.0-android-armeabi-v7a.apk) | 13 MB |
| **Android (x86_64)** | [`shitaka-memes-1.0.0-android-x86_64.apk`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/shitaka-memes-1.0.0-android-x86_64.apk) | 14 MB |
| **Android (AAB / Play Store)** | [`shitaka-memes-1.0.0-android.aab`](https://github.com/Ezmanw/shitaka_memes/releases/download/v1.0.0/shitaka-memes-1.0.0-android.aab) | 41 MB |

> **Linux quick install:** `sudo ./install.sh` (auto-detects your distro)

---

## ✨ Features

- **Exact target size** — enter any KB value (0.5 → 1024 KB)
- **Aggressive re-encode loop** — shrinks resolution, quality, fps, drops to grayscale to hit the byte budget
- **Video muting** — audio is deleted by default
- **Live FFmpeg progress** — real frame/speed logs and per-file progress bars
- **History** — every job logged with before/after sizes and % annihilated
- **Pure Material 3** — `ColorScheme.fromSeed` theming, zero custom assets, dark + light themes
- **Android ready** — FFmpeg bundled inside the APK (no system dependency)

---

## 🛠 Requirements

| Platform | Needs |
|---|---|
| **Linux** | `ffmpeg` + `ffprobe` on PATH (`sudo apt install ffmpeg`) |
| **Android** | Nothing — FFmpeg bundled inside the APK |

---

## 🏃 Run from Source

```bash
# Linux
flutter pub get
flutter run -d linux

# Android
flutter pub get
flutter run -d android
```

## 📦 Build Release Bundles

```bash
# Linux
flutter build linux --release

# Android (all ABIs + AAB)
flutter build apk --release --split-per-abi
flutter build appbundle --release

# Windows (on Windows)
flutter build windows --release

# macOS (on macOS)
flutter build macos --release
```

---

## 🤖 CI / Cross-Platform Builds

A GitHub Actions workflow (`.github/workflows/release.yml`) builds **all platforms** on every `v*` tag:

| Runner | Artifact |
|---|---|
| `ubuntu-latest` | Linux binary, Android APKs + AAB |
| `windows-latest` | `shitaka-memes-windows-x64.zip` (`.exe` + libs) |
| `macos-latest` | `shitaka-memes-macos.zip` (`.app`) |
| `macos-latest` (iOS) | `shitaka-memes-ios-unsigned.zip` (needs signing) |

---

## 📂 Output Location

- **Linux:** `~/Documents/shitaka_memes/`
- **Android:** App-private storage (accessible via the app)

---

## 📜 License

MIT — see [LICENSE](LICENSE)