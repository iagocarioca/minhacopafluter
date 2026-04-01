import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallbackLocation = '/home'});

  final String fallbackLocation;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: const EdgeInsets.only(left: 10),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      iconSize: 22,
      splashRadius: 20,
      color: Colors.white,
      onPressed: () {
        final router = GoRouter.of(context);
        if (router.canPop()) {
          context.pop();
        } else {
          context.go(fallbackLocation);
        }
      },
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
    );
  }
}
