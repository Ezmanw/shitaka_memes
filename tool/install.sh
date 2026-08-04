#!/usr/bin/env bash
set -e

echo "😎 Installing Shitaka Memes..."

INSTALL_DIR="${HOME}/.local/share/shitaka_memes"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/512x512/apps"

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"

# Copy binary and assets
cp -r ./* "$INSTALL_DIR/"

# Symlink executable
ln -sf "$INSTALL_DIR/shitaka_memes" "$BIN_DIR/shitaka_memes"

# Desktop launcher
cat <<EOF > "$DESKTOP_DIR/shitaka-memes.desktop"
[Desktop Entry]
Name=Shitaka Memes
Comment=High-speed cross-platform meme compression utility
Exec=$BIN_DIR/shitaka_memes
Icon=shitaka_memes
Terminal=false
Type=Application
Categories=Utility;Multimedia;
EOF

echo "✅ Shitaka Memes installed successfully! Run 'shitaka_memes' or launch from app menu. 😎"
