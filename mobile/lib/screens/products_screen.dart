import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home_screen.dart' show categoryStyle;
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
  Map<String, dynamic>? _selected;
  String? _brand;
  bool _loading = true;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _brand = widget.brands.length == 1 ? widget.brands.first : null;
    _customerNo.addListener(_detectOperator);
    _load();
  }

  /// Pilih brand otomatis dari awalan nomor HP (khusus kategori pulsa/data).
  void _detectOperator() {
    final operator = operatorFromNumber(_customerNo.text);
    if (operator == null) return;
    final match = widget.brands.where((b) => b.toUpperCase().contains(operator)).firstOrNull;
    if (match != null && match != _brand) {
      setState(() => _brand = match);
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _selected = null;
    });
    try {
      final res = await context.read<Session>().api.get('/products', {'category': widget.category, 'brand': ?_brand});
      setState(() => _products = res as List<dynamic>);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy() async {
    final product = _selected!;
    final customerNo = _customerNo.text.trim();
    if (customerNo.isEmpty) {
      showError(context, 'Isi nomor tujuan dulu');
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE2E6EF), borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Konfirmasi pembelian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              InfoRow('Produk', product['name']),
              InfoRow('Nomor tujuan', customerNo),
              const Divider(height: 24),
              InfoRow('Total bayar', rupiah(product['price']), bold: true),
              const SizedBox(height: 20),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Bayar dengan Saldo')),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final pin = await askPin(context);
    if (pin == null || !mounted) return;

    setState(() => _buying = true);
    try {
      final res = await context.read<Session>().api.post('/transactions', {
        'sku': product['sku'],
        'customer_no': customerNo,
        'pin': pin,
      });
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TransactionScreen(initial: res['data'])));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = categoryStyle(widget.category);
    return Scaffold(
      appBar: AppBar(title: Text(widget.category)),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _customerNo,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  decoration: InputDecoration(
                    hintText: 'Nomor HP / ID pelanggan',
                    prefixIcon: Icon(icon, color: color),
                  ),
                ),
                if (widget.brands.length > 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final b in [null, ...widget.brands])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
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
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                ? const Center(
                    child: Text('Produk belum tersedia', style: TextStyle(color: Brand.muted)),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.75,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (context, i) {
                      final p = _products[i] as Map<String, dynamic>;
                      return _ProductCard(
                        product: p,
                        selected: _selected?['sku'] == p['sku'],
                        onTap: () => setState(() => _selected = p),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _selected == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(color: Colors.white, boxShadow: Brand.softShadow),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total', style: TextStyle(color: Brand.muted, fontSize: 12)),
                          Text(
                            rupiah(_selected!['price']),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Brand.deep),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: FilledButton(onPressed: _buying ? null : _buy, child: const Text('Beli Sekarang')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

const _prefixes = {
  'TELKOMSEL': ['0811', '0812', '0813', '0821', '0822', '0823', '0851', '0852', '0853'],
  'INDOSAT': ['0814', '0815', '0816', '0855', '0856', '0857', '0858'],
  'XL': ['0817', '0818', '0819', '0859', '0877', '0878'],
  'AXIS': ['0831', '0832', '0833', '0838'],
  'TRI': ['0895', '0896', '0897', '0898', '0899'],
  'SMARTFREN': ['0881', '0882', '0883', '0884', '0885', '0886', '0887', '0888', '0889'],
};

/// Nama operator dari awalan nomor HP Indonesia, atau null bila tidak dikenali.
String? operatorFromNumber(String input) {
  var number = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (number.startsWith('62')) number = '0${number.substring(2)}';
  if (number.length < 4) return null;
  final prefix = number.substring(0, 4);
  for (final entry in _prefixes.entries) {
    if (entry.value.contains(prefix)) return entry.key;
  }
  return null;
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.selected, required this.onTap});
  final Map<String, dynamic> product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: selected ? Brand.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? Brand.primary : const Color(0xFFE7EAF2), width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product['name'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, height: 1.25),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rupiah(product['price']),
                      style: const TextStyle(color: Brand.primary, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  if (selected) const Icon(Icons.check_circle, color: Brand.accent, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
