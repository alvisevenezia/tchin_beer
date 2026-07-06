import 'package:flutter_test/flutter_test.dart';
import 'package:pintes_app/models/feed_item.dart';
import 'package:pintes_app/models/profile.dart';

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

  test('FeedItem.fromJson parses reactions + my_reaction, defaults to empty', () {
    final withoutReactions = FeedItem.fromJson({
      'id': 'a',
      'number': 1,
      'name': 'Léo',
      'city': 'Toulouse',
      'tone': 'coral',
      'likes': 0,
      'liked': false,
    });
    expect(withoutReactions.reactions, <String, int>{});
    expect(withoutReactions.myReaction, isNull);

    final withReactions = FeedItem.fromJson({
      'id': 'a',
      'number': 1,
      'name': 'Léo',
      'city': 'Toulouse',
      'tone': 'coral',
      'likes': 0,
      'liked': false,
      'reactions': {'fire': 2, 'star': 1},
      'my_reaction': 'fire',
    });
    expect(withReactions.reactions, {'fire': 2, 'star': 1});
    expect(withReactions.myReaction, 'fire');

    final updated = withReactions.withReaction(
      reactions: {'fire': 1},
      myReaction: null,
    );
    expect(updated.reactions, {'fire': 1});
    expect(updated.myReaction, isNull);
    expect(updated.id, 'a'); // autres champs préservés
  });

  test('Profile.fromJson parses availableReactions, defaults to empty', () {
    final withoutReactions = Profile.fromJson({
      'pseudo': 'Léo',
      'city': 'Toulouse',
      'myCount': 1,
      'streak': 1,
      'isPremium': false,
    });
    expect(withoutReactions.availableReactions, <String>[]);

    final withReactions = Profile.fromJson({
      'pseudo': 'Léo',
      'city': 'Toulouse',
      'myCount': 1,
      'streak': 1,
      'isPremium': false,
      'availableReactions': ['fire', 'star'],
    });
    expect(withReactions.availableReactions, ['fire', 'star']);
  });

  test('FeedItem.fromJson parses posted_at/invalidated/my_red_card/is_mine, defaults', () {
    final withoutFields = FeedItem.fromJson({
      'id': 'a',
      'number': 1,
      'name': 'Léo',
      'city': 'Toulouse',
      'tone': 'coral',
      'likes': 0,
      'liked': false,
    });
    expect(withoutFields.postedAt, isNull);
    expect(withoutFields.invalidated, false);
    expect(withoutFields.myRedCard, false);
    expect(withoutFields.isMine, false);

    final withFields = FeedItem.fromJson({
      'id': 'a',
      'number': 1,
      'name': 'Léo',
      'city': 'Toulouse',
      'tone': 'coral',
      'likes': 0,
      'liked': false,
      'posted_at': '2026-07-06T14:30:00+00:00',
      'invalidated': true,
      'my_red_card': true,
      'is_mine': true,
    });
    expect(withFields.postedAt, DateTime.parse('2026-07-06T14:30:00+00:00'));
    expect(withFields.invalidated, true);
    expect(withFields.myRedCard, true);
    expect(withFields.isMine, true);

    final updated = withFields.withRedCard(myRedCard: false, invalidated: false);
    expect(updated.myRedCard, false);
    expect(updated.invalidated, false);
    expect(updated.id, 'a'); // autres champs préservés
  });
}
