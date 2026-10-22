import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  final _upline = TextEditingController();
  bool _register = false;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    final session = context.read<Session>();
    try {
      if (_register) {
        await session.register(_name.text.trim(), _phone.text.trim(), _pin.text, _upline.text.trim());
      } else {
        await session.login(_phone.text.trim(), _pin.text);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Icon(Icons.phone_android, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('Bhobu Reload',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 32),
            if (_register)
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama')),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor HP'),
            ),
            TextField(
              controller: _pin,
              obscureText: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PIN 6 angka'),
            ),
            if (_register)
              TextField(
                controller: _upline,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'HP upline / referral (opsional)'),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Memproses...' : (_register ? 'Daftar' : 'Masuk')),
            ),
            TextButton(
              onPressed: () => setState(() => _register = !_register),
              child: Text(_register ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar'),
            ),
          ],
        ),
      ),
    );
  }
}
