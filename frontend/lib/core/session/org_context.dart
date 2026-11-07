import 'package:flutter/foundation.dart';

import '../../features/auth/models/auth_models.dart';

enum OrgType { supplier, buyer }

/// Permission names exactly as the server returns them in GET /auth/me
/// (docs/api.md 20.12). The UI only uses them to show or hide controls; the
/// server decides on every request.
abstract final class Perm {
  static const orgRead = 'org.read';
  static const orgUpdate = 'org.update';
  static const catalogView = 'catalog.read';
  static const materialsView = 'material.read';
  static const materialsCreate = 'material.draft';
  static const materialsConfirm = 'material.confirm';
  static const materialsPublish = 'material.publish';
  static const materialsAnalyze = 'ai.analyze';
  // A20-13 / A20-12: MEMBER may plan (supplier) and request reservations (buyer).
  static const planningRun = 'planning.run';
  static const reservationCreate = 'reservation.create';
  static const reservationRead = 'reservation.read';
  static const reservationApprove = 'reservation.approve';
  static const reservationReceive = 'reservation.receive';

  /// Aliases kept for call sites that gate whole owner screens.
  static const materialsEdit = materialsView;
  static const organizationEdit = orgUpdate;
}

/// Who the user is inside their organization.
///
/// In API mode the context is built from GET /auth/me ([fromMe]) and the
/// permission list is the server's. [fromUser] is used for the demo (fixtures
/// mirroring the server's OWNER permissions) and as a display-only stand-in
/// while /auth/me is loading.
@immutable
class OrgContext {
  const OrgContext({
    required this.organizationId,
    required this.orgType,
    required this.orgRole,
    required this.permissions,
    this.specialization,
    this.membershipStatus,
    this.organizationName,
  });

  factory OrgContext.fromUser(AuthUser user, {ActivityType? activity}) {
    final supplier = user.role == UserRole.enterprise;
    return OrgContext(
      organizationId: user.organizationId,
      orgType: supplier ? OrgType.supplier : OrgType.buyer,
      orgRole: user.role.name,
      specialization: activity == ActivityType.recycler ? activity : null,
      permissions: supplier
          ? const {
              Perm.orgRead,
              Perm.orgUpdate,
              Perm.materialsView,
              Perm.materialsCreate,
              Perm.materialsConfirm,
              Perm.materialsPublish,
              Perm.materialsAnalyze,
              Perm.reservationRead,
              Perm.reservationApprove,
            }
          : const {
              Perm.orgRead,
              Perm.orgUpdate,
              Perm.catalogView,
              Perm.reservationRead,
              Perm.reservationCreate,
              Perm.reservationReceive,
            },
    );
  }

  /// Parses GET /auth/me: `organization`, `organization_kind`, `membership`
  /// and the sorted `permissions` list. A missing membership (for example a
  /// platform admin) yields no permissions.
  factory OrgContext.fromMe(Map<String, dynamic> j) {
    final org = j['organization'] is Map
        ? Map<String, dynamic>.from(j['organization'] as Map)
        : const <String, dynamic>{};
    final membership = j['membership'] is Map
        ? Map<String, dynamic>.from(j['membership'] as Map)
        : null;
    final kind = (j['organization_kind'] ?? org['kind']) as String?;
    final perms = j['permissions'];
    return OrgContext(
      organizationId: (org['id'] ??
          membership?['organization_id'] ??
          j['default_organization_id'] ??
          '') as String,
      orgType: kind == 'supplier' ? OrgType.supplier : OrgType.buyer,
      orgRole: (membership?['role'] as String?) ?? '',
      specialization:
          org['activity_type'] == 'recycler' ? ActivityType.recycler : null,
      membershipStatus: membership?['status'] as String?,
      organizationName: org['name'] as String?,
      // The server list as is; empty while the organization is under review.
      permissions: membership == null || perms is! List
          ? const {}
          : perms.whereType<String>().toSet(),
    );
  }

  final String organizationId;
  final OrgType orgType;

  /// Role in the organization as the server names it.
  final String orgRole;
  final Set<String> permissions;

  /// Membership status from /auth/me. The server sends lowercase values
  /// (`active`, `pending_review`, ...); the comparison must use the same spelling.
  final String? membershipStatus;
  final String? organizationName;

  /// `recycler` for a buyer organization that recycles; otherwise null.
  final ActivityType? specialization;

  /// The organization awaits manual review: no operations, no dashboards.
  bool get isPendingReview => membershipStatus == 'pending_review';

  bool get isSupplier => orgType == OrgType.supplier;
  bool get isRecycler => specialization == ActivityType.recycler;
  bool can(String permission) => permissions.contains(permission);

  String get roleLabel => isSupplier
      ? 'Предприятие'
      : isRecycler
          ? 'Переработчик'
          : 'Покупатель';

  /// Required permission for a location, or null when any signed-in user may
  /// open it. Public auth pages are never checked here.
  static String? permissionFor(String location) {
    if (location == '/materials/new') return Perm.materialsCreate;
    if (location == '/reservations') return Perm.reservationRead;
    final m =
        RegExp(r'^/materials/[^/]+/(edit|analysis)$').firstMatch(location);
    if (m == null) return null;
    return m.group(1) == 'edit' ? Perm.materialsEdit : Perm.materialsAnalyze;
  }

  bool canOpen(String location) {
    // Under review only the home screen (the review notice) is reachable.
    if (isPendingReview) return location == '/';
    final need = permissionFor(location);
    return need == null || can(need);
  }
}

const roleBlockedMessage = 'Этот раздел недоступен для вашей роли.';
