import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../brand_logo.dart';
import '../format.dart';
import '../session.dart';
import '../theme.dart';
import 'bill_screen.dart';
import 'mutation_screen.dart';
import 'products_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  /// Pindah ke tab lain di navigasi bawah (1 = Transaksi, 2 = Deposit).
  final void Function(int index) onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _categories = [];
  bool _loading = true;
  bool _hideBalance = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<Session>();
    try {
      final results = await Future.wait([session.api.get('/categories'), session.refresh()]);
      // Kategori paling sering dipakai tampil lebih dulu.
      const order = ['pulsa', 'data', 'pln', 'money', 'game', 'voucher'];
      int rank(dynamic c) {
        final name = (c['category'] as String).toLowerCase();
        final i = order.indexWhere(name.contains);
        return i < 0 ? order.length : i;
      }

      final categories = List<dynamic>.from(results.first as List)..sort((a, b) => rank(a) - rank(b));
      setState(() => _categories = categories);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load(); // saldo bisa berubah setelah transaksi
  }

  void _openCategory(Map c) {
    final brands = List<String>.from(c['brands']);
    _open(
      c['is_postpaid'] == true
          ? BillScreen(category: c['category'], brands: brands)
          : ProductsScreen(category: c['category'], brands: brands),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final prepaid = _categories.where((c) => c['is_postpaid'] != true).toList();
    final postpaid = _categories.where((c) => c['is_postpaid'] == true).toList();
    final firstName = (session.user?['name'] as String? ?? '').split(' ').first;

    return RefreshIndicator(
      onRefresh: _load,
      color: Brand.primary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                Container(
                  height: 210,
                  decoration: const BoxDecoration(
                    gradient: Brand.headerGradient,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 58,
                  right: 18,
                  child: const Mascot(pose: 'mascot_thumbs', height: 104),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const BrandLogo(size: 34),
                            const Spacer(),
                            if (demoMode) const DemoBadge(),
                            IconButton(
                              onPressed: () => _open(const MutationScreen()),
                              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text('Halo, $firstName', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const Text(
                          'Mau transaksi apa hari ini?',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        _balanceCard(session),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: _PromoStrip()),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (!_loading && _categories.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Produk belum tersedia. Silakan hubungi admin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Brand.muted),
                ),
              ),
            ),
          if (prepaid.isNotEmpty) ..._section('Isi Ulang & Voucher', prepaid),
          if (postpaid.isNotEmpty) ..._section('Bayar Tagihan', postpaid),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _balanceCard(Session session) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Brand.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: Brand.accentGradient, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saldo ZPP', style: TextStyle(color: Brand.muted, fontSize: 12)),
                    Text(
                      _hideBalance ? 'Rp •••••••' : rupiah(session.balance),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Brand.deep),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _hideBalance = !_hideBalance),
                icon: Icon(
                  _hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Brand.muted,
                  size: 20,
                ),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          Row(
            children: [
              _Action(Icons.add_circle_outline, 'Isi Saldo', () => widget.onOpenTab(2)),
              _Action(Icons.receipt_long_outlined, 'Riwayat', () => widget.onOpenTab(1)),
              _Action(Icons.swap_vert_rounded, 'Mutasi', () => _open(const MutationScreen())),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _section(String title, List<dynamic> items) => [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: Brand.softShadow,
          ),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.95,
            children: [for (final c in items) _CategoryTile(c, () => _openCategory(c))],
          ),
        ),
      ),
    ),
  ];
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Icon(icon, color: Brand.primary),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ikon & warna per kategori, ditebak dari nama kategori Digiflazz.
(IconData, Color) categoryStyle(String category) {
  final c = category.toLowerCase();
  if (c.contains('pulsa')) return (Icons.smartphone_rounded, const Color(0xFFE11D48));
  if (c.contains('data')) return (Icons.wifi_rounded, const Color(0xFF2563EB));
  if (c.contains('pln') || c.contains('token') || c.contains('listrik')) {
    return (Icons.bolt_rounded, const Color(0xFFF59E0B));
  }
  if (c.contains('game')) return (Icons.sports_esports_rounded, const Color(0xFF7C3AED));
  if (c.contains('money') || c.contains('wallet')) {
    return (Icons.account_balance_wallet_rounded, const Color(0xFF059669));
  }
  if (c.contains('voucher')) return (Icons.confirmation_number_rounded, const Color(0xFFEA580C));
  if (c.contains('bpjs')) return (Icons.health_and_safety_rounded, const Color(0xFF16A34A));
  if (c.contains('pdam') || c.contains('air')) return (Icons.water_drop_rounded, const Color(0xFF0284C7));
  if (c.contains('internet') || c.contains('tv')) return (Icons.router_rounded, const Color(0xFF4F46E5));
  if (c.contains('pasca') || c.contains('tagihan')) return (Icons.receipt_rounded, const Color(0xFF0F766E));
  return (Icons.apps_rounded, Brand.primary);
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile(this.category, this.onTap);
  final Map category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = categoryStyle(category['category']);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              category['category'],
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner keunggulan di beranda (statis; bisa diganti banner promo dari server nanti).
class _PromoStrip extends StatelessWidget {
  const _PromoStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.flash_on_rounded, 'Proses Kilat', 'Transaksi otomatis 24 jam'),
      (Icons.verified_user_rounded, 'Aman & Terpercaya', 'Saldo kembali jika gagal'),
      (Icons.print_rounded, 'Cetak Struk', 'Langsung ke printer Bluetooth'),
    ];
    return SizedBox(
      height: 96,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final (icon, title, subtitle) = items[i];
          return Container(
            width: 240,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: i.isEven ? Brand.headerGradient : null,
              color: i.isEven ? null : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: i.isEven ? null : Border.all(color: Brand.accentLight),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(gradient: Brand.accentGradient, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontWeight: FontWeight.w700, color: i.isEven ? Colors.white : Brand.deep),
                      ),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: i.isEven ? Colors.white70 : Brand.muted)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
