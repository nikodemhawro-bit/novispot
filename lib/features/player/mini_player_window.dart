import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

const WindowMethodChannel miniPlayerCommandChannel = WindowMethodChannel(
  'novispot_mini_player_commands',
  mode: ChannelMode.unidirectional,
);

class MiniPlayerWindow extends StatefulWidget {
  final WindowController controller;

  const MiniPlayerWindow({super.key, required this.controller});

  @override
  State<MiniPlayerWindow> createState() => _MiniPlayerWindowState();
}

class _MiniPlayerWindowState extends State<MiniPlayerWindow> {
  Map<String, dynamic> data = {};
  double? dragPosition;

  @override
  void initState() {
    super.initState();

    unawaited(
      widget.controller.setWindowMethodHandler((call) async {
        if (call.method == 'updateState' && call.arguments is Map) {
          if (mounted) {
            setState(() {
              data = Map<String, dynamic>.from(call.arguments as Map);
            });
          }
        }
        return null;
      }),
    );

    unawaited(miniPlayerCommandChannel.invokeMethod('requestState'));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final window = WindowManager.instance.getCurrent();
      if (window != null) {
        window.title = 'Novispot Mini Player';
        window.setSize(const Size(460, 220).toNative(), false);
        window.minimumSize = const Size(420, 200).toNative();
        window.isResizable = true;
        window.center();
      }
    });
  }

  void command(String name, [dynamic arguments]) {
    unawaited(miniPlayerCommandChannel.invokeMethod(name, arguments));
  }

  Widget artwork() {
    final path = data['coverPath']?.toString() ?? '';
    final url = data['coverUrl']?.toString() ?? '';

    if (path.isNotEmpty && File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }

    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }

    return placeholder();
  }

  Widget placeholder() {
    return Container(
      color: const Color(0xFF252525),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white70, size: 38),
      ),
    );
  }

  String formatTime(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget controlButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    double size = 25,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: size),
      splashRadius: 22,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? '';
    final artist = data['artist']?.toString() ?? '';
    final playing = data['playing'] == true;
    final duration = (data['durationMs'] as num?)?.toInt() ?? 0;
    final position = (data['positionMs'] as num?)?.toInt() ?? 0;
    final maxValue = duration > 0 ? duration.toDouble() : 1.0;
    final shownPosition = (dragPosition ?? position.toDouble()).clamp(
      0.0,
      maxValue,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                    child: Transform.scale(
                      scale: 1.35,
                      child: Opacity(opacity: 0.48, child: artwork()),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xD90A0A0A),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 13, 15, 10),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: SizedBox(
                                width: 88,
                                height: 88,
                                child: artwork(),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title.isEmpty ? 'Nic nie odtwarzam' : title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    artist.isEmpty ? 'Novispot' : artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.65,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Row(
                                    children: [
                                      controlButton(
                                        Icons.skip_previous_rounded,
                                        'Poprzedni utwór',
                                        () => command('previous'),
                                      ),
                                      controlButton(
                                        playing
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        playing ? 'Pauza' : 'Odtwórz',
                                        () => command('playPause'),
                                        size: 30,
                                      ),
                                      controlButton(
                                        Icons.skip_next_rounded,
                                        'Następny utwór',
                                        () => command('next'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Text(
                            formatTime(shownPosition.round()),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 10,
                                ),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                                overlayColor: Colors.white12,
                              ),
                              child: Slider(
                                min: 0,
                                max: maxValue,
                                value: shownPosition,
                                onChanged: duration <= 0
                                    ? null
                                    : (value) {
                                        setState(() => dragPosition = value);
                                      },
                                onChangeEnd: duration <= 0
                                    ? null
                                    : (value) {
                                        command('seek', value.round());
                                        setState(() => dragPosition = null);
                                      },
                              ),
                            ),
                          ),
                          Text(
                            formatTime(duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
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
