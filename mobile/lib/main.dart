import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'brand_logo.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'session.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final session = Session();
  session.restore();
  runApp(ChangeNotifierProvider.value(value: session, child: const PpobApp()));
}

class PpobApp extends StatelessWidget {
  const PpobApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZPP Reload',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Consumer<Session>(
        builder: (context, session, _) {
          if (session.loading) return const _Splash();
          return session.loggedIn ? const MainShell() : const LoginScreen();
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: Brand.headerGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Mascot(pose: 'mascot_wave', height: 200),
              SizedBox(height: 24),
              BrandLogo(size: 48),
            ],
          ),
        ),
      ),
    );
  }
}
