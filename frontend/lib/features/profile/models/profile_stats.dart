/// The three totals the profile header shows.
///
/// They are counted by the API inside the resolved tenant, so `saved` always
/// matches the number of recipes the Saved page can list.
class ProfileStats {
  const ProfileStats({
    required this.saved,
    required this.cooked,
    required this.scans,
  });

  final int saved;
  final int cooked;
  final int scans;

  factory ProfileStats.fromJson(Map<String, dynamic> json) => ProfileStats(
        saved: _count(json['saved']),
        cooked: _count(json['cooked']),
        scans: _count(json['scans']),
      );

  static int _count(dynamic value) =>
      value is num && value >= 0 ? value.toInt() : 0;

  @override
  bool operator ==(Object other) =>
      other is ProfileStats &&
      other.saved == saved &&
      other.cooked == cooked &&
      other.scans == scans;

  @override
  int get hashCode => Object.hash(saved, cooked, scans);
}
