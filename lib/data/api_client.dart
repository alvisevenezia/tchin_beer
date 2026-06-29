import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/feed_item.dart';
import '../models/profile.dart';
import '../models/ranking.dart';
import '../models/session.dart';
import 'token_store.dart';

class ApiException implements Exception {
  ApiException(this.status, this.code);
  final int status;
  final String? code;
  @override
  String toString() => 'ApiException($status, $code)';
}

MediaType _mediaType(String contentType) {
  final parts = contentType.split('/');
  return MediaType(parts.first, parts.length > 1 ? parts[1] : 'octet-stream');
}

class ApiClient {
  ApiClient(this._client, {required this.baseUrl, required this.tokens});
  final http.Client _client;
  final String baseUrl;
  final TokenStore tokens;

  Future<Map<String, String>> _headers() async {
    final t = await tokens.read();
    return {'authorization': ?(t == null ? null : 'Bearer $t')};
  }

  Uri _uri(String path, [Map<String, dynamic>? q]) => Uri.parse(
    '$baseUrl$path',
  ).replace(queryParameters: q?.map((k, v) => MapEntry(k, '$v')));

  Never _fail(http.Response r) {
    String? code;
    try {
      final body = jsonDecode(r.body);
      if (body is Map && body['detail'] is Map) {
        code = body['detail']['code'] as String?;
      }
    } catch (_) {}
    throw ApiException(r.statusCode, code);
  }

  Future<Session> createDevice({
    required String pseudo,
    required String city,
    String? deviceToken,
  }) async {
    final r = await _client.post(
      _uri('/auth/device'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'pseudo': pseudo,
        'city': city,
        'device_token': ?deviceToken,
      }),
    );
    if (r.statusCode != 200) _fail(r);
    return Session.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<int> getCounter() async {
    final r = await _client.get(_uri('/counter'), headers: await _headers());
    if (r.statusCode != 200) _fail(r);
    return (jsonDecode(r.body) as Map<String, dynamic>)['total'] as int;
  }

  Future<({int number, int total, FeedItem item})> postPinte({
    required List<int> bytes,
    required String filename,
    required String contentType,
    String? tone,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/pintes'))
      ..headers.addAll(await _headers())
      ..files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: filename,
          contentType: _mediaType(contentType),
        ),
      );
    if (tone != null) req.fields['tone'] = tone;
    final r = await http.Response.fromStream(await _client.send(req));
    if (r.statusCode != 200) _fail(r);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (
      number: j['number'] as int,
      total: j['total'] as int,
      item: FeedItem.fromJson(j['item'] as Map<String, dynamic>),
    );
  }

  Future<({List<FeedItem> items, String? nextCursor})> getFeed({
    String? cursor,
    int limit = 20,
  }) async {
    final r = await _client.get(
      _uri('/feed', {'cursor': ?cursor, 'limit': limit}),
      headers: await _headers(),
    );
    if (r.statusCode != 200) _fail(r);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (
      items: (j['items'] as List)
          .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: j['next_cursor'] as String?,
    );
  }

  Future<({int likes, bool liked})> toggleLike(String pinteId) async {
    final r = await _client.post(
      _uri('/pintes/$pinteId/like'),
      headers: await _headers(),
    );
    if (r.statusCode != 200) _fail(r);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (likes: j['likes'] as int, liked: j['liked'] as bool);
  }

  Future<Profile> getMe() async {
    final r = await _client.get(_uri('/me'), headers: await _headers());
    if (r.statusCode != 200) _fail(r);
    return Profile.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Rankings> getRankings({String period = 'day', int limit = 10}) async {
    final r = await _client.get(
      _uri('/rankings', {'period': period, 'limit': limit}),
      headers: await _headers(),
    );
    if (r.statusCode != 200) _fail(r);
    return Rankings.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
