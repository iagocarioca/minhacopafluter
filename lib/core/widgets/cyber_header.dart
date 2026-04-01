import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CyberHeader extends StatelessWidget {
  const CyberHeader({super.key, required this.child, this.glow = false});

  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: glow
              ? AppTheme.primary.withValues(alpha: 0.35)
              : AppTheme.surfaceBorderSoft,
        ),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF4F7FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}
