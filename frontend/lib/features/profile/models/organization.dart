import 'package:flutter/foundation.dart';

import '../../auth/models/auth_models.dart';

@immutable
class Contacts {
  const Contacts({this.name, this.phone, this.email});

  factory Contacts.fromJson(Map<String, dynamic>? j) => Contacts(
        name: j?['contact_name'] as String?,
        phone: j?['contact_phone'] as String?,
        email: j?['contact_email'] as String?,
      );

  final String? name;
  final String? phone;
  final String? email;

  Map<String, dynamic> toJson() => {
        'contact_name': name,
        'contact_phone': phone,
        'contact_email': email,
      };
}

@immutable
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.city,
    required this.activityType,
    required this.contacts,
  });

  factory Organization.fromJson(Map<String, dynamic> j) => Organization(
        id: j['id'] as String,
        name: j['name'] as String,
        city: j['city'] as String,
        activityType: ActivityType.parse(j['activity_type'] as String?),
        contacts: Contacts.fromJson(
          j['contacts'] is Map
              ? Map<String, dynamic>.from(j['contacts'] as Map)
              : null,
        ),
      );

  final String id;
  final String name;
  final String city;
  final ActivityType activityType;
  final Contacts contacts;

  Organization copyWith({
    String? name,
    String? city,
    ActivityType? activityType,
    Contacts? contacts,
  }) =>
      Organization(
        id: id,
        name: name ?? this.name,
        city: city ?? this.city,
        activityType: activityType ?? this.activityType,
        contacts: contacts ?? this.contacts,
      );
}

/// Body of PATCH /organizations/me. `contacts` replaces the object entirely.
@immutable
class OrganizationPatch {
  const OrganizationPatch({
    this.name,
    this.city,
    this.activityType,
    this.contacts,
  });

  final String? name;
  final String? city;
  final ActivityType? activityType;
  final Contacts? contacts;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (city != null) 'city': city,
        if (activityType != null) 'activity_type': activityType!.wire,
        if (contacts != null) 'contacts': contacts!.toJson(),
      };
}
