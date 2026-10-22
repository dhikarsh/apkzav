import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../brand_logo.dart';
import '../format.dart';
import '../printer.dart';
import '../session.dart';
import '../theme.dart';
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
    final color = statusColor(status);
    return Scaffold(
      appBar: AppBar(title: const Text('Detail transaksi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: Brand.softShadow,
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                  child: Column(
                    children: [
                      if (status == 'success')
                        const Mascot(pose: 'mascot_thumbs', height: 120)
                      else
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: color,
                          child: status == 'pending'
                              ? const SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                                )
                              : Icon(
                                  status == 'success' ? Icons.check_rounded : Icons.close_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                        ),
                      const SizedBox(height: 12),
                      Text(switch (status) {
                        'success' => 'Transaksi Berhasil',
                        'failed' => 'Transaksi Gagal',
                        _ => 'Sedang Diproses',
                      }, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                      const SizedBox(height: 4),
                      Text(
                        rupiah(_trx['price']),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Brand.deep),
                      ),
                      if (status == 'failed')
                        const Text('Saldo sudah dikembalikan', style: TextStyle(color: Brand.muted)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      InfoRow('Produk', product['name']),
                      InfoRow('Nomor tujuan', _trx['customer_no']),
                      if (detail['customer_name'] != null) InfoRow('Nama', detail['customer_name']),
                      if (_trx['sn'] != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Brand.accentLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SN / Token', style: TextStyle(color: Brand.muted, fontSize: 12)),
                              const SizedBox(height: 4),
                              SelectableText(
                                _trx['sn'],
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      InfoRow('Ref ID', _trx['ref_id']),
                      InfoRow('Waktu', dateTime(_trx['created_at'])),
                      if (_trx['message'] != null && status != 'success') InfoRow('Keterangan', _trx['message']),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (status == 'success')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _print,
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Cetak'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => SharePlus.instance.share(ShareParams(text: _receiptText)),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Bagikan'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
