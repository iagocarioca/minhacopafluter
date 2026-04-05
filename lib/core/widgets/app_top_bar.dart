import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.centerTitle,
    this.toolbarHeight = 66,
    this.automaticallyImplyLeading = true,
    this.actionsPadding,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool? centerTitle;
  final double toolbarHeight;
  final bool automaticallyImplyLeading;
  final EdgeInsetsGeometry? actionsPadding;

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      bottom: bottom,
      centerTitle: centerTitle ?? true,
      toolbarHeight: toolbarHeight,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actionsPadding: actionsPadding,
      elevation: 1.25,
      scrolledUnderElevation: 1.25,
      backgroundColor: const Color(0xFF0F5C57),
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x1F000000),
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.35,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }
}
