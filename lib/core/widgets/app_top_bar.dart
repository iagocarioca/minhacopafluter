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
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.35,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      flexibleSpace: const _AppTopBarBackground(),
    );
  }
}

class _AppTopBarBackground extends StatelessWidget {
  const _AppTopBarBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2BD382), Color(0xFF18C76F), Color(0xFF14B861)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          right: -24,
          top: -20,
          child: Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
        ),
        Positioned(
          left: -16,
          bottom: -22,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SizedBox(
            height: 12,
            child: ClipPath(
              clipper: _HeaderBottomClipper(),
              child: Container(color: Colors.white.withValues(alpha: 0.25)),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 4);
    path.quadraticBezierTo(
      size.width * 0.24,
      size.height + 3,
      size.width * 0.5,
      size.height - 1,
    );
    path.quadraticBezierTo(
      size.width * 0.78,
      size.height - 7,
      size.width,
      size.height - 1,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
