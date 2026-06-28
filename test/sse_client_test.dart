import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pintes_app/data/sse_client.dart';

void main() {
  test('parseSse aggregates event + data on blank line', () async {
    final raw =
        'event: counter\n'
        'data: {"type":"counter","total":5}\n'
        '\n'
        'data: {"type":"feed_item"}\n'
        '\n';
    final events = await parseSse(Stream.value(utf8.encode(raw))).toList();
    expect(events.length, 2);
    expect(events[0].event, 'counter');
    expect(events[0].data, '{"type":"counter","total":5}');
    expect(events[1].event, isNull);
  });

  test('parseSse ignores comment keep-alive lines', () async {
    final raw = ': ping\n\ndata: {"type":"counter","total":9}\n\n';
    final events = await parseSse(Stream.value(utf8.encode(raw))).toList();
    expect(events.single.data, '{"type":"counter","total":9}');
  });
}
