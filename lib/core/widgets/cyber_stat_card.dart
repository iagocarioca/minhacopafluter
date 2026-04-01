import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'cyber_card.dart';

class CyberStatCard extends StatelessWidget {
  const CyberStatCard({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
    this.glow = true,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return CyberCard(
      glow: glow,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: highlight ? AppTheme.primary : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.1,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
