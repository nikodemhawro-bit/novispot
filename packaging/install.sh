#!/bin/sh
set -eu
APP_DIR="$HOME/.local/opt/novispot"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
DESKTOP_DIR="$HOME/.local/share/applications"
BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
mkdir -p "$APP_DIR" "$ICON_DIR" "$DESKTOP_DIR"
cp -a "$BASE_DIR/novispot/." "$APP_DIR/"
install -m 644 "$BASE_DIR/novispot/icons/novispot.png" "$ICON_DIR/novispot.png"
printf "%s\n" "[Desktop Entry]" "Name=Novispot" "Comment=Music player for Navidrome and local music" "Exec=$APP_DIR/novispot" "TryExec=$APP_DIR/novispot" "Icon=novispot" "Terminal=false" "Type=Application" "Categories=AudioVideo;Audio;Player;" "StartupWMClass=novispot" > "$DESKTOP_DIR/novispot.desktop"
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
echo "Novispot installed successfully."
