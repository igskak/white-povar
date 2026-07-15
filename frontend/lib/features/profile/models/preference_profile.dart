class PreferenceProfile {
  const PreferenceProfile({
    this.diets = const [],
    this.allergens = const [],
    this.dislikes = const [],
    this.preferredMaxTotalTime,
    this.equipment = const [],
    this.householdSize,
    required this.personalizationConsent,
  });

  final List<String> diets;
  final List<String> allergens;
  final List<String> dislikes;
  final int? preferredMaxTotalTime;
  final List<String> equipment;
  final int? householdSize;
  final bool personalizationConsent;

  factory PreferenceProfile.fromJson(Map<String, dynamic> json) =>
      PreferenceProfile(
        diets: _strings(json['diets']),
        allergens: _strings(json['allergens']),
        dislikes: _strings(json['dislikes']),
        preferredMaxTotalTime: _number(json['preferred_max_total_time']),
        equipment: _strings(json['equipment']),
        householdSize: _number(json['household_size']),
        personalizationConsent: json['personalization_consent'] == true,
      );

  Map<String, dynamic> toJson() => {
        'diets': diets,
        'allergens': allergens,
        'dislikes': dislikes,
        'preferred_max_total_time': preferredMaxTotalTime,
        'equipment': equipment,
        'household_size': householdSize,
        'personalization_consent': personalizationConsent,
      };

  static List<String> _strings(dynamic value) =>
      value is List ? value.map((item) => item.toString()).toList() : const [];
  static int? _number(dynamic value) =>
      value is int ? value : int.tryParse('$value');
}
