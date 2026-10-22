import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../session.dart';
import 'bill_screen.dart';
import 'deposit_screen.dart';
import 'history_screen.dart';
import 'mutation_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<Session>();
    try {
      final results = await Future.wait([session.api.get('/categories'), session.refresh()]);
      setState(() => _categories = results.first as List<dynamic>);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load(); // saldo bisa berubah setelah transaksi/deposit
  }

  IconData _icon(String category) {
    final c = category.toLowerCase();
    if (c.contains('pulsa')) return Icons.phone_android;
    if (c.contains('data')) return Icons.wifi;
    if (c.contains('pln') || c.contains('token')) return Icons.bolt;
    if (c.contains('game')) return Icons.sports_esports;
    if (c.contains('money') || c.contains('wallet')) return Icons.account_balance_wallet;
    if (c.contains('voucher')) return Icons.confirmation_number;
    if (c.contains('pasca')) return Icons.receipt_long;
    return Icons.apps;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return Scaffold(
      appBar: AppBar(
        title: Text('Halo, ${session.user?['name'] ?? ''}'),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings), onPressed: () => _open(const SettingsScreen())),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saldo'),
                    Text(rupiah(session.balance),
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    Row(children: [
                      _QuickAction(Icons.add_card, 'Deposit', () => _open(const DepositScreen())),
                      _QuickAction(Icons.history, 'Riwayat', () => _open(const HistoryScreen())),
                      _QuickAction(Icons.swap_vert, 'Mutasi', () => _open(const MutationScreen())),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _categories.isEmpty)
              const Center(child: Text('Belum ada produk. Admin perlu sinkron harga supplier.')),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final c in _categories)
                  InkWell(
                    onTap: () => _open(c['is_postpaid'] == true
                        ? BillScreen(category: c['category'], brands: List<String>.from(c['brands']))
                        : ProductsScreen(category: c['category'], brands: List<String>.from(c['brands']))),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_icon(c['category']), size: 32),
                        const SizedBox(height: 4),
                        Text(c['category'],
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(children: [Icon(icon), Text(label, style: const TextStyle(fontSize: 12))]),
      ),
    );
  }
}
