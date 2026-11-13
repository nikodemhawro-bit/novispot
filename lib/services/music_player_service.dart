import "package:audioplayers/audioplayers.dart" show PlayerState;
import "package:miniaudio_player/miniaudio_player.dart" hide PlayerState;

class MusicPlayerService {
  final MiniaudioPlayer _player = MiniaudioPlayer();

  Stream<Duration> get positionStream => _player.stream.position;

  Stream<Duration?> get durationStream =>
      _player.stream.duration.map<Duration?>((duration) => duration);

  Stream<PlayerState> get playerStateStream =>
      _player.stream.playbackState.map((state) {
        switch (state) {
          case PlaybackState.playing:
            return PlayerState.playing;
          case PlaybackState.paused:
            return PlayerState.paused;
          case PlaybackState.completed:
            return PlayerState.completed;
          case PlaybackState.buffering:
            return _player.state.playing
                ? PlayerState.playing
                : PlayerState.stopped;
          case PlaybackState.stopped:
          case PlaybackState.opening:
          case PlaybackState.error:
            return PlayerState.stopped;
        }
      });

  Stream<void> get completedStream =>
      _player.stream.completed
          .where((completed) => completed)
          .map<void>((_) {});

  Equalizer get equalizer => _player.state.equalizer;

  Stream<Equalizer> get equalizerStream => _player.stream.equalizer;

  Future<void> setEqualizer(Equalizer equalizer) async {
    await _player.action.setEqualizer(equalizer);
  }

  Future<void> setEqualizerBand(int bandIndex, double gainDb) async {
    await _player.action.setEqualizerBand(bandIndex, gainDb);
  }

  Future<void> play(String url) async {
    await _player.action.open(url);
    await _player.action.play();
  }

  Future<void> playLocalFile(String path) async {
    await _player.action.open(path);
    await _player.action.play();
  }

  Future<void> pause() async {
    await _player.action.pause();
  }

  Future<void> resume() async {
    await _player.action.play();
  }

  Future<void> stop() async {
    await _player.action.stop();
  }

  Future<void> seek(Duration position) async {
    await _player.action.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await _player.action.setVolume(volume);
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
