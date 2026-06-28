class Profile {
  const Profile({
    required this.pseudo,
    required this.city,
    required this.myCount,
    required this.streak,
  });
  final String pseudo;
  final String city;
  final int myCount;
  final int streak;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    pseudo: j['pseudo'] as String,
    city: j['city'] as String,
    myCount: j['myCount'] as int,
    streak: j['streak'] as int,
  );
}
