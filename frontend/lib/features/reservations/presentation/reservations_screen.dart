import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tab_shell.dart';
import '../../../core/format/mass_format.dart';
import '../../../core/session/org_context.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/error_panel.dart';
import '../../auth/providers/org_context_provider.dart';
import '../models/reservation_models.dart';
import '../providers/reservation_providers.dart';
import 'reservation_dialogs.dart';
import 'reservation_status_badge.dart';

/// Supplier: incoming requests and history ("Сделки"). Buyer and recycler:
/// own requests ("Заявки"). The server returns only the caller's side.
class ReservationsScreen extends ConsumerStatefulWidget {
  const ReservationsScreen({super.key});

  @override
  ConsumerState<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen> {
  ReservationSegment _segment = ReservationSegment.active;

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(currentOrgContextProvider);
    final supplier = org?.isSupplier ?? false;
    final action = ref.watch(reservationActionProvider);
    final list = ref.watch(reservationListProvider(_segment));
    final ctrl = ref.read(reservationListProvider(_segment).notifier);

    Widget segmentButton(ReservationSegment s, String label) => ChoiceChip(
          label: Text(label),
          selected: _segment == s,
          showCheckmark: true,
          onSelected: (_) => setState(() => _segment = s),
        );

    Widget body;
    if (list.loading) {
      body = const SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: AppSkeletonList(),
      );
    } else if (list.error != null) {
      body = Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ErrorBanner(error: list.error!, onRetry: ctrl.reload),
      );
    } else if (list.items.isEmpty) {
      body = _Empty(
          supplier: supplier, history: _segment == ReservationSegment.history);
    } else {
      body = RefreshIndicator(
        onRefresh: ctrl.reload,
        child: ListView(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs,
              AppSpacing.lg, MediaQuery.paddingOf(context).bottom + 96),
          children: [
            AppContentColumn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (action.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: ErrorBanner(
                          error: action.error!, onRetry: ctrl.reload),
                    ),
                  for (final r in list.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child:
                          ReservationCard(reservation: r, supplier: supplier),
                    ),
                  if (list.loadMoreError != null)
                    ErrorBanner(error: list.loadMoreError!),
                  if (list.hasMore)
                    AppButton(
                      kind: AppButtonKind.secondary,
                      label: list.loadingMore ? 'Загрузка…' : 'Показать ещё',
                      onPressed: list.loadingMore ? null : ctrl.loadMore,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppTabShell(
      tab: AppTab.reservations,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          title: supplier ? 'Сделки' : 'Заявки',
          onBack: tabBack(context),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: AppContentColumn(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      segmentButton(ReservationSegment.active,
                          supplier ? 'Заявки' : 'Активные'),
                      segmentButton(ReservationSegment.history, 'История'),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.supplier, required this.history});
  final bool supplier;
  final bool history;

  @override
  Widget build(BuildContext context) {
    if (history) {
      return const AppEmptyState(
        title: 'Завершённых сделок пока нет.',
        icon: Icons.history,
      );
    }
    return supplier
        ? AppEmptyState(
            title: 'Пока нет входящих заявок.',
            message:
                'Заявки появятся, когда покупатели запросят ваши опубликованные партии.',
            actionLabel: 'Открыть партии',
            onAction: () => context.go('/materials'),
          )
        : AppEmptyState(
            title: 'У вас пока нет активных заявок.',
            message: 'Выберите партию в каталоге и запросите резерв.',
            actionLabel: 'Открыть каталог',
            onAction: () => context.go('/materials'),
          );
  }
}

String _date(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

const _contactLabels = {
  'phone': 'Телефон',
  'email': 'Email',
  'address': 'Адрес',
};

class ReservationCard extends ConsumerWidget {
  const ReservationCard(
      {super.key, required this.reservation, required this.supplier});
  final Reservation reservation;
  final bool supplier;

  String get _quantityLine {
    final r = reservation;
    return switch (r.status) {
      ReservationStatus.confirmed => 'Удержано: ${formatKg(r.quantityKg)}',
      ReservationStatus.transferred ||
      ReservationStatus.completed =>
        'Передано: ${formatKg(r.transaction?.transferredKg ?? r.quantityKg)}',
      ReservationStatus.pending => 'Запрошено: ${formatKg(r.quantityKg)}',
      _ => 'Количество: ${formatKg(r.quantityKg)}',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reservation;
    final busy = ref.watch(reservationActionProvider).busy;
    final can = ref.watch(currentOrgContextProvider)?.can ?? (_) => false;
    final counterparty = supplier ? r.buyerName : r.sellerName;
    // Contacts only from confirmed on; the server decides what it returns.
    final showContacts = r.status == ReservationStatus.confirmed ||
        r.status == ReservationStatus.transferred ||
        r.status == ReservationStatus.completed;
    final contacts = !showContacts
        ? const <MapEntry<String, String>>[]
        : [
            for (final e in (r.contacts ?? const <String, String>{}).entries)
              if (_contactLabels.containsKey(e.key) && e.value.isNotEmpty) e
          ];
    final price = r.agreedPricePerKg == null
        ? 'Цена не указана'
        : 'Цена: ${formatDecimal(r.agreedPricePerKg!)} KGS/кг';

    final actions = <Widget>[];
    if (supplier && can(Perm.reservationApprove)) {
      if (r.status == ReservationStatus.pending) {
        actions.addAll([
          AppButton(
              label: 'Подтвердить резерв',
              onPressed:
                  busy ? null : () => confirmReservation(context, ref, r)),
          AppButton(
              label: 'Отклонить',
              kind: AppButtonKind.text,
              onPressed:
                  busy ? null : () => rejectReservation(context, ref, r)),
        ]);
      } else if (r.status == ReservationStatus.confirmed) {
        actions.add(AppButton(
            label: 'Отметить передачу',
            onPressed:
                busy ? null : () => transferReservation(context, ref, r)));
      }
    } else if (!supplier) {
      if (r.status == ReservationStatus.transferred &&
          can(Perm.reservationReceive)) {
        actions.add(AppButton(
            label: 'Подтвердить получение',
            onPressed:
                busy ? null : () => completeReservation(context, ref, r)));
      }
      if ((r.status == ReservationStatus.pending ||
              r.status == ReservationStatus.confirmed) &&
          can(Perm.reservationCreate)) {
        actions.add(AppButton(
            label: 'Отменить заявку',
            kind: AppButtonKind.text,
            onPressed: busy ? null : () => cancelReservation(context, ref, r)));
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.materialName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.title),
          const SizedBox(height: AppSpacing.xs),
          Align(
              alignment: Alignment.centerLeft,
              child: ReservationStatusBadge(status: r.status)),
          const SizedBox(height: AppSpacing.sm),
          Text(_quantityLine, style: AppTypography.body),
          Text(
            [
              supplier
                  ? 'Покупатель: ${counterparty ?? 'организация не указана'}'
                  : 'Продавец: ${counterparty ?? 'продавец'}',
              price,
              if (r.createdAt != null) 'Заявка от ${_date(r.createdAt!)}',
            ].join('\n'),
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          if (r.status == ReservationStatus.transferred && !supplier)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Text('Подтвердите получение.'),
            ),
          if (r.status == ReservationStatus.transferred && supplier)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Text('Ждём подтверждения получения покупателем.'),
            ),
          if (r.status == ReservationStatus.completed &&
              r.transaction?.saleAmountKgs != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                  'Сумма сделки (не оплата): ${formatDecimal(r.transaction!.saleAmountKgs!)} KGS'),
            ),
          if (r.status == ReservationStatus.cancelled &&
              (r.cancelReason ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text('Причина: ${r.cancelReason}'),
            ),
          for (final c in contacts)
            Text('${_contactLabels[c.key]}: ${c.value}'),
          if (showContacts && contacts.isEmpty && !supplier)
            const SizedBox.shrink()
          else if (!showContacts && r.status == ReservationStatus.pending)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child:
                  Text('Контакты будут доступны после подтверждения резерва.'),
            ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final a in actions) ...[
              a,
              const SizedBox(height: AppSpacing.sm)
            ],
          ],
        ],
      ),
    );
  }
}
