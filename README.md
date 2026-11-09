# Novispot

**Novispot** is a music player for Navidrome servers and local music libraries.

## Features

- Connect to a Navidrome server
- Browse and play your music library
- Play local music files
- Dark, light and OLED themes
- Polish and English interface
- Lyrics support
- Local music library support

## Platforms

- Windows
- Linux
- Android

## Requirements

- Flutter SDK (only required for building from source)
- A Navidrome server (optional, for server-based playback)

## Building from source

```bash
flutter pub get
flutter build linux --release
```

## Installation

### Windows

1. Open [GitHub Releases](https://github.com/nikodemhawro-bit/novispot/releases).
2. Download `Novispot-Setup-1.0.0.exe` from the latest release under **Assets**.
3. Run the downloaded installer.
4. Follow the installation wizard.
5. Launch Novispot from the Start Menu or the desktop shortcut (if selected during installation).

To uninstall Novispot, open **Settings → Apps → Installed apps**, find Novispot and select **Uninstall**.

### Linux

1. Download `Novispot-Linux-x64.tar.gz` from [GitHub Releases](https://github.com/nikodemhawro-bit/novispot/releases).
2. Extract the archive.
3. Open the extracted `Novispot` directory.
4. Run:

```sh
./install.sh
```

Novispot will appear in your application menu.

To uninstall it, run `./uninstall.sh` from the extracted directory.

Your music, settings and saved credentials are preserved.

## License

Novispot is licensed under the MIT License. See [LICENSE](LICENSE).
