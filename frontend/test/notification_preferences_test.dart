import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/profile/models/notification_preferences.dart';

void main() {
  test('marketing content stays opt-in in the serialized contract', () {
    const preferences = NotificationPreferences(
      marketingConsent: false,
      newContent: true,
    );

    expect(preferences.toJson()['marketing_consent'], isFalse);
    expect(preferences.toJson()['new_content'], isTrue);
  });

  test('reminder and timer categories remain independent', () {
    const preferences = NotificationPreferences(
      savedRecipeReminders: true,
      cookingReminders: true,
      timerAlerts: false,
    );

    expect(preferences.toJson(), containsPair('saved_recipe_reminders', true));
    expect(preferences.toJson(), containsPair('cooking_reminders', true));
    expect(preferences.toJson(), containsPair('timer_alerts', false));
  });
}
