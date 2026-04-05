import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

class AuthPremiumLayout extends StatelessWidget {
  const AuthPremiumLayout({
    super.key,
    required this.headlineTop,
    required this.headlineBottom,
    required this.child,
    this.hero,
    this.showBack = true,
    this.watermark = 'JOGO',
    this.brandLabel = 'MINHACOPA',
    this.headerColor = AppTheme.primary,
    this.pageBackground = const Color(0xFFF3F4F6),
    this.logoImageUrl,
    this.headerBackgroundImageUrl,
    this.logoOnlyHeader = false,
    this.centerContent = false,
    this.contentMaxWidth = 360,
  });

  final String headlineTop;
  final String headlineBottom;
  final Widget child;
  final Widget? hero;
  final bool showBack;
  final String watermark;
  final String brandLabel;
  final Color headerColor;
  final Color pageBackground;
  final String? logoImageUrl;
  final String? headerBackgroundImageUrl;
  final bool logoOnlyHeader;
  final bool centerContent;
  final double contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ColoredBox(
            color: pageBackground,
            child: Column(
              children: [
                Container(
                  color: headerColor,
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: hero != null ? 246 : 212,
                      child: Stack(
                        children: [
                          if (headerBackgroundImageUrl != null)
                            Positioned.fill(
                              child: Image.network(
                                headerBackgroundImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(0x2E0A1322),
                                    headerColor.withValues(alpha: 0.82),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (!logoOnlyHeader)
                            Positioned(
                              right: -10,
                              top: 38,
                              child: Text(
                                watermark.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0x5CFF4D5E),
                                  fontSize: 68,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                          if (!logoOnlyHeader)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                14,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (showBack) ...[
                                        const _HeaderBackButton(),
                                        const SizedBox(width: 8),
                                      ],
                                      _HeaderLogo(imageUrl: logoImageUrl),
                                      const SizedBox(width: 6),
                                      Text(
                                        brandLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    headlineTop.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    headlineBottom,
                                    style: const TextStyle(
                                      color: Color(0xFFEFF3F7),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                  if (hero != null) ...[
                                    const SizedBox(height: 12),
                                    hero!,
                                  ],
                                ],
                              ),
                            ),
                          if (logoOnlyHeader)
                            Align(
                              alignment: Alignment.center,
                              child: _HeaderCenterLogo(imageUrl: logoImageUrl),
                            ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: -1,
                            child: SizedBox(
                              height: 44,
                              child: ClipPath(
                                clipper: _AuthHeaderBottomClipper(),
                                child: Container(color: pageBackground),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final minHeight = constraints.maxHeight > 32
                          ? constraints.maxHeight - 32
                          : 0.0;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: minHeight),
                          child: Align(
                            alignment: centerContent
                                ? Alignment.center
                                : Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: contentMaxWidth,
                              ),
                              child: child,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.backgroundColor = AppTheme.primary,
    this.foregroundColor = Colors.white,
    this.borderRadius = 12,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color backgroundColor;
  final Color foregroundColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 0,
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            : Text(
                label.toUpperCase(),
                style: const TextStyle(
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF434A56),
          side: const BorderSide(color: Colors.transparent),
          backgroundColor: const Color(0xFFF5F6F7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

InputDecoration authPillInputDecoration({
  required String hintText,
  Widget? suffixIcon,
}) {
  const borderRadius = BorderRadius.all(Radius.circular(12));

  return InputDecoration(
    hintText: hintText,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    hintStyle: const TextStyle(
      color: Color(0xFF8F959F),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    filled: true,
    fillColor: const Color(0xFFE4E7EC),
    border: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Colors.transparent),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Colors.transparent),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Colors.transparent, width: 0),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Colors.transparent, width: 0),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Colors.transparent, width: 0),
    ),
  );
}

class AuthHeroPanel extends StatelessWidget {
  const AuthHeroPanel({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.sports_soccer_rounded,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x30FF4D5E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFE8ECF2),
                    fontWeight: FontWeight.w600,
                    fontSize: 11.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return Icon(
        Icons.bolt_rounded,
        color: Colors.white.withValues(alpha: 0.95),
        size: 18,
      );
    }

    return Container(
      width: 26,
      height: 26,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.bolt_rounded,
          color: Colors.white.withValues(alpha: 0.95),
          size: 17,
        ),
      ),
    );
  }
}

class _HeaderCenterLogo extends StatelessWidget {
  const _HeaderCenterLogo({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 120,
      child: (imageUrl == null || imageUrl!.trim().isEmpty)
          ? const Icon(
              Icons.sports_soccer_rounded,
              color: Colors.white,
              size: 56,
            )
          : Image.network(
              imageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.sports_soccer_rounded,
                color: Colors.white,
                size: 56,
              ),
            ),
    );
  }
}

class _AuthHeaderBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(0, size.height * 0.82);
    path.quadraticBezierTo(
      size.width * 0.15,
      size.height * 1.0,
      size.width * 0.31,
      size.height * 0.56,
    );
    path.cubicTo(
      size.width * 0.43,
      size.height * 0.2,
      size.width * 0.57,
      size.height * 1.04,
      size.width * 0.69,
      size.height * 0.58,
    );
    path.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.24,
      size.width,
      size.height * 0.84,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        final router = GoRouter.of(context);
        if (router.canPop()) {
          context.pop();
        } else {
          context.go('/splash');
        }
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0x2CFF4D5E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.transparent),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}
