class Session {
  const Session({
    required this.deviceToken,
    required this.pseudo,
    required this.city,
  });
  final String deviceToken;
  final String pseudo;
  final String city;

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    deviceToken: j['device_token'] as String,
    pseudo: j['pseudo'] as String,
    city: j['city'] as String,
  );
}
