import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'session.dart';

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
      title: 'Bhobu Reload',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1565C0), useMaterial3: true),
      home: Consumer<Session>(
        builder: (context, session, _) {
          if (session.loading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return session.loggedIn ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}
