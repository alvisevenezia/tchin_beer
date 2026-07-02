class Profile {
  const Profile({
    required this.pseudo,
    required this.city,
    required this.myCount,
    required this.streak,
    required this.isPremium,
    this.frame,
    this.avatarUrl,
    this.purchasedFrames = const [],
    this.availableReactions = const [],
  });
  final String pseudo;
  final String city;
  final int myCount;
  final int streak;
  final bool isPremium;
  final String? frame;
  final String? avatarUrl;
  final List<String> purchasedFrames;
  final List<String> availableReactions;

  bool ownsFrame(String frameId) =>
      isPremium || purchasedFrames.contains(frameId);

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    pseudo: j['pseudo'] as String,
    city: j['city'] as String,
    myCount: j['myCount'] as int,
    streak: j['streak'] as int,
    isPremium: j['isPremium'] as bool? ?? false,
    frame: j['frame'] as String?,
    avatarUrl: j['avatarUrl'] as String?,
    purchasedFrames: (j['purchasedFrames'] as List<dynamic>?)
            ?.cast<String>() ??
        const [],
    availableReactions: (j['availableReactions'] as List<dynamic>?)
            ?.cast<String>() ??
        const [],
  );

  Profile copyWithPurchasedFrames(List<String> frames) => Profile(
    pseudo: pseudo,
    city: city,
    myCount: myCount,
    streak: streak,
    isPremium: isPremium,
    frame: frame,
    avatarUrl: avatarUrl,
    purchasedFrames: frames,
    availableReactions: availableReactions,
  );
}

class PremiumStats {
  const PremiumStats({
    required this.globalRank,
    required this.weekChange,
    required this.bestDay,
    required this.likesReceived,
  });
  final int globalRank;
  final int weekChange;
  final int bestDay;
  final int likesReceived;

  factory PremiumStats.fromJson(Map<String, dynamic> j) => PremiumStats(
    globalRank: j['globalRank'] as int,
    weekChange: j['weekChange'] as int,
    bestDay: j['bestDay'] as int,
    likesReceived: j['likesReceived'] as int,
  );
}
