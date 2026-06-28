import 'package:flutter_test/flutter_test.dart';
import 'package:pintes_app/models/feed_item.dart';

void main() {
  test('FeedItem.fromJson + copyWith', () {
    final i = FeedItem.fromJson({
      'id': 'a',
      'number': 42,
      'name': 'Léo',
      'city': 'Toulouse',
      'tone': 'coral',
      'likes': 3,
      'liked': false,
    });
    expect(i.number, 42);
    expect(i.copyWith(liked: true, likes: 4).liked, true);
  });
}
