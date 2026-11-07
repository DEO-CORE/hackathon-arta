import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Always visible in demo mode so synthetic data is never mistaken for real.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.demoBanner,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          label: 'Демо-режим',
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: Text(
              'Демо: синтетические данные, не реальные',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.surface, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
