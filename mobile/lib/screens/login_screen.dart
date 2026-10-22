import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../brand_logo.dart';
import '../format.dart';
import '../session.dart';
import '../theme.dart';

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
  bool _showPin = false;

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
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Brand.headerGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            children: [
              const BrandLogo(size: 44),
              const SizedBox(height: 8),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Halo, selamat datang!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Smart Transactions, Anytime, Anywhere.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Mascot(pose: 'mascot_wave', height: 170),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _register ? 'Buat akun baru' : 'Masuk ke akun Anda',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Brand.deep),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _register ? 'Daftar gratis, langsung bisa transaksi.' : 'Gunakan nomor HP dan PIN Anda.',
                      style: const TextStyle(color: Brand.muted),
                    ),
                    const SizedBox(height: 20),
                    if (_register) ...[
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          hintText: 'Nama lengkap',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: 'Nomor HP', prefixIcon: Icon(Icons.phone_iphone)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pin,
                      obscureText: !_showPin,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'PIN 6 angka',
                        counterText: '',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_showPin ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _showPin = !_showPin),
                        ),
                      ),
                    ),
                    if (_register) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _upline,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: 'Kode referral / HP upline (opsional)',
                          prefixIcon: Icon(Icons.group_outlined),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_register ? 'Daftar' : 'Masuk'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _register = !_register),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _register ? 'Sudah punya akun? ' : 'Belum punya akun? ',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      TextSpan(
                        text: _register ? 'Masuk' : 'Daftar sekarang',
                        style: const TextStyle(color: Brand.accentLight, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
