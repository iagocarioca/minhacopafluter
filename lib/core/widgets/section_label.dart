import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.label,
    this.color = AppTheme.primary,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.25,
          ),
        ),
      ],
    );
  }
}
