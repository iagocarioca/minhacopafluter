import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
import 'app_services.dart';
import 'router.dart';

class MinhaCopaApp extends StatefulWidget {
  const MinhaCopaApp({super.key, required this.services});

  final AppServices services;

  @override
  State<MinhaCopaApp> createState() => _MinhaCopaAppState();
}

class _MinhaCopaAppState extends State<MinhaCopaApp> {
  late final _router = buildAppRouter(services: widget.services);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MinhaCopa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      routerConfig: _router,
    );
  }
}
