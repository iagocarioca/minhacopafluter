import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum CyberBadgeVariant { active, pending, ended, danger, info }

class CyberBadge extends StatelessWidget {
  const CyberBadge({
    super.key,
    required this.label,
    this.variant = CyberBadgeVariant.active,
  });

  final String label;
  final CyberBadgeVariant variant;

  Color _textColor() {
    return switch (variant) {
      CyberBadgeVariant.active => const Color(0xFF0F9F55),
      CyberBadgeVariant.pending => const Color(0xFFB87A1C),
      CyberBadgeVariant.ended => const Color(0xFF6B7586),
      CyberBadgeVariant.danger => const Color(0xFFDA3F4D),
      CyberBadgeVariant.info => AppTheme.info,
    };
  }

  Color _backgroundColor() {
    return switch (variant) {
      CyberBadgeVariant.active => const Color(0x1A18C76F),
      CyberBadgeVariant.pending => const Color(0x1FE9A73E),
      CyberBadgeVariant.ended => const Color(0x1A7A8597),
      CyberBadgeVariant.danger => const Color(0x20E14A52),
      CyberBadgeVariant.info => const Color(0x1F3B82F6),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor(),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.surfaceBorderSoft),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: _textColor(),
        ),
      ),
    );
  }
}
