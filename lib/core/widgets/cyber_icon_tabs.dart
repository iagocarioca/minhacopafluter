import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CyberIconTabItem {
  const CyberIconTabItem({
    required this.label,
    required this.icon,
    this.accentColor,
  });

  final String label;
  final IconData icon;
  final Color? accentColor;
}

class CyberIconTabs extends StatelessWidget {
  const CyberIconTabs({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<CyberIconTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == selectedIndex;
            final accent = item.accentColor ?? AppTheme.primary;
            return Padding(
              padding: EdgeInsets.only(
                right: index == items.length - 1 ? 0 : 8,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0x1A18C76F)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0x4018C76F)
                          : Colors.transparent,
                    ),
                  ),
                  child: SizedBox(
                    width: 96,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0x2018C76F)
                                : AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.surfaceBorder),
                          ),
                          child: Icon(
                            item.icon,
                            size: 20,
                            color: selected ? accent : AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppTheme.textPrimary
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
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
