import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/boot_screen.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppState();
  runApp(
    ChangeNotifierProvider.value(
      value: app,
      child: const SigfvApp(),
    ),
  );
  app.init();
}

class SigfvApp extends StatelessWidget {
  const SigfvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIGFV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      locale: const Locale('es', 'PE'),
      supportedLocales: const [
        Locale('es', 'PE'),
        Locale('es'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _AppGate(),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    final status = context.select<AppState, AppStatus>((s) => s.status);
    switch (status) {
      case AppStatus.ready:
        return const HomeShell();
      case AppStatus.login:
        return const LoginScreen();
      case AppStatus.boot:
      case AppStatus.bootError:
        return const BootScreen();
    }
  }
}
