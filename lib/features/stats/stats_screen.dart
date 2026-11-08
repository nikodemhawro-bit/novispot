import 'package:flutter/material.dart';
import '../../services/listening_stats_service.dart';

class StatsScreen extends StatefulWidget {
  final bool polish;

  const StatsScreen({super.key, this.polish = true});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final ListeningStatsService _stats = ListeningStatsService();
  late Future<YearlyListeningStats> _future;

  bool get pl => widget.polish;

  static const Color bg = Color(0xFF080808);
  static const Color panel = Color(0xFF151515);
  static const Color surface = Color(0xFF202020);
  static const Color muted = Color(0xFF999999);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = _stats.getYearlyStats();
    });
  }

  String _time(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return pl ? '$hours godz. $minutes min' : '$hours hr $minutes min';
    }
    return pl ? '$minutes min' : '$minutes min';
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: child,
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white70, size: 21),
            const SizedBox(height: 18),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FutureBuilder<YearlyListeningStats>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.white70, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      pl ? 'Nie udało się wczytać Wrapped' : 'Could not load Wrapped',
                      style: const TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      onPressed: _refresh,
                      child: Text(pl ? 'Spróbuj ponownie' : 'Try again'),
                    ),
                  ],
                ),
              );
            }

            final stats = snapshot.data!;
            final hasData = stats.totalSeconds > 0;

            return RefreshIndicator(
              color: Colors.black,
              backgroundColor: Colors.white,
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
                children: [
                  Row(
                    children: [
                      Text(
                        'NOVISPOT',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          letterSpacing: 4,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        tooltip: pl ? 'Odśwież' : 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Text(
                    '${stats.year}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 65,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pl ? 'TWÓJ ROK W MUZYCE' : 'YOUR YEAR IN MUSIC',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    pl
                        ? 'Tak wyglądał Twój muzyczny rok w Novispot.'
                        : 'This is what your music year looked like in Novispot.',
                    style: const TextStyle(color: muted, fontSize: 14),
                  ),
                  const SizedBox(height: 28),

                  _card(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pl ? 'CZAS Z MUZYKĄ' : 'TIME WITH MUSIC',
                          style: const TextStyle(
                            color: muted,
                            letterSpacing: 2,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          hasData ? _time(stats.totalSeconds) : '0 min',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pl
                              ? 'Łączny czas słuchania w tym roku'
                              : 'Total listening time this year',
                          style: const TextStyle(color: muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      _metric(
                        pl ? 'Dni słuchania' : 'Listening days',
                        '${stats.listeningDays}',
                        Icons.calendar_month,
                      ),
                      const SizedBox(width: 12),
                      _metric(
                        pl ? 'Różne utwory' : 'Unique tracks',
                        '${stats.uniqueTracks}',
                        Icons.music_note,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pl ? 'TWÓJ TOP WYKONAWCA' : 'YOUR TOP ARTIST',
                          style: const TextStyle(
                            color: muted,
                            letterSpacing: 2,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          hasData ? stats.topArtist : '—',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasData
                              ? '${_time(stats.topArtistSeconds)} ${pl ? 'słuchania' : 'listened'}'
                              : (pl ? 'Brak danych z tego roku' : 'No data for this year'),
                          style: const TextStyle(color: muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pl ? 'NAJCZĘŚCIEJ SŁUCHANE' : 'MOST LISTENED',
                          style: const TextStyle(
                            color: muted,
                            letterSpacing: 2,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (stats.topSongs.isEmpty)
                          Text(
                            pl ? 'Na razie brak danych.' : 'No data yet.',
                            style: const TextStyle(color: muted),
                          )
                        else
                          ...List.generate(stats.topSongs.length, (index) {
                            final song = stats.topSongs[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 17),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '${index + 1}'.padLeft(2, '0'),
                                      style: const TextStyle(
                                        color: muted,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          song.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _time(song.seconds),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: Text(
                      pl
                          ? 'Statystyki obejmują dane zapisane przez Novispot.'
                          : 'Stats include listening data recorded by Novispot.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
