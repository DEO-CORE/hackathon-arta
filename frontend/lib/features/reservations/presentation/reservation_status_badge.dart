import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../models/reservation_models.dart';

/// Label, icon and tone carry the meaning together; colour is secondary.
class ReservationStatusBadge extends StatelessWidget {
  const ReservationStatusBadge({super.key, required this.status});
  final ReservationStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, tone, outlined) = switch (status) {
      ReservationStatus.pending => (
          Icons.hourglass_empty,
          AppTone.warning,
          false
        ),
      ReservationStatus.confirmed => (Icons.lock, AppTone.accent, true),
      ReservationStatus.transferred => (
          Icons.local_shipping,
          AppTone.accent,
          false
        ),
      ReservationStatus.completed => (
          Icons.check_circle,
          AppTone.success,
          false
        ),
      ReservationStatus.cancelled => (Icons.cancel, AppTone.neutral, true),
      ReservationStatus.unknown => (Icons.help_outline, AppTone.neutral, false),
    };
    return AppStatusBadge(
      label: status.label,
      icon: icon,
      tone: tone,
      outlined: outlined,
      semanticsLabel: 'Статус заявки: ${status.label}',
    );
  }
}
