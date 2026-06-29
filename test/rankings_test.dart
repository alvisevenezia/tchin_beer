import 'package:flutter_test/flutter_test.dart';
import 'package:pintes_app/models/ranking.dart';

void main() {
  test('Rankings.fromJson parses cities and nullable me', () {
    final j = {
      'period': 'day',
      'cities': [
        {'key': 'lyon', 'name': 'Lyon', 'count': 5, 'rank': 1},
        {'key': 'paris', 'name': 'Paris', 'count': 3, 'rank': 2},
      ],
      'me': {'key': 'paris', 'name': 'Paris', 'count': 3, 'rank': 2},
    };
    final r = Rankings.fromJson(j);
    expect(r.period, 'day');
    expect(r.cities.first.name, 'Lyon');
    expect(r.me!.rank, 2);

    final r2 = Rankings.fromJson({'period': 'week', 'cities': [], 'me': null});
    expect(r2.me, isNull);
    expect(r2.cities, isEmpty);
  });
}
