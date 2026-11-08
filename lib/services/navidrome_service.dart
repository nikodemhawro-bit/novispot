import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class NavidromeService {
  final String serverUrl;
  final String username;
  final String password;

  static const String clientName = 'Novispot';
  static const String apiVersion = '1.16.1';

  NavidromeService({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  Uri get _baseUri {
    var address = serverUrl.trim();

    if (!address.startsWith('http://') && !address.startsWith('https://')) {
      address = 'https://$address';
    }

    final uri = Uri.parse(address);

    if (!uri.hasAuthority || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw Exception('Nieprawidłowy adres serwera.');
    }

    return uri;
  }

  Uri _buildUri(String endpoint, [Map<String, String>? parameters]) {
    final base = _baseUri;
    final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');

    final salt = List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    final token = md5.convert(utf8.encode('$password$salt')).toString();

    return base.replace(
      path: '$basePath/rest/$endpoint.view',
      queryParameters: {
        'u': username,
        't': token,
        's': salt,
        'v': apiVersion,
        'c': clientName,
        'f': 'json',
        ...?parameters,
      },
    );
  }

  Future<Map<String, dynamic>> _request(
    String endpoint, [
    Map<String, String>? parameters,
  ]) async {
    final response = await http
        .get(_buildUri(endpoint, parameters))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Błąd serwera: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Nieprawidłowa odpowiedź serwera.');
    }

    final root = decoded['subsonic-response'];

    if (root is! Map<String, dynamic>) {
      throw Exception('Serwer nie obsługuje odpowiedzi Subsonic.');
    }

    if (root['status'] != 'ok') {
      final error = root['error'];
      throw Exception(
        error is Map ? error['message']?.toString() : 'Błąd Navidrome.',
      );
    }

    return root;
  }

  Future<bool> testConnection() async {
    final result = await _request('ping');
    return result['status'] == 'ok';
  }

  Future<List<dynamic>> getArtists() async {
    final result = await _request('getArtists');
    final artists = result['artists'];

    if (artists is! Map) return [];

    final indexes = artists['index'];
    if (indexes is! List) return [];

    return indexes.whereType<Map>().expand((item) {
      final entries = item['artist'];
      return entries is List ? entries : <dynamic>[];
    }).toList();
  }

  Future<List<dynamic>> getAlbums({
    String type = 'newest',
    int size = 50,
  }) async {
    final result = await _request('getAlbumList2', {
      'type': type,
      'size': size.toString(),
    });

    final albumList = result['albumList2'];
    if (albumList is! Map) return [];

    final albums = albumList['album'];
    return albums is List ? albums : [];
  }

  Future<List<dynamic>> getAlbumSongs(String albumId) async {
    final result = await _request('getAlbum', {'id': albumId});
    final album = result['album'];

    if (album is! Map) return [];

    final songs = album['song'];
    return songs is List ? songs : [];
  }

  Future<List<dynamic>> searchSongs(String query) async {
    final result = await _request('search3', {
      'query': query,
      'artistCount': '0',
      'albumCount': '0',
      'songCount': '50',
    });

    final searchResult = result['searchResult3'];
    if (searchResult is! Map) return [];

    final songs = searchResult['song'];
    return songs is List ? songs : [];
  }

  Future<List<dynamic>> getStarredSongs() async {
    final result = await _request('getStarred2');
    final starred = result['starred2'];

    if (starred is! Map) return [];

    final songs = starred['song'];
    return songs is List ? songs : [];
  }

  Future<void> starSong(String songId) async {
    await _request('star', {'id': songId});
  }

  Future<void> unstarSong(String songId) async {
    await _request('unstar', {'id': songId});
  }

  Future<List<dynamic>> getPlaylists() async {
    final result = await _request('getPlaylists');
    final playlists = result['playlists'];

    if (playlists is! Map) return [];

    final entries = playlists['playlist'];
    return entries is List ? entries : [];
  }

  Future<List<dynamic>> getPlaylistSongs(String playlistId) async {
    final result = await _request('getPlaylist', {'id': playlistId});
    final playlist = result['playlist'];

    if (playlist is! Map) return [];

    final songs = playlist['entry'];
    return songs is List ? songs : [];
  }

  Future<void> createPlaylist(String name) async {
    await _request('createPlaylist', {'name': name});
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    await _request('updatePlaylist', {
      'playlistId': playlistId,
      'songIdToAdd': songId,
    });
  }

  Uri getCoverArtUrl(String coverArtId, {int size = 400}) {
    return _buildUri('getCoverArt', {
      'id': coverArtId,
      'size': size.toString(),
    });
  }

  Uri getStreamUrl(String songId) {
    return _buildUri('stream', {'id': songId});
  }
}
