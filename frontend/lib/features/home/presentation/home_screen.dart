import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tab_shell.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';
import '../../auth/models/auth_models.dart';

/// Landing screen: greeting, the role's main action, section link cards.
/// No metrics: the API has no analytics endpoint in this phase.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    final isEnterprise = user?.role == UserRole.enterprise;
    final roleLabel = isEnterprise ? 'Предприятие' : 'Покупатель';
    return AppTabShell(
      tab: AppTab.home,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          showBack: false,
          trailing: AppIconTile(
            icon: Icons.logout,
            tooltip: 'Выйти',
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ),
        // Read the padding below the shell: it includes the floating nav.
        body: Builder(
          builder: (context) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                MediaQuery.paddingOf(context).bottom + AppSpacing.lg),
            child: AppContentColumn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Здравствуйте,',
                      style: AppTypography.display
                          .copyWith(color: AppColors.textSecondary)),
                  Text(user?.email ?? '',
                      style: AppTypography.display
                          .copyWith(fontSize: 28, height: 36 / 28)),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppStatusBadge(
                      label: 'Роль: $roleLabel',
                      icon: Icons.business,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (isEnterprise)
                    AppButton(
                      label: 'Создать партию',
                      icon: Icons.add,
                      onPressed: () => context.push('/materials/new'),
                    )
                  else
                    AppButton(
                      label: 'Открыть каталог',
                      onPressed: () => context.push('/materials'),
                    ),
                  const AppSectionHeader(title: 'Разделы'),
                  AppLinkCard(
                    icon: Icons.inventory_2,
                    title: isEnterprise ? 'Партии' : 'Каталог партий',
                    subtitle: isEnterprise
                        ? 'Ваши партии, фото и статусы'
                        : 'Опубликованные партии',
                    onTap: () => context.push('/materials'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppLinkCard(
                    icon: Icons.business,
                    title: 'Организация',
                    subtitle: 'Профиль и контакты',
                    onTap: () => context.go('/organization'),
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
