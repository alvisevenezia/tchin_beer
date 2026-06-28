import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'token_store.dart';

class SseEvent {
  SseEvent(this.event, this.data);
  final String? event;
  final String data;
}

/// Parse un flux d'octets text/event-stream en SseEvent (sous-ensemble RFC).
Stream<SseEvent> parseSse(Stream<List<int>> bytes) async* {
  String? event;
  final data = StringBuffer();
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        yield SseEvent(event, data.toString());
      }
      event = null;
      data.clear();
      continue;
    }
    if (line.startsWith(':')) continue; // keep-alive
    if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      if (data.isNotEmpty) data.write('\n');
      data.write(line.substring(5).trim());
    }
  }
}

class SseClient {
  SseClient(this._client, {required this.baseUrl, required this.tokens});
  final http.Client _client;
  final String baseUrl;
  final TokenStore tokens;

  Stream<SseEvent> connect(String path) async* {
    final token = await tokens.read();
    final req = http.Request('GET', Uri.parse('$baseUrl$path'))
      ..headers['accept'] = 'text/event-stream'
      ..headers['cache-control'] = 'no-cache';
    if (token != null) req.headers['authorization'] = 'Bearer $token';
    final resp = await _client.send(req);
    yield* parseSse(resp.stream);
  }
}
