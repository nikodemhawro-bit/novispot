import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _LyricLine {
  final Duration time;
  final String text;

  const _LyricLine(this.time, this.text);
}

class LyricsScreen extends StatefulWidget {
  final String title;
  final String artist;
  final String? coverUrl;
  final String? coverPath;
  final Stream<Duration> positionStream;
  final bool polish;

  const LyricsScreen({
    super.key,
    required this.title,
    required this.artist,
    required this.positionStream,
    this.coverUrl,
    this.coverPath,
    this.polish = true,
  });

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  static const Color muted = Color(0xFFAAAAAA);

  bool loading = true;
  String? error;
  String? plainLyrics;
  List<_LyricLine> lines = [];
  bool synced = false;

  final Map<int, GlobalKey> _lineKeys = {};
  int _lastCenteredIndex = -2;

  bool get pl => widget.polish;

  @override
  void initState() {
    super.initState();
    fetchLyrics();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<Map<String, dynamic>?> _requestExact() async {
    if (widget.artist.trim().isEmpty) return null;

    final uri = Uri.https('lrclib.net', '/api/get', {
      'track_name': widget.title.trim(),
      'artist_name': widget.artist.trim(),
    });

    final response = await http
        .get(uri, headers: {'User-Agent': 'Novispot/0.3.0'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 404) return null;

    if (response.statusCode == 429) {
      throw Exception(
        pl ? 'Za dużo zapytań. Spróbuj później.' : 'Too many requests.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) return decoded;

    return null;
  }

  Future<Map<String, dynamic>?> _searchLyrics() async {
    final uri = Uri.https('lrclib.net', '/api/search', {
      'q': '${widget.title.trim()} ${widget.artist.trim()}'.trim(),
    });

    final response = await http
        .get(uri, headers: {'User-Agent': 'Novispot/0.3.0'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 429) {
      throw Exception('HTTP 429');
    }

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List || decoded.isEmpty) return null;

    final results = decoded.whereType<Map<String, dynamic>>().toList();

    if (results.isEmpty) return null;

    final wantedTitle = widget.title.toLowerCase().trim();
    final wantedArtist = widget.artist.toLowerCase().trim();

    for (final item in results) {
      final title = (item['trackName'] ?? '').toString().toLowerCase().trim();

      final artist = (item['artistName'] ?? '').toString().toLowerCase().trim();

      if (title == wantedTitle &&
          (wantedArtist.isEmpty || artist == wantedArtist)) {
        return item;
      }
    }

    return results.first;
  }

  String _lyricsCacheKey() {
    String normalize(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    final identity = '${normalize(widget.title)}|${normalize(widget.artist)}';
    final encoded = base64Url.encode(utf8.encode(identity));
    return 'novispot_lyrics_v1_$encoded';
  }

  Future<Map<String, dynamic>?> _readLyricsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_lyricsCacheKey());
      if (saved == null || saved.isEmpty) return null;
      final decoded = jsonDecode(saved);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('Novispot: lyrics cache read failed: $e');
    }
    return null;
  }

  Future<void> _saveLyricsCache(Map<String, dynamic> result) async {
    final syncedText = result['syncedLyrics']?.toString() ?? '';
    final plainText = result['plainLyrics']?.toString() ?? '';
    if (syncedText.trim().isEmpty && plainText.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lyricsCacheKey(),
        jsonEncode({
          'syncedLyrics': syncedText,
          'plainLyrics': plainText,
          'trackName': result['trackName']?.toString() ?? widget.title,
          'artistName': result['artistName']?.toString() ?? widget.artist,
        }),
      );
    } catch (e) {
      debugPrint('Novispot: lyrics cache save failed: $e');
    }
  }

  void _applyLyricsResult(Map<String, dynamic> result) {
    final syncedText = result['syncedLyrics']?.toString();
    final plainText = result['plainLyrics']?.toString();
    final parsed = _parseLrc(syncedText ?? '');

    if (!mounted) return;
    setState(() {
      lines = parsed;
      synced = parsed.isNotEmpty;
      plainLyrics = plainText;
      loading = false;
      error = null;
      _lastCenteredIndex = -2;
      _lineKeys.clear();

      if (parsed.isEmpty && (plainText == null || plainText.trim().isEmpty)) {
        error = pl
            ? 'Ten utwór nie ma dostępnego tekstu.'
            : 'No lyrics available for this track.';
      }
    });
  }

  Future<void> fetchLyrics() async {
    if (widget.title.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = pl ? 'Brakuje tytułu utworu.' : 'Missing track title.';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    final cached = await _readLyricsCache();
    if (!mounted) return;
    if (cached != null) _applyLyricsResult(cached);

    try {
      var result = await _requestExact();
      result ??= await _searchLyrics();

      if (!mounted) return;
      if (result == null) {
        if (cached == null) {
          setState(() {
            loading = false;
            error = pl
                ? 'Nie znaleziono tekstu tej piosenki.'
                : 'Lyrics not found.';
          });
        }
        return;
      }

      await _saveLyricsCache(result);
      if (!mounted) return;
      _applyLyricsResult(result);
    } catch (e) {
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          loading = false;
          error = null;
        });
      } else {
        setState(() {
          loading = false;
          error = pl
              ? 'Nie udało się pobrać tekstu. Sprawdź internet.'
              : 'Could not load lyrics. Check your connection.';
        });
      }
    }
  }

  List<_LyricLine> _parseLrc(String input) {
    final result = <_LyricLine>[];

    final regex = RegExp(r'\[(\d{2}):(\d{2})(?:\.(\d{1,3}))?\]\s*(.*)');

    for (final line in input.split('\n')) {
      final match = regex.firstMatch(line.trim());

      if (match == null) continue;

      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final fraction = match.group(3) ?? '0';

      final milliseconds =
          int.tryParse(fraction.padRight(3, '0').substring(0, 3)) ?? 0;

      result.add(
        _LyricLine(
          Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          ),
          match.group(4)?.trim() ?? '',
        ),
      );
    }

    result.sort((a, b) => a.time.compareTo(b.time));

    return result;
  }

  int _activeLine(Duration position) {
    int active = -1;

    for (int i = 0; i < lines.length; i++) {
      if (position >= lines[i].time) {
        active = i;
      } else {
        break;
      }
    }

    return active;
  }

  void _centerLine(int index) {
    if (index < 0 || index >= lines.length) return;
    if (index == _lastCenteredIndex) return;

    _lastCenteredIndex = index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final context = _lineKeys[index]?.currentContext;

      if (context == null) return;

      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Widget _albumCover({double size = 230}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 35,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.coverPath != null
          ? Image.file(
              File(widget.coverPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF252525),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white54,
                  size: 75,
                ),
              ),
            )
          : widget.coverUrl == null
          ? Container(
              color: const Color(0xFF252525),
              child: const Icon(
                Icons.music_note_rounded,
                color: Colors.white54,
                size: 75,
              ),
            )
          : Image.network(
              widget.coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF252525),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white54,
                  size: 75,
                ),
              ),
            ),
    );
  }

  Widget _albumInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _albumCover(),
        const SizedBox(height: 28),
        Text(
          widget.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          widget.artist,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (synced) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                pl ? 'SYNCHRONIZOWANY TEKST' : 'SYNCED LYRICS',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _compactAlbumInfo() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _albumCover(size: 66),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _characterKaraoke(
    String text,
    int lineIndex,
    Duration position,
  ) {
    if (text.isEmpty) {
      return const Text('♪', textAlign: TextAlign.center);
    }

    final start = lines[lineIndex].time;

    final lineDuration = lineIndex + 1 < lines.length
        ? lines[lineIndex + 1].time - start
        : const Duration(seconds: 3);

    final elapsed = position - start;

    final progress = (elapsed.inMicroseconds /
            lineDuration.inMicroseconds)
        .clamp(0.0, 1.0);

    final glow = 1.0 - progress;

    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        shadows: [
          Shadow(
            color: Colors.white.withValues(alpha: glow * 0.30),
            blurRadius: 5 + glow * 6,
          ),
          Shadow(
            color: Colors.white.withValues(alpha: glow * 0.12),
            blurRadius: glow * 12,
          ),
        ],
      ),
    );
  }

  Widget _lyricsView() {
    if (loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 27,
              height: 27,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              pl ? 'Szukam tekstu...' : 'Searching lyrics...',
              style: const TextStyle(color: muted),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lyrics_outlined, size: 50, color: muted),
              const SizedBox(height: 18),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: fetchLyrics,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
                child: Text(pl ? 'Spróbuj ponownie' : 'Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (!synced) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 40),
        child: Text(
          plainLyrics ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            height: 1.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: widget.positionStream,
      initialData: Duration.zero,
      builder: (context, snapshot) {
        final active = _activeLine(snapshot.data ?? Duration.zero);

        _centerLine(active);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 180),
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final isActive = index == active;
            final distance = (index - active).abs();

            final color = isActive
                ? Colors.white
                : distance == 1
                ? Colors.white54
                : distance == 2
                ? Colors.white30
                : Colors.white.withValues(alpha: 0.15);

            return Container(
              key: _lineKeys.putIfAbsent(index, () => GlobalKey()),
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: isActive ? 29 : 20,
                  height: 1.35,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: isActive ? -0.5 : 0,
                ),
                child: isActive
                    ? _characterKaraoke(
                        lines[index].text,
                        index,
                        snapshot.data ?? Duration.zero,
                      )
                    : Text(
                        lines[index].text.isEmpty ? '♪' : lines[index].text,
                        textAlign: TextAlign.center,
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _background() {
    if (widget.coverUrl == null && widget.coverPath == null) {
      return Container(color: const Color(0xFF101010));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
          child: widget.coverPath != null
              ? Image.file(
                  File(widget.coverPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF101010)),
                )
              : Image.network(
                  widget.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF101010)),
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withValues(alpha: 0.42),
                const Color(0xFF080808).withValues(alpha: 0.78),
                Colors.black.withValues(alpha: 0.65),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _background(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        tooltip: pl ? 'Wróć' : 'Back',
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pl ? 'TEKST UTWORU' : 'LYRICS',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: fetchLyrics,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white70,
                        ),
                        tooltip: pl ? 'Odśwież tekst' : 'Refresh lyrics',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 820) {
                        return Row(
                          children: [
                            SizedBox(
                              width: 330,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  45,
                                  20,
                                  25,
                                  35,
                                ),
                                child: Center(
                                  child: SingleChildScrollView(
                                    child: _albumInfo(),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  15,
                                  0,
                                  45,
                                  20,
                                ),
                                child: _lyricsView(),
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                            child: _compactAlbumInfo(),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: _lyricsView(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
