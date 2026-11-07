import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_top_bar.dart';

/// Sheet for choose / review / non-destructive confirm. Destructive or
/// irreversible actions keep [AppConfirmDialog]. Esc and the close tile close
/// it; the framework returns focus to the trigger.
abstract final class AppBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required WidgetBuilder builder,
  }) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        backgroundColor: AppColors.surfaceSunken,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
        ),
        builder: (ctx) => AppSheetBody(title: title, child: builder(ctx)),
      );
}

class AppSheetBody extends StatelessWidget {
  const AppSheetBody({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ExcludeSemantics(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.controlBorder,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title,
                            style: AppTypography.headline
                                .copyWith(fontSize: 22, height: 28 / 22)),
                      ),
                    ),
                    AppIconTile(
                      icon: Icons.close,
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                child,
              ],
            ),
          ),
        ),
      );
}
