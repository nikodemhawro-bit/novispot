#!/bin/sh
set -eu
rm -rf "$HOME/.local/opt/novispot"
rm -f "$HOME/.local/share/applications/novispot.desktop"
rm -f "$HOME/.local/share/icons/hicolor/512x512/apps/novispot.png"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
echo "Novispot uninstalled. Your music and settings were kept."
