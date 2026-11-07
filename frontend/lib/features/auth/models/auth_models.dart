import 'package:flutter/foundation.dart';

enum UserRole {
  enterprise,
  buyer,
  admin;

  static UserRole parse(String? v) => UserRole.values.firstWhere(
        (r) => r.name == v,
        orElse: () => UserRole.buyer,
      );
}

/// Activity types as defined in docs/api.md section 2.
enum ActivityType {
  garmentFactory('garment_factory', 'Швейное предприятие'),
  workshop('workshop', 'Мастерская'),
  recycler('recycler', 'Переработчик'),
  other('other', 'Другое');

  const ActivityType(this.wire, this.label);
  final String wire;
  final String label;

  static ActivityType parse(String? v) => ActivityType.values.firstWhere(
        (a) => a.wire == v,
        orElse: () => ActivityType.other,
      );
}

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    required this.organizationId,
    required this.active,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String,
        email: j['email'] as String,
        role: UserRole.parse(j['role'] as String?),
        organizationId: j['organization_id'] as String,
        active: j['active'] as bool? ?? true,
      );

  final String id;
  final String email;
  final UserRole role;
  final String organizationId;
  final bool active;
}

@immutable
class LoginResult {
  const LoginResult({required this.accessToken, required this.user});

  factory LoginResult.fromJson(Map<String, dynamic> j) => LoginResult(
        accessToken: j['access_token'] as String,
        user: AuthUser.fromJson(Map<String, dynamic>.from(j['user'] as Map)),
      );

  final String accessToken;
  final AuthUser user;
}

@immutable
class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.password,
    required this.role,
    required this.organizationName,
    required this.city,
    required this.activityType,
  });

  final String email;
  final String password;
  final UserRole role;
  final String organizationName;
  final String city;
  final ActivityType activityType;

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'role': role.name,
        'organization': {
          'name': organizationName,
          'city': city,
          'activity_type': activityType.wire,
        },
      };
}
