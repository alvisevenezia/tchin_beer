class FeedItem {
  const FeedItem({
    required this.id,
    required this.number,
    required this.name,
    required this.city,
    required this.tone,
    required this.likes,
    required this.liked,
  });
  final String id;
  final int number;
  final String name;
  final String city;
  final String tone;
  final int likes;
  final bool liked;

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
    id: j['id'] as String,
    number: j['number'] as int,
    name: j['name'] as String,
    city: j['city'] as String,
    tone: j['tone'] as String,
    likes: j['likes'] as int,
    liked: j['liked'] as bool,
  );

  FeedItem copyWith({int? likes, bool? liked}) => FeedItem(
    id: id,
    number: number,
    name: name,
    city: city,
    tone: tone,
    likes: likes ?? this.likes,
    liked: liked ?? this.liked,
  );
}
