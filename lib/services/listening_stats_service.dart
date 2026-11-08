import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ListeningSongStat {
  final String id;
  final String title;
  final String artist;
  final int seconds;

  const ListeningSongStat({
    required this.id,
    required this.title,
    required this.artist,
    required this.seconds,
  });
}

class WeeklyListeningStats {
  final int totalSeconds;
  final int todaySeconds;
  final int allTimeSeconds;
  final List<int> dailySeconds;
  final List<ListeningSongStat> topSongs;

  const WeeklyListeningStats({
    required this.totalSeconds,
    required this.todaySeconds,
    required this.allTimeSeconds,
    required this.dailySeconds,
    required this.topSongs,
  });
}



class YearlyListeningStats {
  final int year;
  final int totalSeconds;
  final int listeningDays;
  final int uniqueTracks;
  final String topArtist;
  final int topArtistSeconds;
  final List<ListeningSongStat> topSongs;

  const YearlyListeningStats({
    required this.year,
    required this.totalSeconds,
    required this.listeningDays,
    required this.uniqueTracks,
    required this.topArtist,
    required this.topArtistSeconds,
    required this.topSongs,
  });
}

class ListeningStatsService {
  static const String _storageKey = 'novispot_listening_stats_v1';

  String _dateKey(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);

    return '${local.year}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>> _readData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null) return {};

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return {};
    }

    return {};
  }

  Future<void> _saveData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> recordListening({
    required String songId,
    required String title,
    required String artist,
    required int seconds,
  }) async {
    if (seconds <= 0 || songId.isEmpty) return;

    final data = await _readData();
    final date = _dateKey(DateTime.now());

    final day = Map<String, dynamic>.from(
      data[date] is Map ? data[date] : {},
    );

    final previous = Map<String, dynamic>.from(
      day[songId] is Map ? day[songId] : {},
    );

    day[songId] = {
      'title': title,
      'artist': artist,
      'seconds': ((previous['seconds'] as num?)?.toInt() ?? 0) + seconds,
    };

    data[date] = day;

    await _saveData(data);
  }

  Future<WeeklyListeningStats> getWeeklyStats() async {
    final data = await _readData();
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(
      Duration(days: today.weekday - 1),
    );

    final dailySeconds = <int>[];
    final songTotals = <String, ListeningSongStat>{};

    var weeklyTotal = 0;
    var todayTotal = 0;
    var allTimeTotal = 0;

    for (final entry in data.entries) {
      if (entry.value is! Map) continue;

      final day = Map<String, dynamic>.from(entry.value as Map);
      final date = DateTime.tryParse(entry.key);

      for (final songEntry in day.entries) {
        if (songEntry.value is! Map) continue;

        final song = Map<String, dynamic>.from(songEntry.value as Map);
        final seconds = (song['seconds'] as num?)?.toInt() ?? 0;

        allTimeTotal += seconds;

        final id = songEntry.key;
        final previous = songTotals[id];

        songTotals[id] = ListeningSongStat(
          id: id,
          title: song['title']?.toString() ?? 'Nieznany utwór',
          artist: song['artist']?.toString() ?? 'Nieznany wykonawca',
          seconds: seconds + (previous?.seconds ?? 0),
        );

        if (date == null) continue;

        if (!date.isBefore(monday) && !date.isAfter(today)) {
          weeklyTotal += seconds;
        }

        if (_dateKey(date) == _dateKey(today)) {
          todayTotal += seconds;
        }
      }
    }

    for (var i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final day = data[_dateKey(date)];

      var seconds = 0;

      if (day is Map) {
        for (final song in day.values) {
          if (song is Map) {
            seconds += (song['seconds'] as num?)?.toInt() ?? 0;
          }
        }
      }

      dailySeconds.add(seconds);
    }

    final topSongs = songTotals.values.toList()
      ..sort((a, b) => b.seconds.compareTo(a.seconds));

    return WeeklyListeningStats(
      totalSeconds: weeklyTotal,
      todaySeconds: todayTotal,
      allTimeSeconds: allTimeTotal,
      dailySeconds: dailySeconds,
      topSongs: topSongs.take(5).toList(),
    );
  }


  Future<YearlyListeningStats> getYearlyStats({int? year}) async {
    final selectedYear = year ?? DateTime.now().year;
    final data = await _readData();

    final Map<String, Map<String, dynamic>> songs = {};
    final Map<String, int> artists = {};
    int totalSeconds = 0;
    int listeningDays = 0;

    for (final dayEntry in data.entries) {
      final date = DateTime.tryParse(dayEntry.key);
      if (date == null || date.year != selectedYear) continue;
      if (dayEntry.value is! Map) continue;

      final dayData = Map<String, dynamic>.from(dayEntry.value as Map);
      int daySeconds = 0;

      for (final songEntry in dayData.entries) {
        if (songEntry.value is! Map) continue;

        final song = Map<String, dynamic>.from(songEntry.value as Map);
        final seconds = (song['seconds'] as num?)?.toInt() ?? 0;
        if (seconds <= 0) continue;

        final title = song['title']?.toString() ?? 'Nieznany utwór';
        final artist = song['artist']?.toString() ?? 'Nieznany wykonawca';

        daySeconds += seconds;
        totalSeconds += seconds;

        final id = songEntry.key;
        final existing = songs[id];

        songs[id] = {
          'title': title,
          'artist': artist,
          'seconds': ((existing?['seconds'] as int?) ?? 0) + seconds,
        };

        artists[artist] = (artists[artist] ?? 0) + seconds;
      }

      if (daySeconds > 0) listeningDays++;
    }

    final sortedSongs = songs.entries.toList()
      ..sort((a, b) =>
          (b.value['seconds'] as int).compareTo(a.value['seconds'] as int));

    final topSongs = sortedSongs.take(5).map((entry) {
      return ListeningSongStat(
        id: entry.key,
        title: entry.value['title'] as String,
        artist: entry.value['artist'] as String,
        seconds: entry.value['seconds'] as int,
      );
    }).toList();

    final sortedArtists = artists.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return YearlyListeningStats(
      year: selectedYear,
      totalSeconds: totalSeconds,
      listeningDays: listeningDays,
      uniqueTracks: songs.length,
      topArtist: sortedArtists.isEmpty ? '—' : sortedArtists.first.key,
      topArtistSeconds:
          sortedArtists.isEmpty ? 0 : sortedArtists.first.value,
      topSongs: topSongs,
    );
  }

}

