import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_hatch.dart';

enum AppMassKind { free, reserved, transferred, internal }

class AppMassSegment {
  const AppMassSegment({
    required this.kind,
    required this.label,
    required this.valueText,
    required this.weight,
  });

  final AppMassKind kind;
  final String label;

  /// Server value formatted for display, for example "7 кг".
  final String valueText;

  /// Layout weight only (segment width). It never feeds any business figure.
  final double weight;
}

/// Segmented distribution strip with a label and value under each segment.
/// Zero segments keep a small stub so every label stays visible. Segment kinds
/// differ by fill pattern, not by colour alone (transferred is hatched).
class AppMassBar extends StatelessWidget {
  const AppMassBar({super.key, required this.segments});

  final List<AppMassSegment> segments;

  static const _minShare = 0.06;

  (Color, bool) _style(AppMassKind k) => switch (k) {
        AppMassKind.free => (AppColors.success, false),
        AppMassKind.reserved => (AppColors.primary, false),
        AppMassKind.transferred => (AppColors.neutralBg, true),
        AppMassKind.internal => (AppColors.controlBorder, false),
      };

  @override
  Widget build(BuildContext context) {
    final sum = segments.fold<double>(0, (a, s) => a + s.weight);
    double share(AppMassSegment s) =>
        sum <= 0 ? 1 / segments.length : (s.weight / sum).clamp(_minShare, 1.0);
    return Semantics(
      container: true,
      label:
          [for (final s in segments) '${s.label}: ${s.valueText}'].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 12,
              child: sum <= 0
                  // Nothing registered: an empty track, labels stay below.
                  ? const ColoredBox(
                      color: AppColors.surfaceSunken, child: SizedBox.expand())
                  : Row(
                      // Stretch: a childless box would otherwise collapse to height 0.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < segments.length; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          Expanded(
                            flex: (share(segments[i]) * 1000).round(),
                            child: _fill(segments[i].kind),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Legend as a Wrap: whole items move to the next row, so a word such
          // as "Зарезервировано" is never split in the middle.
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in segments)
                _Caption(segment: s, swatch: _fill(s.kind)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fill(AppMassKind k) {
    final (c, hatched) = _style(k);
    return ColoredBox(
      color: c,
      child: hatched
          ? const AppHatch(child: SizedBox.expand())
          : const SizedBox.expand(),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.segment, required this.swatch});
  final AppMassSegment segment;
  final Widget swatch;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: SizedBox(
              width: 12,
              height: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: swatch,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Flexible: a long label wraps between words instead of overflowing.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(segment.label, style: AppTypography.caption),
                Text(segment.valueText, style: AppTypography.label),
              ],
            ),
          ),
        ],
      );
}
