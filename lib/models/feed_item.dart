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
    this.postedAt,
    this.invalidated = false,
    this.myRedCard = false,
    this.isMine = false,
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
  final DateTime? postedAt;
  final bool invalidated;
  final bool myRedCard;
  final bool isMine;

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
    postedAt: j['posted_at'] == null ? null : DateTime.parse(j['posted_at'] as String),
    invalidated: j['invalidated'] as bool? ?? false,
    myRedCard: j['my_red_card'] as bool? ?? false,
    isMine: j['is_mine'] as bool? ?? false,
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
    postedAt: postedAt,
    invalidated: invalidated,
    myRedCard: myRedCard,
    isMine: isMine,
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
    postedAt: postedAt,
    invalidated: invalidated,
    myRedCard: myRedCard,
    isMine: isMine,
  );

  FeedItem withRedCard({
    required bool myRedCard,
    required bool invalidated,
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
    postedAt: postedAt,
    invalidated: invalidated,
    myRedCard: myRedCard,
    isMine: isMine,
  );
}
