import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../session.dart';

class MutationScreen extends StatefulWidget {
  const MutationScreen({super.key});

  @override
  State<MutationScreen> createState() => _MutationScreenState();
}

class _MutationScreenState extends State<MutationScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<Session>().api.get('/mutations');
      setState(() => _items = res['data']);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mutasi saldo')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final m = _items[i] as Map<String, dynamic>;
                  final amount = m['amount'] as num;
                  return ListTile(
                    title: Text(m['description']),
                    subtitle: Text('${dateTime(m['created_at'])} · saldo ${rupiah(m['balance_after'])}'),
                    trailing: Text(
                      '${amount > 0 ? '+' : '-'}${rupiah(amount.abs())}',
                      style: TextStyle(
                          color: amount > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
