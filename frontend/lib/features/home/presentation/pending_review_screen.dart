import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/org_context.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';

const pendingReviewMessage =
    'Организация на проверке. Доступ к операциям откроется после проверки.';

/// Shown instead of the home screen while membership.status is PENDING_REVIEW.
/// It offers no operations and no role dashboards; signing out stays available
/// (it ends the local session only).
class PendingReviewScreen extends ConsumerWidget {
  const PendingReviewScreen({super.key, required this.context});

  final OrgContext context;

  @override
  Widget build(BuildContext buildContext, WidgetRef ref) {
    final name = context.organizationName;
    return AppAuthBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: AppBottomBar(
          child: AppButton(
            label: 'Выйти',
            kind: AppButtonKind.secondary,
            icon: Icons.logout,
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: AppContentColumn(
              maxWidth: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppBrandBlock(centered: true, tagline: false),
                  const SizedBox(height: AppSpacing.xxl),
                  const ExcludeSemantics(
                    child: Center(
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.warningBg,
                        child: Icon(Icons.hourglass_top,
                            size: 32, color: AppColors.warning),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (name != null && name.isNotEmpty)
                    Text(name,
                        textAlign: TextAlign.center,
                        style: AppTypography.headline),
                  const SizedBox(height: AppSpacing.sm),
                  Semantics(
                    liveRegion: true,
                    child: Text(pendingReviewMessage,
                        textAlign: TextAlign.center,
                        style: AppTypography.body
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
