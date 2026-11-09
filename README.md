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

- Linux
- Android

## Requirements

- Flutter SDK
- A Navidrome server (optional, for server-based playback)

## Building from source

```bash
flutter pub get
flutter build linux --release
```

## License

Novispot is licensed under the MIT License. See [LICENSE](LICENSE).

## Linux installation

Download the latest `Novispot-Linux-x64.tar.gz` from [GitHub Releases](https://github.com/nikodemhawro-bit/novispot/releases). Extract the archive, open the `Novispot` directory and run:

```sh
./install.sh
```

Novispot will appear in your application menu. To uninstall it, run `./uninstall.sh` from the extracted directory. Your music, settings and saved credentials are preserved.
