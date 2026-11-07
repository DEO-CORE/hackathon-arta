import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session.dart';
import '../../auth/models/auth_models.dart';

/// Phase 1 landing screen; feature entry points are added by later phases.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    final roleLabel =
        user?.role == UserRole.enterprise ? 'Предприятие' : 'Покупатель';
    return Scaffold(
      appBar: AppBar(
        title: const Text('ARTA'),
        actions: [
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            children: [
              Text(user?.email ?? '',
                  style: Theme.of(context).textTheme.titleMedium),
              Text('Роль: $roleLabel'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.inventory_2),
                title: Text(user?.role == UserRole.enterprise
                    ? 'Партии'
                    : 'Каталог партий'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/materials'),
              ),
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Организация'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/organization'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
