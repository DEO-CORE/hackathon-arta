import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tab_shell.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/org_context.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/error_panel.dart';
import '../../../demo/demo_reset_section.dart';
import '../../auth/models/auth_models.dart';
import '../../auth/presentation/auth_validators.dart';
import '../../auth/providers/org_context_provider.dart';
import '../models/organization.dart';
import '../providers/organization_providers.dart';

/// Profile of the signed-in organization. The tab keeps the name «Организация»;
/// the page is a profile: identity, what the role can do, and two editable cards.
class OrganizationScreen extends ConsumerWidget {
  const OrganizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(organizationProvider);
    final ctx = ref.watch(currentOrgContextProvider);
    return AppTabShell(
      tab: AppTab.organization,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          title: 'Профиль',
          onBack: () => context.go('/'),
        ),
        body: Padding(
          // Keep the last control above the floating nav.
          padding:
              EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
          child: org.when(
            loading: () => const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Загрузка…'),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ErrorBanner(
                error: e is ApiException ? e : ApiException.network(),
                onRetry: () => ref.invalidate(organizationProvider),
              ),
            ),
            data: (o) => _ProfileBody(org: o, ctx: ctx),
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.org, required this.ctx});

  final Organization org;
  final OrgContext? ctx;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        // Bottom room for the floating nav so the last card can scroll clear of it.
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.contentMax),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileHero(org: org, ctx: ctx),
              const SizedBox(height: AppSpacing.lg),
              if (ctx != null) ...[
                _Capabilities(ctx: ctx!),
                const SizedBox(height: AppSpacing.lg),
              ],
              _InfoCard(
                title: 'Организация',
                rows: [
                  ('Название', org.name),
                  ('Город', org.city),
                  ('Вид деятельности', org.activityType.label),
                ],
                onEdit: () => AppBottomSheet.show<void>(
                  context,
                  title: 'Данные организации',
                  builder: (_) => _OrgEditSheet(org: org),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _InfoCard(
                title: 'Контакты',
                rows: [
                  ('Контактное лицо', _orDash(org.contacts.name)),
                  ('Телефон', _orDash(org.contacts.phone)),
                  ('Email', _orDash(org.contacts.email)),
                ],
                onEdit: () => AppBottomSheet.show<void>(
                  context,
                  title: 'Контакты',
                  builder: (_) => _ContactsEditSheet(org: org),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const DemoResetSection(),
            ],
          ),
        ),
      ),
    );
  }

  static String _orDash(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Не указано' : v;
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.org, required this.ctx});

  final Organization org;
  final OrgContext? ctx;

  @override
  Widget build(BuildContext context) {
    final kindLabel = ctx?.roleLabel ?? org.activityType.label;
    final kindIcon = (ctx?.isRecycler ?? false)
        ? Icons.recycling
        : (ctx?.isSupplier ?? false)
            ? Icons.factory_outlined
            : Icons.shopping_bag_outlined;
    final roleTitle = _roleTitle(ctx?.orgRole ?? '');
    return Semantics(
      container: true,
      label: 'Профиль организации ${org.name}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.authWash, AppColors.surface],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(child: _Monogram(name: org.name)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        org.name,
                        style: AppTypography.headlineSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              org.city,
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppStatusBadge(
                  label: kindLabel,
                  icon: kindIcon,
                  tone: AppTone.accent,
                ),
                if (roleTitle.isNotEmpty)
                  AppStatusBadge(
                    label: roleTitle,
                    icon: Icons.badge_outlined,
                    tone: AppTone.neutral,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _roleTitle(String role) => switch (role) {
        'OWNER' => 'Владелец',
        'MANAGER' => 'Менеджер',
        'MEMBER' => 'Участник',
        _ => '',
      };
}

/// Initials on an orange tile. Text stays dark on orange: white fails contrast.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.name});

  final String name;

  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return '?';
    return parts
        .map((p) => String.fromCharCodes(p.runes.take(1)).toUpperCase())
        .join();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Text(
          initials(name),
          style: AppTypography.headline.copyWith(color: AppColors.onPrimary),
        ),
      );
}

/// What the current role can do, from the server's permission list only.
class _Capabilities extends StatelessWidget {
  const _Capabilities({required this.ctx});

  final OrgContext ctx;

  static const _supplier = [
    (
      Perm.materialsCreate,
      'Партии: черновики, фото и публикация',
      Icons.inventory_2_outlined
    ),
    (
      Perm.planningRun,
      'Подбор покупателей и план распределения',
      Icons.auto_graph_outlined
    ),
    (
      Perm.reservationApprove,
      'Заявки, резерв и передача',
      Icons.handshake_outlined
    ),
    ('analytics.read', 'Аналитика по своим партиям', Icons.insights_outlined),
  ];

  static const _buyer = [
    (
      Perm.catalogView,
      'Каталог опубликованных партий',
      Icons.storefront_outlined
    ),
    (Perm.reservationCreate, 'Запросы на резерв', Icons.bookmark_add_outlined),
    (
      Perm.reservationReceive,
      'Подтверждение получения',
      Icons.task_alt_outlined
    ),
    ('requirement.write', 'Потребности и бюджеты', Icons.tune_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final items = ctx.isSupplier ? _supplier : _buyer;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Возможности роли', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          for (final (perm, label, icon) in items)
            _CapabilityRow(
              label: label,
              icon: icon,
              granted: ctx.can(perm),
            ),
        ],
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({
    required this.label,
    required this.icon,
    required this.granted,
  });

  final String label;
  final IconData icon;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final state = granted ? 'доступно' : 'недоступно в вашей роли';
    return Semantics(
      container: true,
      label: '$label: $state',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: granted
                    ? AppColors.primaryContainer
                    : AppColors.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon,
                  size: 20,
                  color: granted ? AppColors.text : AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: granted ? AppColors.text : AppColors.textSecondary,
                ),
              ),
            ),
            Icon(
              granted ? Icons.check_circle : Icons.lock_outline,
              size: 20,
              color: granted ? AppColors.success : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.rows,
    required this.onEdit,
  });

  final String title;
  final List<(String, String)> rows;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: AppTypography.title)),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text('Изменить'),
                ),
              ],
            ),
            for (final (label, value) in rows)
              AppKeyValueRow(label: label, value: value),
          ],
        ),
      );
}

class _OrgEditSheet extends ConsumerStatefulWidget {
  const _OrgEditSheet({required this.org});

  final Organization org;

  @override
  ConsumerState<_OrgEditSheet> createState() => _OrgEditSheetState();
}

class _OrgEditSheetState extends ConsumerState<_OrgEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.org.name);
  late final _city = TextEditingController(text: widget.org.city);
  late ActivityType _activity = widget.org.activityType;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  void _save() {
    if (ref.read(organizationSaveProvider).saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(organizationSaveProvider.notifier).save(
          OrganizationPatch(
            name: _name.text.trim(),
            city: _city.text.trim(),
            activityType: _activity,
            // contacts is replaced as a whole by PATCH: keep the current ones.
            contacts: widget.org.contacts,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(organizationSaveProvider);
    ref.listen(organizationSaveProvider, (prev, next) {
      if (next.saved != null && prev?.saved != next.saved && context.mounted) {
        Navigator.of(context).maybePop();
      }
    });
    return _SheetForm(
      formKey: _formKey,
      save: save,
      busy: save.saving,
      onSubmit: _save,
      fields: [
        TextFormField(
          controller: _name,
          enabled: !save.saving,
          decoration: InputDecoration(
            labelText: 'Название',
            errorText: save.error?.fieldErrors['name'],
          ),
          validator: (v) => validateRequired(v,
              emptyMessage: 'Укажите название организации.'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _city,
          enabled: !save.saving,
          decoration: InputDecoration(
            labelText: 'Город',
            errorText: save.error?.fieldErrors['city'],
          ),
          validator: (v) =>
              validateRequired(v, max: 100, emptyMessage: 'Укажите город.'),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<ActivityType>(
          initialValue: _activity,
          decoration: const InputDecoration(labelText: 'Вид деятельности'),
          items: [
            for (final a in ActivityType.values)
              DropdownMenuItem(value: a, child: Text(a.label)),
          ],
          onChanged: save.saving
              ? null
              : (v) => setState(() => _activity = v ?? _activity),
        ),
      ],
    );
  }
}

class _ContactsEditSheet extends ConsumerStatefulWidget {
  const _ContactsEditSheet({required this.org});

  final Organization org;

  @override
  ConsumerState<_ContactsEditSheet> createState() => _ContactsEditSheetState();
}

class _ContactsEditSheetState extends ConsumerState<_ContactsEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _contactName =
      TextEditingController(text: widget.org.contacts.name ?? '');
  late final _phone =
      TextEditingController(text: widget.org.contacts.phone ?? '');
  late final _email =
      TextEditingController(text: widget.org.contacts.email ?? '');

  @override
  void dispose() {
    _contactName.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

  void _save() {
    if (ref.read(organizationSaveProvider).saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(organizationSaveProvider.notifier).save(
          OrganizationPatch(
            name: widget.org.name,
            city: widget.org.city,
            activityType: widget.org.activityType,
            contacts: Contacts(
              name: _nullIfEmpty(_contactName.text),
              phone: _nullIfEmpty(_phone.text),
              email: _nullIfEmpty(_email.text),
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(organizationSaveProvider);
    ref.listen(organizationSaveProvider, (prev, next) {
      if (next.saved != null && prev?.saved != next.saved && context.mounted) {
        Navigator.of(context).maybePop();
      }
    });
    return _SheetForm(
      formKey: _formKey,
      save: save,
      busy: save.saving,
      onSubmit: _save,
      fields: [
        TextFormField(
          controller: _contactName,
          enabled: !save.saving,
          decoration: const InputDecoration(labelText: 'Контактное лицо'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _phone,
          enabled: !save.saving,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Телефон'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _email,
          enabled: !save.saving,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Контактный email'),
        ),
      ],
    );
  }
}

/// Common frame for the edit sheets: inline error, saving state, one submit.
class _SheetForm extends StatelessWidget {
  const _SheetForm({
    required this.formKey,
    required this.save,
    required this.busy,
    required this.onSubmit,
    required this.fields,
  });

  final GlobalKey<FormState> formKey;
  final OrganizationSaveState save;
  final bool busy;
  final VoidCallback onSubmit;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) => Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (save.error != null) ...[
              ErrorBanner(error: save.error!),
              const SizedBox(height: AppSpacing.md),
            ],
            ...fields,
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: busy ? null : onSubmit,
              child: Text(busy ? 'Сохранение…' : 'Сохранить'),
            ),
          ],
        ),
      );
}
