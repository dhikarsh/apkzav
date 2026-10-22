import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../session.dart';
import '../widgets.dart';
import 'transaction_screen.dart';

/// Cek & bayar tagihan pascabayar (PLN, BPJS, PDAM, internet, ...).
class BillScreen extends StatefulWidget {
  const BillScreen({super.key, required this.category, required this.brands});
  final String category;
  final List<String> brands;

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final _customerNo = TextEditingController();
  List<dynamic> _products = [];
  String? _sku;
  Map<String, dynamic>? _bill;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final res = await context.read<Session>().api.get('/products', {'category': widget.category});
      setState(() {
        _products = res as List<dynamic>;
        if (_products.length == 1) _sku = _products.first['sku'];
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _inquiry() async {
    if (_sku == null || _customerNo.text.trim().isEmpty) {
      showError(context, 'Pilih layanan dan isi ID pelanggan');
      return;
    }
    setState(() {
      _busy = true;
      _bill = null;
    });
    try {
      final res = await context.read<Session>().api.post('/bills/inquiry', {
        'sku': _sku,
        'customer_no': _customerNo.text.trim(),
      });
      setState(() => _bill = Map<String, dynamic>.from(res));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    final pin = await askPin(context);
    if (pin == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await context.read<Session>().api.post('/bills/${_bill!['ref_id']}/pay', {'pin': pin});
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => TransactionScreen(initial: res['data'])));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = _bill;
    return Scaffold(
      appBar: AppBar(title: Text(widget.category)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _sku,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Layanan'),
            items: [
              for (final p in _products)
                DropdownMenuItem(value: p['sku'] as String, child: Text(p['name'])),
            ],
            onChanged: (v) => setState(() {
              _sku = v;
              _bill = null;
            }),
          ),
          TextField(
            controller: _customerNo,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'ID pelanggan / nomor'),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: _busy ? null : _inquiry,
            child: const Text('Cek tagihan'),
          ),
          if (bill != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  InfoRow('Layanan', bill['product']),
                  InfoRow('ID pelanggan', bill['customer_no']),
                  InfoRow('Nama', bill['customer_name'] ?? '-'),
                  InfoRow('Total bayar', rupiah(bill['price']), bold: true),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _busy ? null : _pay, child: const Text('Bayar tagihan')),
          ],
        ],
      ),
    );
  }
}
