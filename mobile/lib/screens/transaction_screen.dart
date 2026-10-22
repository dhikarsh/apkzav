import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../format.dart';
import '../printer.dart';
import '../session.dart';
import '../widgets.dart';

/// Detail transaksi. Saat masih diproses, status dicek ulang tiap 3 detik.
class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key, required this.initial});
  final Map<String, dynamic> initial;

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  late Map<String, dynamic> _trx = widget.initial;
  Timer? _timer;
  int _polls = 0;

  @override
  void initState() {
    super.initState();
    if (_trx['status'] == 'pending') {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polls++ > 100) return _timer?.cancel();
    try {
      final res = await context.read<Session>().api.get('/transactions/${_trx['ref_id']}');
      if (!mounted) return;
      setState(() => _trx = Map<String, dynamic>.from(res['data']));
      if (_trx['status'] != 'pending') {
        _timer?.cancel();
        context.read<Session>().refresh();
      }
    } catch (_) {}
  }

  String get _receiptText => Receipt.fromTransaction(_trx).asText();

  Future<void> _print() async {
    try {
      await Printer.printReceipt(Receipt.fromTransaction(_trx));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _trx['status'] as String;
    final product = _trx['product'] as Map;
    final detail = _trx['detail'] is Map ? _trx['detail'] as Map : const {};
    return Scaffold(
      appBar: AppBar(title: const Text('Detail transaksi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(children: [
              Icon(
                switch (status) {
                  'success' => Icons.check_circle,
                  'failed' => Icons.cancel,
                  _ => Icons.hourglass_top,
                },
                size: 72,
                color: statusColor(status),
              ),
              Text(statusLabel(status),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: statusColor(status))),
              if (status == 'pending') const Text('Transaksi sedang diproses...'),
            ]),
          ),
          const SizedBox(height: 16),
          InfoRow('Produk', product['name']),
          InfoRow('Tujuan', _trx['customer_no']),
          if (detail['customer_name'] != null) InfoRow('Nama', detail['customer_name']),
          InfoRow('Harga', rupiah(_trx['price']), bold: true),
          InfoRow('SN / Token', _trx['sn'] ?? '-', bold: true),
          InfoRow('Ref ID', _trx['ref_id']),
          InfoRow('Waktu', dateTime(_trx['created_at'])),
          if (_trx['message'] != null) InfoRow('Keterangan', _trx['message']),
          const SizedBox(height: 24),
          if (status == 'success')
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                    onPressed: _print, icon: const Icon(Icons.print), label: const Text('Cetak')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => SharePlus.instance.share(ShareParams(text: _receiptText)),
                  icon: const Icon(Icons.share),
                  label: const Text('Bagikan'),
                ),
              ),
            ]),
        ],
      ),
    );
  }
}
