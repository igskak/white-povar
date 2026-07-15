import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/profile/models/preference_profile.dart';

void main() {
  test('preference profile parses the server contract and preserves consent',
      () {
    final profile = PreferenceProfile.fromJson(const {
      'diets': ['vegan'],
      'allergens': ['горіхи'],
      'dislikes': ['кінза'],
      'preferred_max_total_time': 30,
      'equipment': ['духовка'],
      'household_size': 2,
      'personalization_consent': true,
    });

    expect(profile.allergens, ['горіхи']);
    expect(profile.preferredMaxTotalTime, 30);
    expect(profile.householdSize, 2);
    expect(profile.toJson()['personalization_consent'], isTrue);
  });
}
