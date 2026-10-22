import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../session.dart';
import '../widgets.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _amount = TextEditingController();
  List<dynamic> _deposits = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<Session>().api.get('/deposits');
      setState(() => _deposits = res['data']);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _create() async {
    final amount = int.tryParse(_amount.text.replaceAll('.', ''));
    if (amount == null) return showError(context, 'Isi nominal deposit');
    setState(() => _busy = true);
    try {
      final d = await context.read<Session>().api.post('/deposits', {'amount': amount});
      _amount.clear();
      await _load();
      if (mounted) _showTicket(Map<String, dynamic>.from(d));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showTicket(Map<String, dynamic> d) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tiket deposit'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Transfer TEPAT sejumlah (termasuk 3 digit terakhir):'),
          const SizedBox(height: 8),
          Text(rupiah(d['total']), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          InfoRow('Ke rekening', d['bank_info'] ?? '-'),
          const Text('Saldo bertambah setelah admin mengonfirmasi.',
              style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: '${d['total']}')),
            child: const Text('Salin nominal'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deposit saldo')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nominal deposit', prefixText: 'Rp '),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _create, child: const Text('Buat tiket deposit')),
            const SizedBox(height: 24),
            Text('Riwayat deposit', style: Theme.of(context).textTheme.titleMedium),
            for (final d in _deposits)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(rupiah(d['total'])),
                subtitle: Text(dateTime(d['created_at'])),
                trailing: Text(switch (d['status']) {
                  'paid' => 'Lunas',
                  'rejected' => 'Ditolak',
                  'expired' => 'Kedaluwarsa',
                  _ => 'Menunggu',
                }),
                onTap: d['status'] == 'pending' ? () => _showTicket(Map<String, dynamic>.from(d)) : null,
              ),
          ],
        ),
      ),
    );
  }
}
