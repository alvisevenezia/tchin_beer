import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pintes_app/models/feed_item.dart';
import 'package:pintes_app/ui/widgets/feed_item_card.dart';

FeedItem _item({bool invalidated = false, bool isMine = false}) => FeedItem.fromJson({
  'id': 'a',
  'number': 1,
  'name': 'Léo',
  'city': 'Toulouse',
  'tone': 'coral',
  'likes': 0,
  'liked': false,
  'invalidated': invalidated,
  'is_mine': isMine,
});

void main() {
  testWidgets('shows "Invalidée" overlay only when item.invalidated', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FeedItemCard(
              item: _item(invalidated: true),
              onLike: () {},
              onReact: (_) {},
              onRedCard: () {},
            ),
          ),
        ),
      ),
    ));
    expect(find.text('Invalidée'), findsOneWidget);
  });

  testWidgets('hides "Invalidée" overlay when item is active', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FeedItemCard(
              item: _item(invalidated: false),
              onLike: () {},
              onReact: (_) {},
              onRedCard: () {},
            ),
          ),
        ),
      ),
    ));
    expect(find.text('Invalidée'), findsNothing);
  });

  testWidgets("hides the red card button on the viewer's own pinte", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FeedItemCard(
              item: _item(isMine: true),
              onLike: () {},
              onReact: (_) {},
              onRedCard: () {},
            ),
          ),
        ),
      ),
    ));
    expect(find.byIcon(Icons.flag), findsNothing);
  });

  testWidgets("shows the red card button on someone else's pinte", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FeedItemCard(
              item: _item(isMine: false),
              onLike: () {},
              onReact: (_) {},
              onRedCard: () {},
            ),
          ),
        ),
      ),
    ));
    expect(find.byIcon(Icons.flag), findsOneWidget);
  });
}
