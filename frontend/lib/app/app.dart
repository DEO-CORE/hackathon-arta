import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/widgets/demo_banner.dart';
import 'router.dart';
import 'theme.dart';

class ArtaApp extends ConsumerWidget {
  const ArtaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(appConfigProvider).useDemoData;
    return MaterialApp.router(
      title: 'ARTA',
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => Column(
        children: [
          if (demo) const DemoBanner(),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}
