import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tab_shell.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/error_panel.dart';
import '../../../demo/demo_reset_section.dart';
import '../../auth/models/auth_models.dart';
import '../../auth/presentation/auth_validators.dart';
import '../models/organization.dart';
import '../providers/organization_providers.dart';

class OrganizationScreen extends ConsumerWidget {
  const OrganizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(organizationProvider);
    return AppTabShell(
      tab: AppTab.organization,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          title: 'Организация',
          onBack: () => context.go('/'),
        ),
        body: Builder(builder: (context) => _body(context, ref, org)),
      ),
    );
  }

  Widget _body(
      BuildContext context, WidgetRef ref, AsyncValue<Organization> org) {
    return Padding(
      // Keep the last control above the floating nav.
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: org.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Загрузка…'),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(
            error: e is ApiException ? e : ApiException.network(),
            onRetry: () => ref.invalidate(organizationProvider),
          ),
        ),
        data: (o) => _OrganizationForm(org: o),
      ),
    );
  }
}

class _OrganizationForm extends ConsumerStatefulWidget {
  const _OrganizationForm({required this.org});
  final Organization org;

  @override
  ConsumerState<_OrganizationForm> createState() => _OrganizationFormState();
}

class _OrganizationFormState extends ConsumerState<_OrganizationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.org.name);
  late final _city = TextEditingController(text: widget.org.city);
  late final _contactName =
      TextEditingController(text: widget.org.contacts.name ?? '');
  late final _phone =
      TextEditingController(text: widget.org.contacts.phone ?? '');
  late final _email =
      TextEditingController(text: widget.org.contacts.email ?? '');
  late ActivityType _activity = widget.org.activityType;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
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
            name: _name.text.trim(),
            city: _city.text.trim(),
            activityType: _activity,
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
    final busy = save.saving;
    final fe = save.error?.fieldErrors ?? const <String, String>{};
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (save.error != null) ...[
                  ErrorBanner(error: save.error!),
                  const SizedBox(height: 12),
                ],
                if (save.saved != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text('Сохранено.'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _name,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: 'Название',
                    errorText: fe['name'],
                  ),
                  validator: (v) => validateRequired(v,
                      emptyMessage: 'Укажите название организации.'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _city,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: 'Город',
                    errorText: fe['city'],
                  ),
                  validator: (v) => validateRequired(v,
                      max: 100, emptyMessage: 'Укажите город.'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ActivityType>(
                  initialValue: _activity,
                  decoration:
                      const InputDecoration(labelText: 'Вид деятельности'),
                  items: [
                    for (final a in ActivityType.values)
                      DropdownMenuItem(value: a, child: Text(a.label)),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() => _activity = v ?? _activity),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactName,
                  enabled: !busy,
                  decoration:
                      const InputDecoration(labelText: 'Контактное лицо'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  enabled: !busy,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Телефон'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: 'Контактный email'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : _save,
                  child: Text(busy ? 'Сохранение…' : 'Сохранить'),
                ),
                const DemoResetSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
