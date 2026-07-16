class NotificationPreferences {
  const NotificationPreferences({
    this.marketingConsent = false,
    this.newContent = false,
    this.savedRecipeReminders = false,
    this.cookingReminders = false,
    this.timerAlerts = true,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.timezone = 'Europe/Prague',
  });

  final bool marketingConsent;
  final bool newContent;
  final bool savedRecipeReminders;
  final bool cookingReminders;
  final bool timerAlerts;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final String timezone;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        marketingConsent: json['marketing_consent'] == true,
        newContent: json['new_content'] == true,
        savedRecipeReminders: json['saved_recipe_reminders'] == true,
        cookingReminders: json['cooking_reminders'] == true,
        timerAlerts: json['timer_alerts'] != false,
        quietHoursStart: json['quiet_hours_start']?.toString(),
        quietHoursEnd: json['quiet_hours_end']?.toString(),
        timezone: json['timezone']?.toString() ?? 'Europe/Prague',
      );

  NotificationPreferences copyWith({
    bool? marketingConsent,
    bool? newContent,
    bool? savedRecipeReminders,
    bool? cookingReminders,
    bool? timerAlerts,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool clearQuietHours = false,
  }) =>
      NotificationPreferences(
        marketingConsent: marketingConsent ?? this.marketingConsent,
        newContent: newContent ?? this.newContent,
        savedRecipeReminders: savedRecipeReminders ?? this.savedRecipeReminders,
        cookingReminders: cookingReminders ?? this.cookingReminders,
        timerAlerts: timerAlerts ?? this.timerAlerts,
        quietHoursStart:
            clearQuietHours ? null : (quietHoursStart ?? this.quietHoursStart),
        quietHoursEnd:
            clearQuietHours ? null : (quietHoursEnd ?? this.quietHoursEnd),
        timezone: timezone,
      );

  Map<String, dynamic> toJson() => {
        'marketing_consent': marketingConsent,
        'new_content': newContent,
        'saved_recipe_reminders': savedRecipeReminders,
        'cooking_reminders': cookingReminders,
        'timer_alerts': timerAlerts,
        'quiet_hours_start': quietHoursStart,
        'quiet_hours_end': quietHoursEnd,
        'timezone': timezone,
      };
}
