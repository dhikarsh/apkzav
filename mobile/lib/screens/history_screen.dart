import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../brand_logo.dart';
import '../format.dart';
import '../session.dart';
import '../theme.dart';
import 'home_screen.dart' show categoryStyle;
import 'transaction_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final List<dynamic> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _page = 1;
      _hasMore = true;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final res = await context.read<Session>().api.get('/transactions', {'page': '$_page'});
      setState(() {
        _items.addAll(res['data']);
        _hasMore = res['meta']['current_page'] < res['meta']['last_page'];
        _page++;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 300) _loadMore();
            return false;
          },
          child: ListView.separated(
            itemCount: _items.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i == _items.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : _items.isEmpty
                        ? const Column(
                            children: [
                              SizedBox(height: 40),
                              Mascot(height: 150),
                              SizedBox(height: 12),
                              Text('Belum ada transaksi', style: TextStyle(fontWeight: FontWeight.w700)),
                              Text('Yuk, mulai isi pulsa pertamamu.', style: TextStyle(color: Brand.muted)),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                );
              }
              final t = _items[i] as Map<String, dynamic>;
              final (icon, color) = categoryStyle(t['product']['category'] ?? '');
              return ListTile(
                tileColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
                ),
                title: Text(
                  '${t['product']['name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${t['customer_no']}\n${dateTime(t['created_at'])}',
                  style: const TextStyle(fontSize: 12, color: Brand.muted),
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(rupiah(t['price']), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor(t['status']).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel(t['status']),
                        style: TextStyle(color: statusColor(t['status']), fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionScreen(initial: t))),
              );
            },
          ),
        ),
      ),
    );
  }
}
