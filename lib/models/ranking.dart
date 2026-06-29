class CityRank {
  const CityRank({
    required this.key,
    required this.name,
    required this.count,
    required this.rank,
  });
  final String key;
  final String name;
  final int count;
  final int rank;

  factory CityRank.fromJson(Map<String, dynamic> j) => CityRank(
    key: j['key'] as String,
    name: j['name'] as String,
    count: j['count'] as int,
    rank: j['rank'] as int,
  );
}

class Rankings {
  const Rankings({required this.period, required this.cities, this.me});
  final String period;
  final List<CityRank> cities;
  final CityRank? me;

  factory Rankings.fromJson(Map<String, dynamic> j) => Rankings(
    period: j['period'] as String,
    cities: (j['cities'] as List)
        .map((e) => CityRank.fromJson(e as Map<String, dynamic>))
        .toList(),
    me: j['me'] == null
        ? null
        : CityRank.fromJson(j['me'] as Map<String, dynamic>),
  );
}
