import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../printer.dart';
import '../session.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _header = TextEditingController();
  final _footer = TextEditingController();
  String? _printer;

  @override
  void initState() {
    super.initState();
    () async {
      _header.text = await Printer.header;
      _footer.text = await Printer.footer;
      final p = await Printer.savedAddress;
      if (mounted) setState(() => _printer = p);
    }();
  }

  Future<void> _pickPrinter() async {
    try {
      final printers = await Printer.pairedPrinters();
      if (!mounted) return;
      final picked = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Pilih printer'),
          children: [
            if (printers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada perangkat. Pair printer di pengaturan Bluetooth HP.'),
              ),
            for (final p in printers)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, p.macAdress),
                child: Text('${p.name}\n${p.macAdress}'),
              ),
          ],
        ),
      );
      if (picked != null) {
        await Printer.saveSettings(address: picked);
        setState(() => _printer = picked);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _changePin() async {
    final old = TextEditingController(), fresh = TextEditingController(), again = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ganti PIN'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (c, label) in [(old, 'PIN lama'), (fresh, 'PIN baru'), (again, 'Ulangi PIN baru')])
            TextField(
              controller: c,
              obscureText: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: label),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<Session>().api.post('/me/pin', {
        'old_pin': old.text,
        'new_pin': fresh.text,
        'new_pin_confirmation': again.text,
      });
      if (mounted) showError(context, 'PIN berhasil diganti');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.print),
            title: const Text('Printer struk'),
            subtitle: Text(_printer ?? 'Belum dipilih'),
            onTap: _pickPrinter,
          ),
          TextField(controller: _header, decoration: const InputDecoration(labelText: 'Judul struk')),
          TextField(controller: _footer, decoration: const InputDecoration(labelText: 'Catatan bawah struk')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              await Printer.saveSettings(header: _header.text, footer: _footer.text);
              if (context.mounted) showError(context, 'Pengaturan struk disimpan');
            },
            child: const Text('Simpan pengaturan struk'),
          ),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock),
            title: const Text('Ganti PIN'),
            onTap: _changePin,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Keluar'),
            onTap: () async {
              await context.read<Session>().logout();
              if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
            },
          ),
        ],
      ),
    );
  }
}
