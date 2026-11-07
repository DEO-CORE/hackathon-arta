import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../demo/demo_auth_repository.dart';
import '../data/organization_repository.dart';
import '../models/organization.dart';

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  if (ref.watch(appConfigProvider).useDemoData) {
    return DemoOrganizationRepository();
  }
  return ApiOrganizationRepository(ref.watch(apiClientProvider));
});

final organizationProvider =
    FutureProvider.autoDispose<Organization>((ref) async {
  return ref.watch(organizationRepositoryProvider).getMe();
});

class OrganizationSaveState {
  const OrganizationSaveState({this.saving = false, this.error, this.saved});
  final bool saving;
  final ApiException? error;
  final Organization? saved;
}

class OrganizationSaveController
    extends AutoDisposeNotifier<OrganizationSaveState> {
  @override
  OrganizationSaveState build() => const OrganizationSaveState();

  Future<void> save(OrganizationPatch patch) async {
    if (state.saving) return;
    state = const OrganizationSaveState(saving: true);
    try {
      final org = await ref.read(organizationRepositoryProvider).patchMe(patch);
      state = OrganizationSaveState(saved: org);
      ref.invalidate(organizationProvider);
    } on ApiException catch (e) {
      state = OrganizationSaveState(error: e);
    } catch (_) {
      state = OrganizationSaveState(error: ApiException.network());
    }
  }
}

final organizationSaveProvider = AutoDisposeNotifierProvider<
    OrganizationSaveController, OrganizationSaveState>(
  OrganizationSaveController.new,
);
