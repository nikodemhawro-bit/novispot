import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'services/listening_stats_service.dart';
import 'features/stats/stats_screen.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:os_media_controls/os_media_controls.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';

import 'services/navidrome_service.dart';
import 'services/music_player_service.dart';

import 'features/lyrics/lyrics_screen.dart';
import 'features/player/mini_player_window.dart';

bool metadataGodReady = false;

String appTheme = "dark";

Color get bg => appTheme == "light"
    ? const Color(0xFFF5F5F5)
    : appTheme == "oled"
    ? const Color(0xFF000000)
    : const Color(0xFF101010);

Color get panel => appTheme == "light"
    ? const Color(0xFFFFFFFF)
    : appTheme == "oled"
    ? const Color(0xFF080808)
    : const Color(0xFF181818);

Color get surface => appTheme == "light"
    ? const Color(0xFFEAEAEA)
    : appTheme == "oled"
    ? const Color(0xFF151515)
    : const Color(0xFF222222);

Color get muted =>
    appTheme == "light" ? const Color(0xFF666666) : const Color(0xFF999999);

Color get primaryText => appTheme == "light" ? Colors.black : Colors.white;

Color get dividerColor =>
    appTheme == "light" ? const Color(0xFFE0E0E0) : const Color(0xFF303030);

Color get trackColor =>
    appTheme == "light" ? const Color(0xFFCCCCCC) : const Color(0xFF444444);

final secureStorage = FlutterSecureStorage();

ThemeData buildNovispotTheme(String selectedTheme) {
  final isLight = selectedTheme == "light";
  final base = isLight ? ThemeData.light() : ThemeData.dark();

  return base.copyWith(
    scaffoldBackgroundColor: bg,
    canvasColor: panel,
    cardColor: panel,
    dividerColor: dividerColor,
    colorScheme: isLight
        ? ColorScheme.light(primary: Colors.black, surface: surface)
        : ColorScheme.dark(primary: Colors.white, surface: surface),
    textTheme: base.textTheme.apply(
      bodyColor: primaryText,
      displayColor: primaryText,
    ),
    iconTheme: IconThemeData(color: primaryText),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: primaryText,
      elevation: 0,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primaryText,
      inactiveTrackColor: trackColor,
      thumbColor: primaryText,
      overlayColor: primaryText.withOpacity(0.12),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux) {
    final windowController = await WindowController.fromCurrentEngine();
    if (windowController.arguments == 'novispot-mini-player') {
      runApp(MiniPlayerWindow(controller: windowController));
      return;
    }
  }

  try {
    await MetadataGod.initialize();
    metadataGodReady = true;
  } catch (e) {
    debugPrint('Novispot: metadata_god initialization failed: $e');
  }

  runApp(NovispotApp());
}

class NovispotApp extends StatefulWidget {
  NovispotApp({super.key});

  @override
  State<NovispotApp> createState() => _NovispotAppState();
}

class _NovispotAppState extends State<NovispotApp> {
  bool loading = true;
  bool setupComplete = false;
  String theme = "dark";

  String language = 'pl';
  String server = '';
  String username = '';
  String password = '';

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    language = prefs.getString('language') ?? 'pl';
    final savedTheme = prefs.getString('novispot_theme') ?? 'dark';
    theme = ["dark", "light", "oled"].contains(savedTheme)
        ? savedTheme
        : "dark";
    appTheme = theme;
    setupComplete = prefs.getBool('setup_complete') ?? false;
    final localOnly = prefs.getBool('local_only') ?? false;

    if (setupComplete && !localOnly) {
      server = await secureStorage.read(key: 'server') ?? '';
      username = await secureStorage.read(key: 'username') ?? '';
      password = await secureStorage.read(key: 'password') ?? '';

      if (server.isEmpty || username.isEmpty || password.isEmpty) {
        setupComplete = false;
      }
    } else if (localOnly) {
      server = '';
      username = '';
      password = '';
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> startLocalMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_complete', true);
    await prefs.setBool('local_only', true);
    if (!mounted) return;
    setState(() {
      server = '';
      username = '';
      password = '';
      setupComplete = true;
    });
  }

  Future<void> changeTheme(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("novispot_theme", value);
    if (!mounted) return;

    setState(() {
      theme = value;
      appTheme = value;
    });
  }

  Future<void> changeLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', value);
    if (mounted) setState(() => language = value);
  }

  Future<void> saveConnection(
    String newServer,
    String newUsername,
    String newPassword,
  ) async {
    await secureStorage.write(key: 'server', value: newServer);
    await secureStorage.write(key: 'username', value: newUsername);
    await secureStorage.write(key: 'password', value: newPassword);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_complete', true);
    await prefs.setBool('local_only', false);

    if (mounted) {
      setState(() {
        server = newServer;
        username = newUsername;
        password = newPassword;
        setupComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Novispot',
      debugShowCheckedModeBanner: false,
      theme: buildNovispotTheme(theme).copyWith(
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.dark(primary: primaryText, surface: surface),
        sliderTheme: SliderThemeData(
          activeTrackColor: primaryText,
          inactiveTrackColor: trackColor,
          thumbColor: primaryText,
          overlayColor: Color(0x22FFFFFF),
        ),
      ),
      home: loading
          ? Scaffold(body: Center(child: CircularProgressIndicator()))
          : setupComplete
          ? MainScreen(
              language: language,
              server: server,
              username: username,
              password: password,
              onLanguageChanged: changeLanguage,
              onConnectionChanged: saveConnection,
              theme: theme,
              onThemeChanged: changeTheme,
            )
          : SetupScreen(
              language: language,
              onLanguageChanged: changeLanguage,
              onComplete: saveConnection,
              onLocalOnly: startLocalMode,
            ),
    );
  }
}

// FIRST RUN SETUP

class SetupScreen extends StatefulWidget {
  final String language;
  final ValueChanged<String> onLanguageChanged;
  final Future<void> Function(String, String, String) onComplete;
  final Future<void> Function() onLocalOnly;

  SetupScreen({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.onComplete,
    required this.onLocalOnly,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final serverController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool connecting = false;
  String? error;

  bool get pl => widget.language == 'pl';

  @override
  void dispose() {
    serverController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> connect() async {
    final address = serverController.text.trim();
    final user = usernameController.text.trim();
    final pass = passwordController.text;

    if (address.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() {
        error = pl ? 'Wypełnij wszystkie pola.' : 'Please fill in all fields.';
      });
      return;
    }

    setState(() {
      connecting = true;
      error = null;
    });

    try {
      final service = NavidromeService(
        serverUrl: address,
        username: user,
        password: pass,
      );

      await service.testConnection();
      await widget.onComplete(address, user, pass);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = pl
              ? 'Nie udało się połączyć. Sprawdź adres, login i hasło.\n$e'
              : 'Connection failed. Check your server and credentials.\n$e';
        });
      }
    } finally {
      if (mounted) setState(() => connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'novispot',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
                SizedBox(height: 45),
                Text(
                  pl ? 'WITAJ W NOVISPOT' : 'WELCOME TO NOVISPOT',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  pl ? 'Zacznijmy od konfiguracji.' : 'Let’s get you set up.',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  pl
                      ? 'Podaj dane swojego serwera Navidrome.'
                      : 'Enter your Navidrome server details.',
                  style: TextStyle(color: muted),
                ),
                SizedBox(height: 35),
                _sectionLabel(pl ? 'JĘZYK' : 'LANGUAGE'),
                SizedBox(height: 12),
                DropdownButton<String>(
                  value: widget.language,
                  dropdownColor: surface,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: 'pl', child: Text('Polski')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (value) {
                    if (value != null) widget.onLanguageChanged(value);
                  },
                ),
                SizedBox(height: 30),
                _sectionLabel(pl ? 'SERWER NAVIDROME' : 'NAVIDROME SERVER'),
                SizedBox(height: 12),
                TextField(
                  controller: serverController,
                  decoration: _inputDecoration(
                    Icons.dns_outlined,
                    hint: 'https://music.example.com',
                    label: pl ? 'Adres serwera' : 'Server address',
                  ),
                ),
                SizedBox(height: 14),
                TextField(
                  controller: usernameController,
                  decoration: _inputDecoration(
                    Icons.person_outline,
                    label: pl ? 'Login' : 'Username',
                  ),
                ),
                SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  decoration:
                      _inputDecoration(
                        Icons.lock_outline,
                        label: pl ? 'Hasło' : 'Password',
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() => hidePassword = !hidePassword);
                          },
                        ),
                      ),
                ),
                if (error != null) ...[
                  SizedBox(height: 18),
                  Text(error!, style: TextStyle(color: Colors.redAccent)),
                ],
                SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: connecting ? null : connect,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryText,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: connecting
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            pl ? 'Połącz i rozpocznij' : 'Connect and continue',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                SizedBox(height: 20),
                Center(
                  child: Text(
                    pl
                        ? 'Hasło będzie przechowywane bezpiecznie na tym urządzeniu.'
                        : 'Your password will be stored securely on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ),
                SizedBox(height: 26),
                Center(
                  child: Text(
                    pl ? 'Nie masz Navidrome?' : 'Don’t have Navidrome?',
                    style: TextStyle(color: muted),
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: connecting ? null : () => widget.onLocalOnly(),
                    icon: Icon(Icons.folder_open_outlined),
                    label: Text(
                      pl ? 'Używaj muzyki lokalnej' : 'Use local music',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// MAIN SCREEN

class MainScreen extends StatefulWidget {
  final String language;
  final String server;
  final String username;
  final String password;
  final ValueChanged<String> onLanguageChanged;
  final Future<void> Function(String, String, String) onConnectionChanged;
  final String theme;
  final Future<void> Function(String) onThemeChanged;

  MainScreen({
    super.key,
    required this.language,
    required this.server,
    required this.username,
    required this.password,
    required this.onLanguageChanged,
    required this.onConnectionChanged,
    required this.theme,
    required this.onThemeChanged,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _playlistCloudAnimation;
  int page = 0;
  int librarySource = 0; // 0 = Lokalna, 1 = Navidrome
  String search = '';

  NavidromeService? service;
  late Future<List<dynamic>> albumsFuture;
  List<Map<String, dynamic>> localTracks = [];

  bool get hasNavidrome => widget.server.trim().isNotEmpty;

  Future<List<dynamic>>? searchFuture;
  Future<List<dynamic>>? likedFuture;
  Future<List<dynamic>>? playlistsFuture;
  Future<List<dynamic>>? albumSongsFuture;
  Future<List<dynamic>>? playlistSongsFuture;

  Map<String, dynamic>? selectedAlbum;
  Map<String, dynamic>? selectedPlaylist;

  final MusicPlayerService musicPlayer = MusicPlayerService();
  WindowController? _miniPlayerController;
  DateTime? _lastMiniPlayerSync;

  List<dynamic> queue = [];
  int currentIndex = -1;
  Map<String, dynamic>? currentSong;

  bool shuffleEnabled = false;
  final Random shuffleRandom = Random();
  final List<int> shuffleHistory = [];
  int shuffleHistoryPosition = -1;
  int statsRefreshVersion = 0;

  final Set<String> likedIds = {};
  StreamSubscription<void>? completionSubscription;

  final ListeningStatsService listeningStats = ListeningStatsService();

  StreamSubscription<Duration>? positionSubscription;
  StreamSubscription<PlayerState>? stateSubscription;

  bool isActuallyPlaying = false;

  StreamSubscription<MediaControlEvent>? mediaControlSubscription;
  StreamSubscription<Duration?>? mediaDurationSubscription;

  Duration currentMediaPosition = Duration.zero;
  Duration? currentMediaDuration;
  DateTime? lastMediaStateUpdateAt;
  Duration? lastPosition;
  int pendingMilliseconds = 0;

  bool get pl => widget.language == 'pl';
  String tr(String polish, String english) => pl ? polish : english;

  @override
  void initState() {
    super.initState();
    if (Platform.isLinux) {
      miniPlayerCommandChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'requestState':
            unawaited(syncMiniPlayer(force: true));
            return true;
          case 'playPause':
            if (isActuallyPlaying) {
              await musicPlayer.pause();
            } else {
              await musicPlayer.resume();
            }
            return true;
          case 'next':
            await nextSong();
            return true;
          case 'previous':
            await previousSong();
            return true;
          case 'seek':
            final value = call.arguments;
            if (value is num) {
              await musicPlayer.seek(Duration(milliseconds: value.round()));
            }
            return true;
          default:
            return null;
        }
      });
    }
    initMediaControls();
    _playlistCloudAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    createService();
    loadLocalTracks();
    refreshLiked();
    refreshPlaylists();

    completionSubscription = musicPlayer.completedStream.listen((_) {
      if (queue.isNotEmpty) unawaited(nextSong());
    });

    positionSubscription = musicPlayer.positionStream.listen(
      handleListeningPosition,
    );

    stateSubscription = musicPlayer.playerStateStream.listen(handlePlayerState);
  }

  void handlePlayerState(PlayerState state) {
    final playing = state == PlayerState.playing;

    if (isActuallyPlaying && !playing) {
      unawaited(flushListeningTime());
    }

    if (playing && !isActuallyPlaying) {
      lastPosition = null;
    }

    isActuallyPlaying = playing;
    unawaited(updateMediaPlaybackState(force: true));
    unawaited(syncMiniPlayer(force: true));
  }

  Future<void> initMediaControls() async {
    try {
      await OsMediaControls.enableControls([
        MediaControl.play,
        MediaControl.pause,
        MediaControl.next,
        MediaControl.previous,
        MediaControl.seek,
      ]);

      mediaControlSubscription = OsMediaControls.controlEvents.listen(
        (event) {
          if (event is PlayEvent) {
            unawaited(musicPlayer.resume());
          } else if (event is PauseEvent) {
            unawaited(musicPlayer.pause());
          } else if (event is TogglePlayPauseEvent) {
            if (isActuallyPlaying) {
              unawaited(musicPlayer.pause());
            } else {
              unawaited(musicPlayer.resume());
            }
          } else if (event is NextTrackEvent) {
            unawaited(nextSong());
          } else if (event is PreviousTrackEvent) {
            unawaited(previousSong());
          } else if (event is SeekEvent) {
            currentMediaPosition = event.position;
            unawaited(musicPlayer.seek(event.position));
            unawaited(
              updateMediaPlaybackState(position: event.position, force: true),
            );
          } else if (event is StopEvent) {
            unawaited(musicPlayer.stop());
          }
        },
        onError: (error) {
          debugPrint('Novispot MPRIS event error: $error');
        },
      );

      mediaDurationSubscription = musicPlayer.durationStream.listen((duration) {
        currentMediaDuration = duration;
        unawaited(updateMediaMetadata());
        unawaited(syncMiniPlayer(force: true));
      });

      debugPrint('Novispot: system media controls initialized.');
    } catch (e) {
      debugPrint('Novispot MPRIS initialization error: $e');
    }
  }

  Future<void> updateMediaMetadata() async {
    final song = currentSong;
    if (song == null) return;

    try {
      final title = song['title']?.toString().trim();
      final artist = song['artist']?.toString().trim();
      final album = song['album']?.toString().trim();

      Uint8List? artworkBytes;
      String? artworkUrl;

      final localCover = song['coverPath']?.toString() ?? '';

      if (localCover.isNotEmpty) {
        final coverFile = File(localCover);
        if (await coverFile.exists()) {
          artworkBytes = await coverFile.readAsBytes();
        }
      }

      if (artworkBytes == null) {
        final coverId =
            song['coverArt']?.toString() ?? song['coverId']?.toString() ?? '';

        if (coverId.isNotEmpty && service != null) {
          artworkUrl = service!.getCoverArtUrl(coverId).toString();
        }
      }

      await OsMediaControls.setMetadata(
        MediaMetadata(
          title: title == null || title.isEmpty ? 'Novispot' : title,
          artist: artist,
          album: album,
          duration: currentMediaDuration,
          artwork: artworkBytes,
          artworkUrl: artworkUrl,
        ),
      );
    } catch (e) {
      debugPrint('Novispot MPRIS metadata error: $e');
    }
  }

  Future<void> updateMediaPlaybackState({
    Duration? position,
    bool force = false,
  }) async {
    if (currentSong == null) return;

    final now = DateTime.now();

    if (!force &&
        lastMediaStateUpdateAt != null &&
        now.difference(lastMediaStateUpdateAt!) < const Duration(seconds: 2)) {
      return;
    }

    lastMediaStateUpdateAt = now;

    if (position != null) {
      currentMediaPosition = position;
    }

    try {
      await OsMediaControls.setPlaybackState(
        MediaPlaybackState(
          state: isActuallyPlaying
              ? PlaybackState.playing
              : PlaybackState.paused,
          position: currentMediaPosition,
          speed: isActuallyPlaying ? 1.0 : 0.0,
        ),
      );
    } catch (e) {
      debugPrint('Novispot MPRIS playback state error: $e');
    }
  }

  void handleListeningPosition(Duration position) {
    currentMediaPosition = position;
    unawaited(updateMediaPlaybackState(position: position));
    unawaited(syncMiniPlayer());
    if (!isActuallyPlaying || currentSong == null) {
      lastPosition = position;
      return;
    }

    final previous = lastPosition;
    lastPosition = position;

    if (previous == null) return;

    final difference = position.inMilliseconds - previous.inMilliseconds;

    // Pomijamy skoki pozycji, np. przewijanie utworu.
    if (difference <= 0 || difference > 3000) return;

    pendingMilliseconds += difference;

    if (pendingMilliseconds >= 5000) {
      unawaited(flushListeningTime());
    }
  }

  Future<void> flushListeningTime({bool resetRemainder = false}) async {
    final song = currentSong;

    final seconds = pendingMilliseconds ~/ 1000;

    if (resetRemainder) {
      pendingMilliseconds = 0;
    } else {
      pendingMilliseconds -= seconds * 1000;
    }

    if (seconds <= 0 || song == null) return;

    final id = song['id']?.toString() ?? '';
    if (id.isEmpty) return;

    try {
      await listeningStats.recordListening(
        songId: id,
        title: song['title']?.toString() ?? 'Nieznany utwór',
        artist: song['artist']?.toString() ?? 'Nieznany wykonawca',
        seconds: seconds,
      );
    } catch (e) {
      debugPrint('Nie udało się zapisać statystyk: $e');
    }
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.server != widget.server ||
        oldWidget.username != widget.username ||
        oldWidget.password != widget.password) {
      createService();
      refreshLiked();
      refreshPlaylists();
    }
  }

  Future<void> openMiniPlayer() async {
    if (!Platform.isLinux) return;

    try {
      if (_miniPlayerController == null) {
        final windows = await WindowController.getAll();

        for (final window in windows) {
          if (window.arguments == 'novispot-mini-player') {
            _miniPlayerController = window;
            break;
          }
        }
      }

      _miniPlayerController ??= await WindowController.create(
        const WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: 'novispot-mini-player',
        ),
      );

      await _miniPlayerController!.show();
      await syncMiniPlayer(force: true);
    } catch (e) {
      debugPrint('Novispot Mini Player error: $e');
      _miniPlayerController = null;
    }
  }

  Future<void> syncMiniPlayer({bool force = false}) async {
    if (!Platform.isLinux || _miniPlayerController == null) return;

    final now = DateTime.now();
    if (!force &&
        _lastMiniPlayerSync != null &&
        now.difference(_lastMiniPlayerSync!) <
            const Duration(milliseconds: 450)) {
      return;
    }
    _lastMiniPlayerSync = now;

    final song = currentSong;
    String? coverUrl;
    String? coverPath;

    if (song != null) {
      if (song['source'] == 'local') {
        coverPath = song['coverPath']?.toString();
      } else {
        final coverId = song['coverArt']?.toString();
        if (coverId != null && coverId.isNotEmpty && service != null) {
          coverUrl = service!.getCoverArtUrl(coverId).toString();
        }
      }
    }

    final payload = <String, dynamic>{
      'title': song?['title']?.toString() ?? '',
      'artist': song?['artist']?.toString() ?? '',
      'album': song?['album']?.toString() ?? '',
      'coverUrl': coverUrl,
      'coverPath': coverPath,
      'playing': isActuallyPlaying,
      'positionMs': currentMediaPosition.inMilliseconds,
      'durationMs': currentMediaDuration?.inMilliseconds ?? 0,
    };

    try {
      await _miniPlayerController!.invokeMethod('updateState', payload);
    } catch (e) {
      debugPrint('Novispot Mini Player sync error: $e');
      _miniPlayerController = null;
    }
  }

  void createService() {
    if (!hasNavidrome) {
      service = null;
      albumsFuture = Future.value(<dynamic>[]);
      return;
    }
    service = NavidromeService(
      serverUrl: widget.server,
      username: widget.username,
      password: widget.password,
    );
    albumsFuture = service!.getAlbums();
  }

  @override
  void dispose() {
    completionSubscription?.cancel();
    positionSubscription?.cancel();
    stateSubscription?.cancel();
    mediaControlSubscription?.cancel();
    mediaDurationSubscription?.cancel();

    unawaited(OsMediaControls.clear());

    unawaited(flushListeningTime(resetRemainder: true));
    unawaited(musicPlayer.dispose());
    _playlistCloudAnimation.dispose();

    super.dispose();
  }

  Future<void> loadLocalTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved =
          prefs.getStringList("novispot_local_tracks_v1") ?? <String>[];
      final loaded = <Map<String, dynamic>>[];

      debugPrint("Novispot: saved local tracks: ${saved.length}");

      for (final item in saved) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is! Map) {
            debugPrint("Novispot: invalid local track entry");
            continue;
          }

          final track = Map<String, dynamic>.from(decoded);
          final path = track["path"]?.toString() ?? "";

          if (path.isEmpty || !await File(path).exists()) {
            debugPrint("Novispot: local audio file missing: $path");
            continue;
          }

          final oldCoverPath = track["coverPath"]?.toString() ?? "";
          if (track["metadataVersion"] != 2 ||
              oldCoverPath.toLowerCase().endsWith(".cover")) {
            await _readLocalTrackMetadata(track);
          }

          loaded.add(track);
        } catch (e) {
          debugPrint("Novispot: skipping invalid local track: $e");
        }
      }

      debugPrint(
        "Novispot: loaded local tracks: ${loaded.length}/${saved.length}",
      );

      localTracks = loaded;

      if (loaded.length == saved.length) {
        await _saveLocalTracks();
      } else {
        debugPrint(
          "Novispot: original library preserved; not overwriting saved list",
        );
      }

      if (!mounted) return;
      setState(() {});
      refreshLiked();
    } catch (e) {
      debugPrint("Novispot: loadLocalTracks failed: $e");
    }
  }

  Future<void> _saveLocalTracks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'novispot_local_tracks_v1',
      localTracks.map((track) => jsonEncode(track)).toList(),
    );
  }

  bool _isAudioFile(String path) {
    final extension = path.split('.').last.toLowerCase();
    return const {
      'mp3',
      'flac',
      'wav',
      'm4a',
      'aac',
      'ogg',
      'opus',
      'aiff',
      'aif',
      'wma',
    }.contains(extension);
  }

  String _localTrackTitle(String path) {
    final filename = Uri.file(path).pathSegments.isEmpty
        ? path
        : Uri.file(path).pathSegments.last;
    return filename.replaceFirst(RegExp(r'\.[^.]+$'), '');
  }

  Future<void> _readLocalTrackMetadata(Map<String, dynamic> track) async {
    if (!metadataGodReady) return;

    final path = track['path']?.toString() ?? '';
    if (path.isEmpty || !await File(path).exists()) return;

    try {
      final metadata = await MetadataGod.readMetadata(file: path);
      debugPrint(
        'Novispot COVER TEST: path=$path, '
        'picture=${metadata.picture != null}, '
        'mime=${metadata.picture?.mimeType}, '
        'bytes=${metadata.picture?.data.length ?? 0}',
      );
      final title = metadata.title?.toString().trim() ?? '';
      final artist = metadata.artist?.toString().trim() ?? '';
      final album = metadata.album?.toString().trim() ?? '';
      final albumArtist = metadata.albumArtist?.toString().trim() ?? '';

      if (title.isNotEmpty) track['title'] = title;
      if (artist.isNotEmpty) track['artist'] = artist;
      if (album.isNotEmpty) track['album'] = album;
      if (albumArtist.isNotEmpty) track['albumArtist'] = albumArtist;

      final picture = metadata.picture;
      final previousCoverPath = track['coverPath']?.toString() ?? '';

      if (picture != null && picture.data.isNotEmpty) {
        final appDir = await getApplicationSupportDirectory();
        final coversDir = Directory('${appDir.path}/local_covers');
        await coversDir.create(recursive: true);

        final mimeType = picture.mimeType.toLowerCase().split(';').first.trim();
        final extension = switch (mimeType) {
          'image/jpeg' || 'image/jpg' => 'jpg',
          'image/png' => 'png',
          'image/webp' => 'webp',
          'image/gif' => 'gif',
          'image/bmp' => 'bmp',
          'image/avif' => 'avif',
          _ => 'img',
        };

        final coverFile = File(
          '${coversDir.path}/${DateTime.now().microsecondsSinceEpoch}.$extension',
        );
        await coverFile.writeAsBytes(picture.data, flush: true);

        track['coverPath'] = coverFile.path;
        track['coverMimeType'] = mimeType;

        if (previousCoverPath.isNotEmpty &&
            previousCoverPath != coverFile.path &&
            previousCoverPath.toLowerCase().endsWith('.cover')) {
          final oldCover = File(previousCoverPath);
          if (await oldCover.exists()) await oldCover.delete();
        }
      } else if (previousCoverPath.toLowerCase().endsWith('.cover')) {
        final oldCover = File(previousCoverPath);
        if (await oldCover.exists()) await oldCover.delete();
        track.remove('coverPath');
        track.remove('coverMimeType');
      }

      track['metadataLoaded'] = true;
      track['metadataVersion'] = 2;

      if (picture != null && picture.data.isNotEmpty) {
        debugPrint('Novispot: embedded cover saved: ${track["coverPath"]}');
      } else {
        debugPrint('Novispot: no embedded cover in $path');
      }
    } catch (e) {
      track['metadataLoaded'] = true;
      debugPrint('Novispot: metadata read failed for $path: $e');
    }
  }

  Future<String?> _keepLocalAudioFile(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;

    // Android selections may point to temporary cache files, so copy them
    // into application storage. On desktop keep the original file in place.
    if (Platform.isAndroid) {
      final appDir = await getApplicationSupportDirectory();
      final musicDir = Directory('${appDir.path}/local_music');
      await musicDir.create(recursive: true);
      final originalName = Uri.file(sourcePath).pathSegments.last;
      final safeName = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final destination = File(
        '${musicDir.path}/${DateTime.now().microsecondsSinceEpoch}_$safeName',
      );
      return (await source.copy(destination.path)).path;
    }
    return source.absolute.path;
  }

  Future<void> addLocalFiles() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.audio);
      if (files.isEmpty) return;
      var added = 0;

      for (final picked in files) {
        final path = picked.path;
        if (path == null || path.isEmpty || !_isAudioFile(picked.name))
          continue;
        final storedPath = await _keepLocalAudioFile(path);
        if (storedPath == null) continue;
        if (localTracks.any((track) => track['path'] == storedPath)) continue;

        final track = <String, dynamic>{
          'id': 'local:$storedPath',
          'source': 'local',
          'path': storedPath,
          'title': _localTrackTitle(picked.name),
          'artist': '',
        };

        await _readLocalTrackMetadata(track);
        localTracks.add(track);
        added++;
      }

      await _saveLocalTracks();
      if (!mounted) return;
      setState(() {});
      refreshLiked();
      showMessage(
        added > 0
            ? tr('Dodano $added utworów.', 'Added $added tracks.')
            : tr('Nie dodano nowych plików.', 'No new files were added.'),
      );
    } catch (e) {
      showMessage(
        '${tr('Nie udało się dodać plików.', 'Could not add files.')}\n$e',
      );
    }
  }

  Future<void> addLocalFolder() async {
    try {
      final folderPath = await FilePicker.getDirectoryPath();
      if (folderPath == null || folderPath.isEmpty) return;
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        showMessage(
          tr('Nie można otworzyć tego folderu.', 'Cannot open this folder.'),
        );
        return;
      }

      var added = 0;
      await for (final entity in folder.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !_isAudioFile(entity.path)) continue;
        final storedPath = await _keepLocalAudioFile(entity.path);
        if (storedPath == null) continue;
        if (localTracks.any((track) => track['path'] == storedPath)) continue;

        final track = <String, dynamic>{
          'id': 'local:$storedPath',
          'source': 'local',
          'path': storedPath,
          'title': _localTrackTitle(entity.path),
          'artist': '',
        };

        await _readLocalTrackMetadata(track);
        localTracks.add(track);
        added++;
      }

      await _saveLocalTracks();
      if (!mounted) return;
      setState(() {});
      refreshLiked();
      showMessage(
        added > 0
            ? tr(
                'Dodano $added utworów z folderu.',
                'Added $added tracks from folder.',
              )
            : tr(
                'Nie znaleziono nowych plików audio.',
                'No new audio files were found.',
              ),
      );
    } catch (e) {
      showMessage(
        '${tr('Nie udało się odczytać folderu. Na Androidzie wybierz pojedyncze pliki, jeśli folder nie jest dostępny.', 'Could not read the folder. On Android, choose individual files if folder access is unavailable.')}\n$e',
      );
    }
  }

  void refreshLiked() {
    likedFuture = () async {
      final songs = <dynamic>[];
      if (service != null) {
        songs.addAll(await service!.getStarredSongs());
      }
      final prefs = await SharedPreferences.getInstance();
      final localLikedIds =
          prefs.getStringList('novispot_local_liked_ids') ?? [];
      songs.addAll(
        localTracks.where(
          (track) => localLikedIds.contains(track['id']?.toString()),
        ),
      );
      likedIds
        ..clear()
        ..addAll(
          songs
              .map((song) => song['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty),
        );
      return songs;
    }();
    likedFuture!
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((_) {});
  }

  void refreshPlaylists() {
    playlistsFuture = service == null
        ? Future.value(<dynamic>[])
        : service!.getPlaylists();
  }

  Future<void> toggleLike(dynamic song) async {
    final id = song['id']?.toString();
    if (id == null || id.isEmpty) return;

    final wasLiked = likedIds.contains(id);

    if (song['source'] == 'local') {
      final prefs = await SharedPreferences.getInstance();
      final localLikes = (prefs.getStringList('novispot_local_liked_ids') ?? [])
          .toSet();
      if (wasLiked) {
        localLikes.remove(id);
      } else {
        localLikes.add(id);
      }
      await prefs.setStringList(
        'novispot_local_liked_ids',
        localLikes.toList(),
      );
      refreshLiked();
      if (mounted) setState(() {});
      return;
    }

    if (service == null) return;

    setState(() {
      if (wasLiked) {
        likedIds.remove(id);
      } else {
        likedIds.add(id);
      }
    });

    try {
      if (wasLiked) {
        await service!.unstarSong(id);
      } else {
        await service!.starSong(id);
      }
      refreshLiked();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasLiked) {
          likedIds.add(id);
        } else {
          likedIds.remove(id);
        }
      });
      showMessage(
        '${tr('Nie udało się zmienić polubienia.', 'Could not update like.')}\n$e',
      );
    }
  }

  Future<void> playSong(dynamic song, List<dynamic> songs) async {
    final index = songs.indexOf(song);
    if (index < 0) return;

    setState(() {
      queue = List<dynamic>.from(songs);
      currentIndex = index;
    });

    await playAt(index);
  }

  Future<void> playAt(int index, {bool addToShuffleHistory = true}) async {
    if (index < 0 || index >= queue.length) return;

    if (addToShuffleHistory && shuffleEnabled) {
      if (shuffleHistoryPosition < shuffleHistory.length - 1) {
        shuffleHistory.removeRange(
          shuffleHistoryPosition + 1,
          shuffleHistory.length,
        );
      }
      if (shuffleHistory.isEmpty || shuffleHistory.last != index) {
        shuffleHistory.add(index);
      }
      shuffleHistoryPosition = shuffleHistory.length - 1;
    }

    final song = queue[index];
    final id = song['id']?.toString();

    if (id == null || id.isEmpty) {
      showMessage(
        tr('Ten utwór nie ma poprawnego ID.', 'This track has no valid ID.'),
      );
      return;
    }

    await flushListeningTime(resetRemainder: true);
    lastPosition = null;

    setState(() {
      currentIndex = index;
      currentSong = Map<String, dynamic>.from(song as Map);
    });
    unawaited(syncMiniPlayer(force: true));

    try {
      if (song['source'] == 'local') {
        final path = song['path']?.toString() ?? '';
        if (path.isEmpty) throw StateError('Brak ścieżki lokalnego pliku.');
        await musicPlayer.playLocalFile(path);
      } else {
        final navidrome = service;
        if (navidrome == null) {
          throw StateError('Ten utwór wymaga połączenia z Navidrome.');
        }
        await musicPlayer.play(navidrome.getStreamUrl(id).toString());
      }

      currentMediaPosition = Duration.zero;
      await updateMediaMetadata();
      await updateMediaPlaybackState(force: true);
    } catch (e) {
      showMessage(
        '${tr('Nie udało się odtworzyć utworu.', 'Could not play this track.')}\n$e',
      );
    }
  }

  Future<void> nextSong() async {
    if (queue.isEmpty || currentIndex < 0) return;

    if (shuffleEnabled && queue.length > 1) {
      int next;
      do {
        next = shuffleRandom.nextInt(queue.length);
      } while (next == currentIndex);
      await playAt(next);
      return;
    }

    if (currentIndex < queue.length - 1) {
      await playAt(currentIndex + 1);
    }
  }

  Future<void> previousSong() async {
    if (shuffleEnabled && shuffleHistoryPosition > 0) {
      shuffleHistoryPosition--;
      await playAt(
        shuffleHistory[shuffleHistoryPosition],
        addToShuffleHistory: false,
      );
      return;
    }

    if (currentIndex > 0) {
      await playAt(currentIndex - 1);
    } else if (currentSong != null) {
      await musicPlayer.seek(Duration.zero);
    }
  }

  void toggleShuffle() {
    setState(() {
      shuffleEnabled = !shuffleEnabled;
      shuffleHistory.clear();
      shuffleHistoryPosition = -1;
      if (shuffleEnabled && currentIndex >= 0) {
        shuffleHistory.add(currentIndex);
        shuffleHistoryPosition = 0;
      }
    });
    showMessage(
      shuffleEnabled
          ? tr('Losowe odtwarzanie włączone', 'Shuffle enabled')
          : tr('Losowe odtwarzanie wyłączone', 'Shuffle disabled'),
    );
  }

  Future<void> resetListeningStats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: Text(
          tr('Zresetować statystyki?', 'Reset listening statistics?'),
        ),
        content: Text(
          tr(
            'Cała historia słuchania zostanie usunięta. Playlisty i polubione utwory pozostaną bez zmian.',
            'All listening history will be deleted. Playlists and liked songs will remain unchanged.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Anuluj', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: primaryText,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Resetuj', 'Reset')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await flushListeningTime(resetRemainder: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('novispot_listening_stats_v1');

    if (!mounted) return;
    setState(() => statsRefreshVersion++);
    showMessage(
      tr('Statystyki zostały wyzerowane.', 'Statistics have been reset.'),
    );
  }

  void openAlbum(dynamic album) {
    final navidrome = service;
    if (navidrome == null) return;
    final id = album['id']?.toString();
    if (id == null || id.isEmpty) return;

    setState(() {
      selectedAlbum = Map<String, dynamic>.from(album as Map);
      selectedPlaylist = null;
      albumSongsFuture = navidrome.getAlbumSongs(id);
    });
  }

  void openPlaylist(dynamic playlist) {
    final navidrome = service;
    if (navidrome == null) return;
    final id = playlist['id']?.toString();
    if (id == null || id.isEmpty) return;

    setState(() {
      selectedPlaylist = Map<String, dynamic>.from(playlist as Map);
      selectedAlbum = null;
      playlistSongsFuture = navidrome.getPlaylistSongs(id);
    });
  }

  void closeDetails() {
    setState(() {
      selectedAlbum = null;
      selectedPlaylist = null;
    });
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> createNewPlaylist() async {
    final navidrome = service;
    if (navidrome == null) {
      showMessage(
        tr(
          'Playlisty Navidrome wymagają połączenia z serwerem.',
          'Navidrome playlists require a server connection.',
        ),
      );
      return;
    }
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panel,
        title: Text(tr('Nowa playlista', 'New playlist')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: tr('Nazwa playlisty', 'Playlist name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Anuluj', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: Text(tr('Utwórz', 'Create')),
          ),
        ],
      ),
    );

    controller.dispose();
    if (name == null || name.isEmpty) return;

    try {
      await navidrome.createPlaylist(name);
      refreshPlaylists();
      if (mounted) setState(() {});
      showMessage(tr('Utworzono playlistę.', 'Playlist created.'));
    } catch (e) {
      showMessage(
        '${tr('Nie udało się utworzyć playlisty.', 'Could not create playlist.')}\n$e',
      );
    }
  }

  Future<void> addSongToPlaylist(dynamic song) async {
    final navidrome = service;
    if (navidrome == null || song['source'] == 'local') return;
    final playlists = await navidrome.getPlaylists();
    if (!mounted) return;

    if (playlists.isEmpty) {
      showMessage(tr('Najpierw utwórz playlistę.', 'Create a playlist first.'));
      return;
    }

    final selectedId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: panel,
        title: Text(tr('Dodaj do playlisty', 'Add to playlist')),
        children: [
          for (final playlist in playlists)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, playlist['id']?.toString());
              },
              child: Text(playlist['name']?.toString() ?? 'Playlist'),
            ),
        ],
      ),
    );

    if (selectedId == null) return;

    try {
      final songId = song['id']?.toString();
      if (songId == null) return;

      await navidrome.addSongToPlaylist(selectedId, songId);
      refreshPlaylists();
      if (mounted) setState(() {});
      showMessage(tr('Dodano utwór do playlisty.', 'Song added to playlist.'));
    } catch (e) {
      showMessage(
        '${tr('Nie udało się dodać utworu.', 'Could not add song.')}\n$e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 54),
          Expanded(
            child: Row(
              children: [
                sidebar(),
                Expanded(child: content()),
              ],
            ),
          ),
          player(),
        ],
      ),
    );
  }

  Widget sidebar() {
    final labels = [
      tr('Strona główna', 'Home'),
      tr('Szukaj', 'Search'),
      tr('Biblioteka', 'Library'),
      tr('Polubione', 'Liked Songs'),
      tr('Playlisty', 'Playlists'),
      tr('Statystyki', 'Statistics'),
    ];

    final icons = [
      Icons.home_rounded,
      Icons.search_rounded,
      Icons.library_music_rounded,
      Icons.favorite_border_rounded,
      Icons.queue_music_rounded,
      Icons.bar_chart_rounded,
    ];

    return Container(
      width: 225,
      margin: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(17, 25, 17, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.only(left: 5, bottom: 38),
            child: Row(
              children: [
                Text(
                  'novispot',
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                  ),
                ),
              ],
            ),
          ),

          // Naglowek
          Padding(
            padding: const EdgeInsets.only(left: 11, bottom: 12),
            child: Text(
              tr('NAWIGACJA', 'NAVIGATION'),
              style: TextStyle(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),

          // Nawigacja
          for (int i = 0; i < labels.length; i++)
            _NavItem(
              icon: icons[i],
              label: labels[i],
              selected: page == i,
              onTap: () {
                setState(() {
                  page = i;
                  selectedAlbum = null;
                  selectedPlaylist = null;
                });
              },
            ),

          const Spacer(),

          Divider(color: dividerColor.withValues(alpha: 0.7), height: 25),

          // Uzytkownik i ustawienia
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
            decoration: BoxDecoration(
              color: surface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.username.isEmpty
                        ? Icons.library_music_rounded
                        : Icons.person_outline_rounded,
                    color: muted,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 9),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.username.isEmpty
                            ? tr('Muzyka lokalna', 'Local music')
                            : widget.username,
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr('Twoja kolekcja', 'Your collection'),
                        style: TextStyle(color: muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 3),

                IconButton(
                  tooltip: tr('Ustawienia', 'Settings'),
                  onPressed: () {
                    setState(() {
                      page = 6;
                      selectedAlbum = null;
                      selectedPlaylist = null;
                    });
                  },
                  icon: Icon(
                    Icons.settings_outlined,
                    color: page == 6 ? primaryText : muted,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  splashRadius: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget content() {
    if (selectedAlbum != null) return albumDetailPage();
    if (selectedPlaylist != null) return playlistDetailPage();

    switch (page) {
      case 1:
        return searchPage();
      case 2:
        return libraryPage();
      case 3:
        return likedPage();
      case 4:
        return playlistsPage();
      case 5:
        return StatsScreen(key: ValueKey(statsRefreshVersion), polish: pl);
      case 6:
        return settingsPage();
      default:
        return homePage();
    }
  }

  Widget heading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(subtitle, style: TextStyle(color: muted)),
      ],
    );
  }

  Widget homePage() {
    if (service == null) {
      return ListView(
        padding: EdgeInsets.fromLTRB(36, 30, 36, 42),
        children: [
          Text(
            tr('TWOJA MUZYKA', 'YOUR MUSIC'),
            style: TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Novispot.',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              letterSpacing: -1.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            tr(
              'Odtwarzaj muzykę bez serwera. Dodaj własne pliki z komputera lub telefonu.',
              'Play music without a server. Add your own files from your computer or phone.',
            ),
            style: TextStyle(color: muted),
          ),
          SizedBox(height: 25),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => setState(() => page = 2),
              icon: Icon(Icons.library_music_outlined),
              label: Text(tr('Otwórz bibliotekę', 'Open library')),
              style: FilledButton.styleFrom(
                backgroundColor: primaryText,
                foregroundColor: Colors.black,
              ),
            ),
          ),
          SizedBox(height: 24),
          if (localTracks.isEmpty)
            Text(
              tr(
                'Biblioteka jest pusta. Dodaj pliki w zakładce Biblioteka.',
                'Your library is empty. Add files in the Library tab.',
              ),
              style: TextStyle(color: muted),
            )
          else
            ...localTracks.map((song) => songTile(song, localTracks)),
        ],
      );
    }
    return FutureBuilder<List<dynamic>>(
      future: albumsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ListView(
            padding: EdgeInsets.all(38),
            children: [_errorPanel(snapshot.error.toString())],
          );
        }

        final albums = snapshot.data ?? [];

        if (albums.isEmpty) {
          return ListView(
            padding: EdgeInsets.all(38),
            children: [
              Text(
                tr("Twoja muzyka", "Your Music"),
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                tr("Nie znaleziono albumów.", "No albums found."),
                style: TextStyle(color: muted),
              ),
            ],
          );
        }

        final featured = albums.first;
        final featuredTitle = featured["name"]?.toString() ?? "Unknown album";
        final featuredArtist = featured["artist"]?.toString() ?? "";
        final featuredCover = featured["coverArt"]?.toString();

        return ListView(
          padding: EdgeInsets.fromLTRB(36, 30, 36, 42),
          children: [
            Text(
              tr("ODKRYWAJ", "LISTEN NOW"),
              style: TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
            SizedBox(height: 10),
            Text(
              tr("Twoja muzyka.", "Your music."),
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                letterSpacing: -1.2,
              ),
            ),
            SizedBox(height: 7),
            Text(
              tr(
                "Wszystko, czego chcesz słuchać, w jednym miejscu.",
                "Everything you want to hear, in one place.",
              ),
              style: TextStyle(fontSize: 14, color: muted),
            ),
            SizedBox(height: 32),

            Text(
              tr("Wybrany dla Ciebie", "Featured album"),
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: 15),

            InkWell(
              onTap: () => openAlbum(featured),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 235,
                padding: EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: dividerColor, width: 0.7),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tr(
                              "ALBUM Z TWOJEJ BIBLIOTEKI",
                              "FROM YOUR LIBRARY",
                            ),
                            style: TextStyle(
                              color: muted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(height: 15),
                          Text(
                            featuredTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.6,
                            ),
                          ),
                          if (featuredArtist.isNotEmpty) ...[
                            SizedBox(height: 7),
                            Text(
                              featuredArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: muted, fontSize: 14),
                            ),
                          ],
                          SizedBox(height: 18),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 17,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: primaryText,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: 19,
                                  color: bg,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  tr("Otwórz album", "Open album"),
                                  style: TextStyle(
                                    color: bg,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: SizedBox(
                        width: 180,
                        height: 180,
                        child: featuredCover == null
                            ? _coverPlaceholder()
                            : Image.network(
                                service!
                                    .getCoverArtUrl(featuredCover)
                                    .toString(),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) =>
                                    _coverPlaceholder(),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 38),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr("Ostatnio dodane", "Recently added"),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "${albums.length} ${tr("albumów", "albums")}",
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 19),

            SizedBox(
              height: 245,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: albums.length,
                separatorBuilder: (context, index) => SizedBox(width: 19),
                itemBuilder: (context, index) {
                  return albumCard(albums[index]);
                },
              ),
            ),

            SizedBox(height: 30),

            Container(
              padding: EdgeInsets.all(19),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.library_music_outlined, color: muted, size: 25),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr("Twoja kolekcja", "Your collection"),
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          tr(
                            "Twoja muzyka przechowywana na Navidrome.",
                            "Your music, stored on Navidrome.",
                          ),
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget albumGrid() {
    return FutureBuilder<List<dynamic>>(
      future: albumsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) return _errorPanel(snapshot.error.toString());

        final albums = snapshot.data ?? [];

        if (albums.isEmpty) {
          return Text(
            tr('Nie znaleziono albumów.', 'No albums found.'),
            style: TextStyle(color: muted),
          );
        }

        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: albums.map((album) => albumCard(album)).toList(),
        );
      },
    );
  }

  Widget albumCard(dynamic album) {
    final title = album['name']?.toString() ?? 'Unknown album';
    final artist = album['artist']?.toString() ?? '';
    final coverId = album['coverArt']?.toString();

    return _HoverCard(
      onTap: () => openAlbum(album),
      child: SizedBox(
        width: 165,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 165,
                height: 165,
                child: coverId == null
                    ? _coverPlaceholder()
                    : Image.network(
                        service!.getCoverArtUrl(coverId).toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            _coverPlaceholder(),
                      ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            if (artist.isNotEmpty)
              Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      color: surface,
      child: Center(child: Icon(Icons.album, size: 65, color: muted)),
    );
  }

  Widget _errorPanel(String message) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Nie udało się pobrać danych.', 'Could not load data.'),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(message, style: TextStyle(color: muted)),
          SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(
                () => albumsFuture =
                    service?.getAlbums() ?? Future.value(<dynamic>[]),
              );
            },
            icon: Icon(Icons.refresh),
            label: Text(tr('Spróbuj ponownie', 'Try again')),
          ),
        ],
      ),
    );
  }

  Widget albumDetailPage() {
    final album = selectedAlbum!;
    final title = album['name']?.toString() ?? 'Album';
    final artist = album['artist']?.toString() ?? '';
    final coverId = album['coverArt']?.toString();

    return FutureBuilder<List<dynamic>>(
      future: albumSongsFuture,
      builder: (context, snapshot) {
        final songs = snapshot.data ?? [];

        return ListView(
          padding: EdgeInsets.all(38),
          children: [
            TextButton.icon(
              onPressed: closeDetails,
              icon: Icon(Icons.arrow_back),
              label: Text(tr('Wróć', 'Back')),
              style: TextButton.styleFrom(alignment: Alignment.centerLeft),
            ),
            SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: coverId == null
                        ? _coverPlaceholder()
                        : Image.network(
                            service!.getCoverArtUrl(coverId).toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                _coverPlaceholder(),
                          ),
                  ),
                ),
                SizedBox(width: 25),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('ALBUM', 'ALBUM'),
                        style: TextStyle(
                          color: muted,
                          letterSpacing: 3,
                          fontSize: 11,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(artist, style: TextStyle(color: muted)),
                      SizedBox(height: 16),
                      if (songs.isNotEmpty)
                        FilledButton.icon(
                          onPressed: () => playSong(songs.first, songs),
                          icon: Icon(Icons.play_arrow),
                          label: Text(tr('Odtwórz album', 'Play album')),
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryText,
                            foregroundColor: Colors.black,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 35),
            if (snapshot.connectionState == ConnectionState.waiting)
              Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              _errorPanel(snapshot.error.toString())
            else if (songs.isEmpty)
              Text(
                tr(
                  'Ten album nie zawiera utworów.',
                  'This album has no tracks.',
                ),
              )
            else
              ...songs.map((song) => songTile(song, songs)),
          ],
        );
      },
    );
  }

  Widget searchPage() {
    return Padding(
      padding: EdgeInsets.all(38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(
            tr('Szukaj', 'Search'),
            tr(
              'Znajdź coś w swojej bibliotece.',
              'Find something in your library.',
            ),
          ),
          SizedBox(height: 25),
          TextField(
            onChanged: (value) {
              setState(() {
                search = value.trim();
                searchFuture = search.isEmpty || service == null
                    ? Future.value(<dynamic>[])
                    : service!.searchSongs(search);
              });
            },
            decoration: InputDecoration(
              hintText: tr(
                'Wpisz tytuł lub wykonawcę...',
                'Search songs or artists...',
              ),
              prefixIcon: Icon(Icons.search),
              filled: true,
              fillColor: panel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: search.isEmpty
                ? Text(
                    tr(
                      'Wpisz frazę, aby wyszukać muzykę.',
                      'Enter a search term to find music.',
                    ),
                    style: TextStyle(color: muted),
                  )
                : FutureBuilder<List<dynamic>>(
                    future: searchFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Text(
                          snapshot.error.toString(),
                          style: TextStyle(color: Colors.redAccent),
                        );
                      }

                      final remoteSongs = snapshot.data ?? [];
                      final term = search.toLowerCase();
                      final localMatches = localTracks.where((song) {
                        final title =
                            song['title']?.toString().toLowerCase() ?? '';
                        final artist =
                            song['artist']?.toString().toLowerCase() ?? '';
                        return title.contains(term) || artist.contains(term);
                      }).toList();
                      final songs = <dynamic>[...localMatches, ...remoteSongs];
                      if (songs.isEmpty) {
                        return Text(
                          tr('Brak wyników.', 'No results found.'),
                          style: TextStyle(color: muted),
                        );
                      }

                      return ListView(
                        children: songs
                            .map((song) => songTile(song, songs))
                            .toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget libraryPage() {
    final isLocal = librarySource == 0;

    Widget sourceTab(int index, String label, IconData icon) {
      final selected = librarySource == index;

      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              librarySource = index;
            });
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: selected ? primaryText : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: selected ? Colors.black : muted),
                SizedBox(width: 9),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.black : muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(38),
      children: [
        heading(
          tr("Twoja biblioteka", "Your Library"),
          tr(
            "Wybierz bibliotekę, z której chcesz słuchać.",
            "Choose the library you want to listen to.",
          ),
        ),
        SizedBox(height: 24),

        Container(
          padding: EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: dividerColor),
          ),
          child: Row(
            children: [
              sourceTab(0, tr("Lokalne", "Local"), Icons.folder_open_outlined),
              sourceTab(1, "Navidrome", Icons.dns_outlined),
            ],
          ),
        ),

        SizedBox(height: 28),

        if (isLocal) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: addLocalFiles,
                icon: Icon(Icons.audio_file_outlined),
                label: Text(tr("Dodaj pliki", "Add files")),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryText,
                  foregroundColor: Colors.black,
                ),
              ),
              OutlinedButton.icon(
                onPressed: addLocalFolder,
                icon: Icon(Icons.folder_open_outlined),
                label: Text(tr("Dodaj folder", "Add folder")),
              ),
            ],
          ),
          SizedBox(height: 28),
          Text(
            tr(
              "MUZYKA LOKALNA  •  ${localTracks.length} UTWORÓW",
              "LOCAL MUSIC  •  ${localTracks.length} TRACKS",
            ),
            style: TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          SizedBox(height: 10),
          if (localTracks.isEmpty)
            Text(
              tr(
                "Nie dodano jeszcze plików. Wybierz pliki audio albo cały folder.",
                "No files added yet. Choose audio files or an entire folder.",
              ),
              style: TextStyle(color: muted),
            )
          else
            ...localTracks.map((song) => songTile(song, localTracks)),
        ] else ...[
          if (service != null) ...[
            heading(
              tr("Twoje albumy", "Your albums"),
              tr(
                "Kolekcja z podłączonego serwera Navidrome.",
                "Your connected Navidrome server collection.",
              ),
            ),
            SizedBox(height: 20),
            albumGrid(),
          ] else
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                tr(
                  "Nie masz podłączonego serwera Navidrome. Dodaj go w Ustawieniach.",
                  "No Navidrome server connected. Add one in Settings.",
                ),
                style: TextStyle(color: muted),
              ),
            ),
        ],
      ],
    );
  }

  Widget songTile(dynamic song, List<dynamic> songs) {
    final title = song['title']?.toString() ?? 'Unknown track';
    final artist = song['artist']?.toString() ?? '';
    final coverId = song['coverArt']?.toString();
    final id = song['id']?.toString() ?? '';
    final isLiked = likedIds.contains(id);

    return _HoverCard(
      onTap: () => playSong(song, songs),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 46,
                height: 46,
                child: song['source'] == 'local'
                    ? (song['coverPath'] != null
                          ? Image.file(
                              File(song['coverPath'].toString()),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  _coverPlaceholder(),
                            )
                          : _coverPlaceholder())
                    : (coverId == null || service == null
                          ? _coverPlaceholder()
                          : Image.network(
                              service!.getCoverArtUrl(coverId).toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  _coverPlaceholder(),
                            )),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (artist.isNotEmpty)
                    Text(artist, style: TextStyle(color: muted, fontSize: 12)),
                ],
              ),
            ),
            Icon(
              currentSong?['id'] == song['id']
                  ? Icons.graphic_eq
                  : Icons.play_arrow,
              color: primaryText,
            ),
            IconButton(
              tooltip: isLiked
                  ? tr('Usuń polubienie', 'Unlike')
                  : tr('Polub', 'Like'),
              onPressed: () => toggleLike(song),
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? primaryText : muted,
                size: 20,
              ),
            ),
            if (service != null && song['source'] != 'local')
              PopupMenuButton<String>(
                tooltip: tr('Więcej', 'More'),
                onSelected: (value) {
                  if (value == 'playlist') addSongToPlaylist(song);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'playlist',
                    child: Text(tr('Dodaj do playlisty', 'Add to playlist')),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget likedPage() {
    return FutureBuilder<List<dynamic>>(
      future: likedFuture,
      builder: (context, snapshot) {
        final songs = snapshot.data ?? [];

        return ListView(
          padding: EdgeInsets.all(38),
          children: [
            heading(
              tr('Polubione utwory', 'Liked Songs'),
              tr('Twoje ulubione utwory.', 'Your favourite tracks.'),
            ),
            SizedBox(height: 25),
            if (snapshot.connectionState == ConnectionState.waiting)
              Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              _errorPanel(snapshot.error.toString())
            else if (songs.isEmpty)
              Text(
                tr(
                  'Nie masz jeszcze polubionych utworów.',
                  'You have no liked songs yet.',
                ),
                style: TextStyle(color: muted),
              )
            else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => playSong(songs.first, songs),
                  icon: Icon(Icons.play_arrow),
                  label: Text(tr('Odtwórz wszystko', 'Play all')),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryText,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              SizedBox(height: 18),
              ...songs.map((song) => songTile(song, songs)),
            ],
          ],
        );
      },
    );
  }

  Future<File?> _getLocalPlaylistCover(dynamic playlist) async {
    final id = playlist['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final safeId = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/playlist_covers/$safeId.cover');
    return await file.exists() ? file : null;
  }

  Widget _playlistCoverWidget(dynamic playlist) {
    return FutureBuilder<File?>(
      future: _getLocalPlaylistCover(playlist),
      builder: (context, snapshot) {
        final file = snapshot.data;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 52,
            height: 52,
            child: file == null
                ? Container(
                    color: surface,
                    child: Icon(Icons.queue_music, size: 28),
                  )
                : Image.file(file, fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  Widget _playlistCloudCoverWidget(dynamic playlist) {
    return FutureBuilder<File?>(
      future: _getLocalPlaylistCover(playlist),
      builder: (context, snapshot) {
        final file = snapshot.data;
        return AnimatedBuilder(
          animation: _playlistCloudAnimation,
          builder: (context, child) {
            final progress = Curves.easeInOut.transform(
              _playlistCloudAnimation.value,
            );
            return Container(
              width: 164,
              height: 164,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.35 + progress * 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.06 + progress * 0.12),
                    blurRadius: 12 + progress * 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox.expand(
                    child: file == null
                        ? Container(
                            color: surface,
                            child: Icon(
                              Icons.queue_music,
                              size: 48,
                              color: primaryText,
                            ),
                          )
                        : Image.file(file, fit: BoxFit.cover),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> changePlaylistCover() async {
    final playlist = selectedPlaylist;
    if (playlist == null) return;
    final id = playlist['id']?.toString();
    if (id == null || id.isEmpty) return;

    final result = await FilePicker.pickFile(type: FileType.image);
    if (result == null) return;

    final bytes = await result.readAsBytes();
    if (bytes.isEmpty) return;
    if (bytes.length > 10 * 1024 * 1024) {
      showMessage('Obrazek może mieć maksymalnie 10 MB.');
      return;
    }

    final safeId = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final dir = await getApplicationSupportDirectory();
    final covers = Directory('${dir.path}/playlist_covers');
    await covers.create(recursive: true);
    await File('${covers.path}/$safeId.cover').writeAsBytes(bytes);

    if (!mounted) return;
    setState(() {});
    showMessage('Zapisano okładkę w Novispot.');
  }

  Widget playlistsPage() {
    if (service == null) {
      return ListView(
        padding: EdgeInsets.all(38),
        children: [
          heading(
            tr('Playlisty', 'Playlists'),
            tr('Playlisty serwera Navidrome.', 'Navidrome server playlists.'),
          ),
          SizedBox(height: 18),
          Text(
            tr(
              'Aby korzystać z playlist Navidrome, dodaj serwer w Ustawieniach. Lokalna biblioteka i odtwarzanie działają bez serwera.',
              'To use Navidrome playlists, add a server in Settings. Your local library and playback work without a server.',
            ),
            style: TextStyle(color: muted),
          ),
        ],
      );
    }
    return FutureBuilder<List<dynamic>>(
      future: playlistsFuture,
      builder: (context, snapshot) {
        final playlists = snapshot.data ?? [];

        return ListView(
          padding: EdgeInsets.all(38),
          children: [
            Row(
              children: [
                Expanded(
                  child: heading(
                    tr('Playlisty', 'Playlists'),
                    tr('Twoje muzyczne zestawy.', 'Your music collections.'),
                  ),
                ),
                FilledButton.icon(
                  onPressed: createNewPlaylist,
                  icon: Icon(Icons.add),
                  label: Text(tr('Nowa playlista', 'New playlist')),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryText,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
            SizedBox(height: 25),
            if (snapshot.connectionState == ConnectionState.waiting)
              Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              _errorPanel(snapshot.error.toString())
            else if (playlists.isEmpty)
              Text(
                tr('Nie masz jeszcze playlist.', 'You have no playlists yet.'),
                style: TextStyle(color: muted),
              )
            else
              ...playlists.map((playlist) {
                final name = playlist['name']?.toString() ?? 'Playlist';
                final count = playlist['songCount']?.toString() ?? '';

                return _HoverCard(
                  onTap: () => openPlaylist(playlist),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    leading: _playlistCoverWidget(playlist),
                    title: Text(name),
                    subtitle: Text(
                      count.isEmpty
                          ? tr('Playlista', 'Playlist')
                          : '$count ${tr('utworów', 'songs')}',
                      style: TextStyle(color: muted),
                    ),
                    trailing: Icon(Icons.chevron_right),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget playlistDetailPage() {
    final playlist = selectedPlaylist!;
    final name = playlist['name']?.toString() ?? 'Playlist';

    return FutureBuilder<List<dynamic>>(
      future: playlistSongsFuture,
      builder: (context, snapshot) {
        final songs = snapshot.data ?? [];

        return ListView(
          padding: EdgeInsets.all(38),
          children: [
            TextButton.icon(
              onPressed: closeDetails,
              icon: Icon(Icons.arrow_back),
              label: Text(tr('Wróć do playlist', 'Back to playlists')),
              style: TextButton.styleFrom(alignment: Alignment.centerLeft),
            ),
            SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _playlistCloudCoverWidget(playlist),
                SizedBox(width: 22),
                Expanded(
                  child: heading(name, tr('Twoja playlista', 'Your playlist')),
                ),
              ],
            ),
            SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: changePlaylistCover,
                icon: Icon(Icons.image_outlined),
                label: Text(tr('Zmień okładkę', 'Change cover')),
              ),
            ),
            SizedBox(height: 25),
            if (snapshot.connectionState == ConnectionState.waiting)
              Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              _errorPanel(snapshot.error.toString())
            else if (songs.isEmpty)
              Text(
                tr('Ta playlista jest pusta.', 'This playlist is empty.'),
                style: TextStyle(color: muted),
              )
            else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => playSong(songs.first, songs),
                  icon: Icon(Icons.play_arrow),
                  label: Text(tr('Odtwórz wszystko', 'Play all')),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryText,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              SizedBox(height: 18),
              ...songs.map((song) => songTile(song, songs)),
            ],
          ],
        );
      },
    );
  }

  Widget settingsPage() {
    return ListView(
      padding: EdgeInsets.all(38),
      children: [
        heading(
          tr('Ustawienia', 'Settings'),
          tr('Dostosuj Novispot.', 'Customize Novispot.'),
        ),
        SizedBox(height: 30),
        Text(
          tr('Język aplikacji', 'Application language'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        DropdownButton<String>(
          value: widget.language,
          dropdownColor: surface,
          isExpanded: true,
          items: [
            DropdownMenuItem(value: 'pl', child: Text('Polski')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: (value) {
            if (value != null) widget.onLanguageChanged(value);
          },
        ),
        SizedBox(height: 26),
        Text(
          tr('Motyw aplikacji', 'App theme'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        DropdownButton<String>(
          value: widget.theme,
          isExpanded: true,
          dropdownColor: surface,
          items: [
            DropdownMenuItem(value: "dark", child: Text(tr("Ciemny", "Dark"))),
            DropdownMenuItem(value: "light", child: Text(tr("Jasny", "Light"))),
            DropdownMenuItem(value: "oled", child: Text("OLED")),
          ],
          onChanged: (value) {
            if (value != null) {
              widget.onThemeChanged(value);
            }
          },
        ),
        SizedBox(height: 20),
        Divider(color: dividerColor),
        SizedBox(height: 20),
        Text(
          tr('Statystyki słuchania', 'Listening statistics'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: resetListeningStats,
          icon: Icon(Icons.delete_outline),
          label: Text(tr('Zresetuj statystyki', 'Reset statistics')),
        ),
        SizedBox(height: 25),
        Divider(color: dividerColor),
        SizedBox(height: 25),
        Text(
          tr('Źródło muzyki', 'Music source'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        if (hasNavidrome) ...[
          SelectableText(widget.server, style: TextStyle(color: muted)),
          SizedBox(height: 5),
          Text(widget.username, style: TextStyle(color: muted)),
        ] else
          Text(
            tr(
              'Tryb lokalny — muzyka jest odtwarzana bezpośrednio z plików na tym urządzeniu.',
              'Local mode — music plays directly from files on this device.',
            ),
            style: TextStyle(color: muted),
          ),
        SizedBox(height: 18),
        FilledButton.icon(
          onPressed: editConnection,
          icon: Icon(Icons.edit),
          label: Text(tr('Zmień serwer', 'Change server')),
          style: FilledButton.styleFrom(
            backgroundColor: primaryText,
            foregroundColor: Colors.black,
          ),
        ),
        SizedBox(height: 30),
        Divider(color: dividerColor),
        SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.music_note),
            SizedBox(width: 10),
            Text('Novispot', style: TextStyle(fontWeight: FontWeight.bold)),
            Spacer(),
            Text('NOVISPOT 1.0.0 (BETA)', style: TextStyle(color: muted)),
          ],
        ),
      ],
    );
  }

  Future<void> editConnection() async {
    await showDialog<bool>(
      context: context,
      builder: (context) => _ConnectionDialog(
        language: widget.language,
        server: widget.server,
        username: widget.username,
        password: widget.password,
        onSave: widget.onConnectionChanged,
      ),
    );
  }

  Widget player() {
    final title =
        currentSong?['title']?.toString() ??
        tr('Nic nie odtwarzam', 'Nothing playing');
    final artist = currentSong?['artist']?.toString() ?? '';
    final coverId = currentSong?['coverArt']?.toString();
    final currentId = currentSong?['id']?.toString() ?? '';
    final isLiked = likedIds.contains(currentId);
    final songForCover = currentSong;

    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: panel,
        border: Border(top: BorderSide(color: dividerColor)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _PlayerBarWaveBackground(
            positionStream: musicPlayer.positionStream,
            durationStream: musicPlayer.durationStream,
            coverUrl: coverId == null || service == null
                ? null
                : service!.getCoverArtUrl(coverId).toString(),
            coverPath: songForCover != null && songForCover['source'] == 'local'
                ? songForCover['coverPath']?.toString()
                : null,
            baseColor: panel,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child:
                              songForCover != null &&
                                  songForCover['source'] == 'local'
                              ? (songForCover['coverPath'] != null
                                    ? Image.file(
                                        File(
                                          songForCover['coverPath'].toString(),
                                        ),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stack) =>
                                            _coverPlaceholder(),
                                      )
                                    : _coverPlaceholder())
                              : (coverId == null || service == null
                                    ? _coverPlaceholder()
                                    : Image.network(
                                        service!
                                            .getCoverArtUrl(coverId)
                                            .toString(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stack) =>
                                            _coverPlaceholder(),
                                      )),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.38),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  artist.isEmpty ? 'Novispot' : artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: muted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Spacer(),
                      if (Platform.isLinux)
                        IconButton(
                          tooltip: tr('Otwórz Mini Player', 'Open Mini Player'),
                          onPressed: openMiniPlayer,
                          icon: const Icon(
                            Icons.picture_in_picture_alt_rounded,
                            size: 22,
                          ),
                        )
                      else
                        StreamBuilder<PlayerState>(
                          stream: musicPlayer.playerStateStream,
                          initialData: PlayerState.stopped,
                          builder: (context, snapshot) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _MiniAudioVisualizer(
                                isPlaying: snapshot.data == PlayerState.playing,
                              ),
                            );
                          },
                        ),
                      IconButton(
                        tooltip: tr('Tekst utworu', 'Lyrics'),
                        onPressed: currentSong == null
                            ? null
                            : () {
                                final song = currentSong!;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LyricsScreen(
                                      title: song['title']?.toString() ?? '',
                                      artist: song['artist']?.toString() ?? '',
                                      coverUrl:
                                          song['source'] == 'local' ||
                                              song['coverArt'] == null ||
                                              service == null
                                          ? null
                                          : service!
                                                .getCoverArtUrl(
                                                  song['coverArt'].toString(),
                                                )
                                                .toString(),
                                      coverPath: song['source'] == 'local'
                                          ? song['coverPath']?.toString()
                                          : null,
                                      positionStream:
                                          musicPlayer.positionStream,
                                      polish: pl,
                                    ),
                                  ),
                                );
                              },
                        icon: Icon(Icons.lyrics_outlined, size: 22),
                      ),
                      IconButton(
                        tooltip: shuffleEnabled
                            ? tr('Wyłącz losowanie', 'Disable shuffle')
                            : tr('Włącz losowanie', 'Enable shuffle'),
                        onPressed: currentSong == null ? null : toggleShuffle,
                        icon: Icon(
                          Icons.shuffle_rounded,
                          size: 21,
                          color: shuffleEnabled ? primaryText : muted,
                        ),
                      ),
                      IconButton(
                        tooltip: tr('Poprzedni utwór', 'Previous track'),
                        onPressed: currentSong == null ? null : previousSong,
                        icon: Icon(Icons.skip_previous_rounded, size: 27),
                      ),
                      StreamBuilder<PlayerState>(
                        stream: musicPlayer.playerStateStream,
                        initialData: PlayerState.stopped,
                        builder: (context, snapshot) {
                          final playing = snapshot.data == PlayerState.playing;

                          return IconButton(
                            tooltip: playing
                                ? tr('Pauza', 'Pause')
                                : tr('Odtwórz', 'Play'),
                            onPressed: currentSong == null
                                ? null
                                : () async {
                                    if (playing) {
                                      await musicPlayer.pause();
                                    } else {
                                      await musicPlayer.resume();
                                    }
                                  },
                            icon: Icon(
                              playing
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              size: 39,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: tr('Następny utwór', 'Next track'),
                        onPressed: currentSong == null ? null : nextSong,
                        icon: Icon(Icons.skip_next_rounded, size: 27),
                      ),
                      IconButton(
                        tooltip: isLiked
                            ? tr('Usuń polubienie', 'Unlike')
                            : tr('Polub', 'Like'),
                        onPressed: currentSong == null
                            ? null
                            : () => toggleLike(currentSong),
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? primaryText : muted,
                        ),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<Duration>(
                  stream: musicPlayer.positionStream,
                  initialData: Duration.zero,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;

                    return StreamBuilder<Duration?>(
                      stream: musicPlayer.durationStream,
                      builder: (context, durationSnapshot) {
                        final duration = durationSnapshot.data ?? Duration.zero;
                        final maxMs = duration.inMilliseconds.toDouble();
                        final currentMs = position.inMilliseconds
                            .clamp(0, duration.inMilliseconds)
                            .toDouble();

                        return Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.38),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                _formatDuration(position),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            Expanded(
                              child: WavyProgressBar(
                                value: currentMs,
                                max: maxMs,
                                coverUrl: coverId == null || service == null
                                    ? null
                                    : service!
                                          .getCoverArtUrl(coverId)
                                          .toString(),
                                trackColor: trackColor,
                                onSeek:
                                    duration.inMilliseconds <= 0 ||
                                        currentSong == null
                                    ? null
                                    : (value) {
                                        musicPlayer.seek(
                                          Duration(milliseconds: value.round()),
                                        );
                                      },
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.38),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                _formatDuration(duration),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerBarWaveBackground extends StatefulWidget {
  final Stream<Duration> positionStream;
  final Stream<Duration?> durationStream;
  final String? coverUrl;
  final String? coverPath;
  final Color baseColor;

  const _PlayerBarWaveBackground({
    required this.positionStream,
    required this.durationStream,
    required this.coverUrl,
    required this.coverPath,
    required this.baseColor,
  });

  @override
  State<_PlayerBarWaveBackground> createState() =>
      _PlayerBarWaveBackgroundState();
}

class _PlayerBarWaveBackgroundState extends State<_PlayerBarWaveBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;

  @override
  void initState() {
    super.initState();
    animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: StreamBuilder<Duration>(
        stream: widget.positionStream,
        initialData: Duration.zero,
        builder: (context, ps) {
          return StreamBuilder<Duration?>(
            stream: widget.durationStream,
            builder: (context, ds) {
              final duration = ds.data ?? Duration.zero;
              final position = ps.data ?? Duration.zero;
              final progress = duration.inMilliseconds > 0
                  ? (position.inMilliseconds / duration.inMilliseconds).clamp(
                      0.0,
                      1.0,
                    )
                  : 0.0;

              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: widget.baseColor),
                      if (progress > 0 &&
                          (widget.coverPath != null || widget.coverUrl != null))
                        ClipPath(
                          clipper: _PlayerBarClipper(
                            progress,
                            animation.value * math.pi * 2,
                          ),
                          child: ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: 38,
                              sigmaY: 38,
                            ),
                            child: widget.coverPath != null
                                ? Image.file(
                                    File(widget.coverPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) =>
                                        ColoredBox(color: widget.baseColor),
                                  )
                                : Image.network(
                                    widget.coverUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) =>
                                        ColoredBox(color: widget.baseColor),
                                  ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _PlayerBarClipper extends CustomClipper<Path> {
  final double progress;
  final double phase;

  _PlayerBarClipper(this.progress, this.phase);

  @override
  Path getClip(Size size) {
    final path = Path();
    if (progress <= 0) return path;
    if (progress >= 1) return path..addRect(Offset.zero & size);

    final x = size.width * progress;
    path.moveTo(0, 0);
    path.lineTo(x, 0);

    for (int i = 1; i <= 80; i++) {
      final y = size.height * i / 80;
      final wave = math.sin(y / size.height * math.pi * 2.5 + phase) * 9;
      path.lineTo((x + wave).clamp(0.0, size.width), y);
    }

    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _PlayerBarClipper old) =>
      old.progress != progress || old.phase != phase;
}

class WavyProgressBar extends StatefulWidget {
  final double value;
  final double max;
  final String? coverUrl;
  final Color trackColor;
  final ValueChanged<double>? onSeek;

  const WavyProgressBar({
    super.key,
    required this.value,
    required this.max,
    required this.coverUrl,
    required this.trackColor,
    required this.onSeek,
  });

  @override
  State<WavyProgressBar> createState() => _WavyProgressBarState();
}

class _WavyProgressBarState extends State<WavyProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _seek(double dx, double width) {
    if (widget.onSeek == null || width <= 0 || widget.max <= 0) return;

    final fraction = (dx / width).clamp(0.0, 1.0);
    widget.onSeek!(widget.max * fraction);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.max > 0
        ? (widget.value / widget.max).clamp(0.0, 1.0)
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onSeek == null
              ? null
              : (details) =>
                    _seek(details.localPosition.dx, constraints.maxWidth),
          onHorizontalDragUpdate: widget.onSeek == null
              ? null
              : (details) =>
                    _seek(details.localPosition.dx, constraints.maxWidth),
          child: SizedBox(
            height: 22,
            width: double.infinity,
            child: Center(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      height: 7,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: Colors.white),
                          ClipPath(
                            clipper: _WaveProgressClipper(
                              progress: progress,
                              phase: _animation.value * math.pi * 2,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                const ColoredBox(color: Colors.white),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withOpacity(0.18),
                                        Colors.transparent,
                                        Colors.white.withOpacity(0.12),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fallbackGradient() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF777777), Color(0xFFBBBBBB), Color(0xFF555555)],
        ),
      ),
    );
  }
}

class _WaveProgressClipper extends CustomClipper<Path> {
  final double progress;
  final double phase;

  _WaveProgressClipper({required this.progress, required this.phase});

  @override
  Path getClip(Size size) {
    final path = Path();

    if (progress <= 0 || size.width <= 0 || size.height <= 0) {
      return path;
    }

    if (progress >= 1) {
      return path..addRect(Offset.zero & size);
    }

    final edgeX = size.width * progress;
    final amplitude = math.min(2.4, size.height * 0.24);

    path.moveTo(0, 0);
    path.lineTo(edgeX, 0);

    for (var i = 1; i <= 24; i++) {
      final y = size.height * i / 24;
      final waveX =
          (edgeX +
                  math.sin((y / size.height * math.pi * 2) + phase) * amplitude)
              .clamp(0.0, size.width)
              .toDouble();

      path.lineTo(waveX, y);
    }

    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant _WaveProgressClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.phase != phase;
  }
}

// CHANGE SERVER DIALOG

class _ConnectionDialog extends StatefulWidget {
  final String language;
  final String server;
  final String username;
  final String password;
  final Future<void> Function(String, String, String) onSave;

  _ConnectionDialog({
    required this.language,
    required this.server,
    required this.username,
    required this.password,
    required this.onSave,
  });

  @override
  State<_ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<_ConnectionDialog> {
  late final TextEditingController serverController;
  late final TextEditingController usernameController;
  late final TextEditingController passwordController;

  bool connecting = false;
  bool hidePassword = true;
  String? error;

  bool get pl => widget.language == 'pl';

  @override
  void initState() {
    super.initState();
    serverController = TextEditingController(text: widget.server);
    usernameController = TextEditingController(text: widget.username);
    passwordController = TextEditingController(text: widget.password);
  }

  @override
  void dispose() {
    serverController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final server = serverController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text;

    if (server.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() {
        error = pl ? 'Wypełnij wszystkie pola.' : 'Please fill in all fields.';
      });
      return;
    }

    setState(() {
      connecting = true;
      error = null;
    });

    try {
      final service = NavidromeService(
        serverUrl: server,
        username: username,
        password: password,
      );

      await service.testConnection();
      await widget.onSave(server, username, password);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = pl
              ? 'Nie udało się połączyć. Sprawdź dane.\n$e'
              : 'Connection failed. Check your details.\n$e';
        });
      }
    } finally {
      if (mounted) setState(() => connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: panel,
      title: Text(pl ? 'Zmień serwer' : 'Change server'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: serverController,
                decoration: InputDecoration(
                  labelText: pl ? 'Adres serwera' : 'Server URL',
                  hintText: 'https://music.example.com',
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: pl ? 'Login' : 'Username',
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: hidePassword,
                decoration: InputDecoration(
                  labelText: pl ? 'Hasło' : 'Password',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => hidePassword = !hidePassword),
                    icon: Icon(
                      hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (error != null) ...[
                SizedBox(height: 12),
                Text(error!, style: TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: connecting ? null : () => Navigator.pop(context, false),
          child: Text(pl ? 'Anuluj' : 'Cancel'),
        ),
        FilledButton(
          onPressed: connecting ? null : save,
          child: connecting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(pl ? 'Zapisz' : 'Save'),
        ),
      ],
    );
  }
}

// SHARED UI

Widget _sectionLabel(String text) {
  return Text(
    text,
    style: TextStyle(
      color: muted,
      fontSize: 11,
      letterSpacing: 2,
      fontWeight: FontWeight.bold,
    ),
  );
}

InputDecoration _inputDecoration(IconData icon, {String? hint, String? label}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: panel,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;

    final background = active
        ? surface
        : hovered
        ? surface.withOpacity(0.55)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? primaryText.withOpacity(0.07)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 3,
                      height: 19,
                      decoration: BoxDecoration(
                        color: active ? primaryText : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Icon(
                      widget.icon,
                      size: 19,
                      color: active || hovered ? primaryText : muted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: active || hovered ? primaryText : muted,
                          fontSize: 13,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                          letterSpacing: -0.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  _HoverCard({required this.child, required this.onTap});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedScale(
        scale: hovered ? 1.035 : 1,
        duration: Duration(milliseconds: 160),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: hovered ? surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _PlaylistCloudClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.18, h * 0.79)
      ..cubicTo(w * 0.06, h * 0.78, w * 0.01, h * 0.66, w * 0.06, h * 0.54)
      ..cubicTo(w * 0.09, h * 0.44, w * 0.18, h * 0.39, w * 0.29, h * 0.40)
      ..cubicTo(w * 0.31, h * 0.19, w * 0.49, h * 0.08, w * 0.64, h * 0.20)
      ..cubicTo(w * 0.72, h * 0.25, w * 0.75, h * 0.34, w * 0.76, h * 0.40)
      ..cubicTo(w * 0.91, h * 0.35, w * 1.00, h * 0.47, w * 0.98, h * 0.62)
      ..cubicTo(w * 0.97, h * 0.76, w * 0.87, h * 0.83, w * 0.75, h * 0.82)
      ..cubicTo(w * 0.57, h * 0.91, w * 0.35, h * 0.89, w * 0.18, h * 0.79)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _MiniAudioVisualizer extends StatefulWidget {
  final bool isPlaying;

  const _MiniAudioVisualizer({required this.isPlaying});

  @override
  State<_MiniAudioVisualizer> createState() => _MiniAudioVisualizerState();
}

class _MiniAudioVisualizerState extends State<_MiniAudioVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();

    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    if (widget.isPlaying) {
      _animation.repeat();
    } else {
      _animation.value = 0.15;
    }
  }

  @override
  void didUpdateWidget(covariant _MiniAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _animation.repeat();
      } else {
        _animation.stop();
        _animation.value = 0.15;
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 38,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _MiniVisualizerPainter(
              phase: _animation.value,
              active: widget.isPlaying,
              color: primaryText,
            ),
          );
        },
      ),
    );
  }
}

class _MiniVisualizerPainter extends CustomPainter {
  final double phase;
  final bool active;
  final Color color;

  _MiniVisualizerPainter({
    required this.phase,
    required this.active,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const count = 9;
    const barWidth = 2.6;
    const gap = 2.0;

    final totalWidth = count * barWidth + (count - 1) * gap;
    final startX = (size.width - totalWidth) / 2;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final wave = math.sin(phase * math.pi * 2 + i * 0.78);
      final secondary = math.sin(phase * math.pi * 4 - i * 0.45);

      final amount = active
          ? 0.18 + ((wave + 1) / 2) * 0.72
          : 0.25 + (i % 3) * 0.08;

      final height = 5 + amount * (size.height - 7);
      final x = startX + i * (barWidth + gap);
      final y = (size.height - height) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, height),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniVisualizerPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.active != active ||
        oldDelegate.color != color;
  }
}
