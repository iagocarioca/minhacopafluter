import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CyberTabs extends StatelessWidget {
  const CyberTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (index) {
            final selected = index == selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0x2018C76F)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0x4518C76F)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 0.1,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
