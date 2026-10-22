import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../session.dart';
import '../widgets.dart';
import 'transaction_screen.dart';

/// Daftar produk prabayar satu kategori (pulsa, data, token PLN, game, e-money, ...).
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.category, required this.brands});
  final String category;
  final List<String> brands;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _customerNo = TextEditingController();
  List<dynamic> _products = [];
  String? _brand;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _brand = widget.brands.length == 1 ? widget.brands.first : null;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await context.read<Session>().api.get('/products', {
        'category': widget.category,
        'brand': ?_brand,
      });
      setState(() => _products = res as List<dynamic>);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy(Map<String, dynamic> product) async {
    final customerNo = _customerNo.text.trim();
    if (customerNo.isEmpty) {
      showError(context, 'Isi nomor tujuan dulu');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          InfoRow('Produk', product['name']),
          InfoRow('Tujuan', customerNo),
          InfoRow('Harga', rupiah(product['price']), bold: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Beli')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final pin = await askPin(context);
    if (pin == null || !mounted) return;

    try {
      final res = await context.read<Session>().api.post('/transactions', {
        'sku': product['sku'],
        'customer_no': customerNo,
        'pin': pin,
      });
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => TransactionScreen(initial: res['data'])));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _customerNo,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor tujuan / ID pelanggan',
                prefixIcon: Icon(Icons.contact_phone),
              ),
            ),
          ),
          if (widget.brands.length > 1)
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (final b in [null, ...widget.brands])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(b ?? 'Semua'),
                        selected: _brand == b,
                        onSelected: (_) {
                          setState(() => _brand = b);
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _products.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = _products[i] as Map<String, dynamic>;
                      return ListTile(
                        title: Text(p['name']),
                        subtitle: p['description'] == null || p['description'] == '-'
                            ? null
                            : Text(p['description'], maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Text(rupiah(p['price']),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () => _buy(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
