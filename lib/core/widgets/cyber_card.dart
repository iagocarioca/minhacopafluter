import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CyberCard extends StatelessWidget {
  const CyberCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.borderRadius,
    this.glow = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    final content = Ink(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: radius,
        border: Border.all(
          color: glow
              ? AppTheme.primary.withValues(alpha: 0.35)
              : AppTheme.surfaceBorderSoft,
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(14),
        child: child,
      ),
    );

    if (onTap == null && onLongPress == null) {
      return Container(margin: margin, child: content);
    }

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radius,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppTheme.primary.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.hovered)) {
              return AppTheme.primary.withValues(alpha: 0.05);
            }
            return Colors.transparent;
          }),
          child: content,
        ),
      ),
    );
  }
}
