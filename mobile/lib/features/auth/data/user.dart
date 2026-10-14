import '../../../core/utils/units.dart';

enum Sex {
  male,
  female;

  static Sex? fromApi(String? v) => switch (v) {
    'male' => Sex.male,
    'female' => Sex.female,
    _ => null,
  };

  String get label => this == Sex.male ? 'Male' : 'Female';
}

enum ActivityLevel {
  sedentary('Sedentary', 'Desk job, little exercise'),
  light('Light', 'Training 1–3 days a week'),
  moderate('Moderate', 'Training 3–5 days a week'),
  active('Active', 'Hard training 6–7 days a week'),
  veryActive('Very active', 'Physical job plus training');

  const ActivityLevel(this.label, this.description);
  final String label;
  final String description;

  String get apiValue => this == veryActive ? 'very_active' : name;

  static ActivityLevel fromApi(String? v) =>
      v == 'very_active' ? veryActive : values.firstWhere((e) => e.name == v, orElse: () => moderate);
}

enum Goal {
  cut('Lose fat', 'Calorie deficit, keep strength'),
  maintain('Maintain', 'Stay lean, get stronger'),
  bulk('Build muscle', 'Calorie surplus, maximise gains');

  const Goal(this.label, this.description);
  final String label;
  final String description;

  static Goal fromApi(String? v) => values.firstWhere((e) => e.name == v, orElse: () => maintain);
}

/// The signed-in user's profile (mirrors `GET /users/me`).
class User {
  const User({
    required this.id,
    required this.email,
    required this.username,
    this.avatarUrl,
    this.sex,
    this.birthDate,
    this.heightCm,
    this.bodyweightKg,
    this.unit = WeightUnit.kg,
    this.activityLevel = ActivityLevel.moderate,
    this.goal = Goal.maintain,
    this.restTimerDefaultSec = 90,
    this.onboardingComplete = false,
    this.calorieTargetKcal,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] as String,
    email: j['email'] as String,
    username: j['username'] as String,
    avatarUrl: j['avatarUrl'] as String?,
    sex: Sex.fromApi(j['sex'] as String?),
    birthDate: j['birthDate'] == null ? null : DateTime.parse(j['birthDate'] as String),
    heightCm: (j['heightCm'] as num?)?.toDouble(),
    bodyweightKg: (j['bodyweightKg'] as num?)?.toDouble(),
    unit: WeightUnit.fromApi(j['unit'] as String?),
    activityLevel: ActivityLevel.fromApi(j['activityLevel'] as String?),
    goal: Goal.fromApi(j['goal'] as String?),
    restTimerDefaultSec: (j['restTimerDefaultSec'] as num?)?.toInt() ?? 90,
    onboardingComplete: j['onboardingComplete'] as bool? ?? false,
    calorieTargetKcal: (j['calorieTargetKcal'] as num?)?.toInt(),
    createdAt: j['createdAt'] == null ? null : DateTime.parse(j['createdAt'] as String),
  );

  final String id;
  final String email;
  final String username;
  final String? avatarUrl;
  final Sex? sex;
  final DateTime? birthDate;
  final double? heightCm;
  final double? bodyweightKg;
  final WeightUnit unit;
  final ActivityLevel activityLevel;
  final Goal goal;
  final int restTimerDefaultSec;
  final bool onboardingComplete;
  final int? calorieTargetKcal;
  final DateTime? createdAt;

  /// First letter(s) for avatar fallbacks.
  String get initials => username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'avatarUrl': avatarUrl,
    'sex': sex?.name,
    'birthDate': birthDate?.toIso8601String(),
    'heightCm': heightCm,
    'bodyweightKg': bodyweightKg,
    'unit': unit.apiValue,
    'activityLevel': activityLevel.apiValue,
    'goal': goal.name,
    'restTimerDefaultSec': restTimerDefaultSec,
    'onboardingComplete': onboardingComplete,
    'calorieTargetKcal': calorieTargetKcal,
    'createdAt': createdAt?.toIso8601String(),
  };
}

/// Fields the profile endpoints accept; nulls are omitted from the request.
class ProfileUpdate {
  const ProfileUpdate({
    this.username,
    this.sex,
    this.birthDate,
    this.heightCm,
    this.bodyweightKg,
    this.unit,
    this.activityLevel,
    this.goal,
    this.restTimerDefaultSec,
    this.onboardingComplete,
  });

  final String? username;
  final Sex? sex;
  final DateTime? birthDate;
  final double? heightCm;
  final double? bodyweightKg;
  final WeightUnit? unit;
  final ActivityLevel? activityLevel;
  final Goal? goal;
  final int? restTimerDefaultSec;
  final bool? onboardingComplete;

  Map<String, dynamic> toJson() => {
    'username': ?username,
    'sex': ?sex?.name,
    if (birthDate != null) 'birthDate': '${birthDate!.year.toString().padLeft(4, '0')}-'
        '${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
    'heightCm': ?heightCm,
    'bodyweightKg': ?bodyweightKg,
    'unit': ?unit?.apiValue,
    'activityLevel': ?activityLevel?.apiValue,
    'goal': ?goal?.name,
    'restTimerDefaultSec': ?restTimerDefaultSec,
    'onboardingComplete': ?onboardingComplete,
  };
}
