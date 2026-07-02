class FeedItem {
  const FeedItem({
    required this.id,
    required this.number,
    required this.name,
    required this.city,
    required this.tone,
    required this.likes,
    required this.liked,
    this.frame,
    this.avatarUrl,
    this.photoUrl,
    this.isPremium = false,
    this.reactions = const {},
    this.myReaction,
  });
  final String id;
  final int number;
  final String name;
  final String city;
  final String tone;
  final int likes;
  final bool liked;
  final String? frame;
  final String? avatarUrl;
  final String? photoUrl;
  final bool isPremium;
  final Map<String, int> reactions;
  final String? myReaction;

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
    id: j['id'] as String,
    number: j['number'] as int,
    name: j['name'] as String,
    city: j['city'] as String,
    tone: j['tone'] as String,
    likes: j['likes'] as int,
    liked: j['liked'] as bool,
    frame: j['frame'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    photoUrl: j['photo_url'] as String?,
    isPremium: j['is_premium'] as bool? ?? false,
    reactions: (j['reactions'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as int),
        ) ??
        const {},
    myReaction: j['my_reaction'] as String?,
  );

  FeedItem copyWith({int? likes, bool? liked}) => FeedItem(
    id: id,
    number: number,
    name: name,
    city: city,
    tone: tone,
    likes: likes ?? this.likes,
    liked: liked ?? this.liked,
    frame: frame,
    avatarUrl: avatarUrl,
    photoUrl: photoUrl,
    isPremium: isPremium,
    reactions: reactions,
    myReaction: myReaction,
  );

  FeedItem withReaction({
    required Map<String, int> reactions,
    required String? myReaction,
  }) => FeedItem(
    id: id,
    number: number,
    name: name,
    city: city,
    tone: tone,
    likes: likes,
    liked: liked,
    frame: frame,
    avatarUrl: avatarUrl,
    photoUrl: photoUrl,
    isPremium: isPremium,
    reactions: reactions,
    myReaction: myReaction,
  );
}
