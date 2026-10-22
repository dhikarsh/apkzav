import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Server tiruan di dalam aplikasi untuk mode demo: meniru API /api/v1 backend dengan data contoh
/// di memori, sehingga semua layar bisa dicoba tanpa server. Data hilang saat aplikasi ditutup.
class DemoBackend {
  DemoBackend({this.processDelay = const Duration(seconds: 3)});

  /// Lama transaksi berstatus "diproses" sebelum sukses, meniru waktu proses supplier.
  final Duration processDelay;

  final _random = Random();
  Map<String, dynamic> _user = {'id': 1, 'name': 'Sobat ZPP', 'phone': '081234567890', 'level': 'Member'};
  String _pin = '123456';
  int _balance = 1000000;
  final List<Map<String, dynamic>> _transactions = [];
  final List<Map<String, dynamic>> _ledger = [];
  final List<Map<String, dynamic>> _deposits = [];
  final Map<String, Map<String, dynamic>> _bills = {};
  int _seq = 0;

  http.Client get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final path = request.url.path.replaceFirst(RegExp(r'^/api/v1'), '');
    final query = request.url.queryParameters;
    final body = request.body.isEmpty ? <String, dynamic>{} : jsonDecode(request.body) as Map<String, dynamic>;

    if (request.method == 'POST' && path == '/auth/login') return _login(body);
    if (request.method == 'POST' && path == '/auth/register') return _register(body);
    if (request.headers['Authorization'] == null) return _json({'message': 'Unauthenticated.'}, 401);

    final trxMatch = RegExp(r'^/transactions/([\w-]+)$').firstMatch(path);
    final payMatch = RegExp(r'^/bills/([\w-]+)/pay$').firstMatch(path);
    return switch ((request.method, path)) {
      ('POST', '/auth/logout') => _json(null, 204),
      ('GET', '/me') => _json({'data': _userJson()}),
      ('POST', '/me/pin') => _changePin(body),
      ('GET', '/categories') => _json(_categories()),
      ('GET', '/products') => _json(_products(query['category'], query['brand'])),
      ('GET', '/transactions') => _json(_page(_transactions)),
      ('POST', '/transactions') => _purchase(body),
      ('POST', '/bills/inquiry') => _inquiry(body),
      ('GET', '/mutations') => _json(_page(_ledger)),
      ('GET', '/deposits') => _json(_page(_deposits)),
      ('POST', '/deposits') => _createDeposit(body),
      ('GET', _) when trxMatch != null => _show(trxMatch.group(1)!),
      ('POST', _) when payMatch != null => _payBill(payMatch.group(1)!, body),
      _ => _json({'message': 'Tidak ditemukan'}, 404),
    };
  }

  // ---- Akun ----

  http.Response _login(Map<String, dynamic> body) {
    final phone = '${body['phone'] ?? ''}';
    if (!RegExp(r'^08\d{8,13}$').hasMatch(phone) || !RegExp(r'^\d{6}$').hasMatch('${body['pin']}')) {
      return _invalid('phone', 'Masukkan nomor HP (08…) dan PIN 6 angka');
    }
    // Mode demo menerima nomor dan PIN apa saja; PIN itu dipakai untuk konfirmasi transaksi.
    _user = {..._user, 'phone': phone};
    _pin = '${body['pin']}';
    return _json({'token': 'demo-token', 'user': _userJson()});
  }

  http.Response _register(Map<String, dynamic> body) {
    final phone = '${body['phone'] ?? ''}';
    if ('${body['name'] ?? ''}'.trim().isEmpty) return _invalid('name', 'Nama wajib diisi');
    if (!RegExp(r'^08\d{8,13}$').hasMatch(phone)) return _invalid('phone', 'Format nomor HP tidak valid');
    if (!RegExp(r'^\d{6}$').hasMatch('${body['pin']}')) return _invalid('pin', 'PIN harus 6 angka');
    _user = {..._user, 'name': '${body['name']}'.trim(), 'phone': phone};
    _pin = '${body['pin']}';
    return _json({'token': 'demo-token', 'user': _userJson()}, 201);
  }

  http.Response _changePin(Map<String, dynamic> body) {
    if (body['old_pin'] != _pin) return _invalid('old_pin', 'PIN lama salah');
    if (!RegExp(r'^\d{6}$').hasMatch('${body['new_pin']}')) return _invalid('new_pin', 'PIN baru harus 6 angka');
    if (body['new_pin'] != body['new_pin_confirmation']) return _invalid('new_pin', 'Konfirmasi PIN tidak sama');
    _pin = '${body['new_pin']}';
    return _json(null, 204);
  }

  Map<String, dynamic> _userJson() => {..._user, 'balance': _balance};

  // ---- Katalog ----

  List<Map<String, dynamic>> _categories() {
    final grouped = <String, Map<String, dynamic>>{};
    for (final p in _catalog) {
      final c = grouped.putIfAbsent(
        p.category,
        () => {'category': p.category, 'is_postpaid': p.postpaid, 'brands': <String>[]},
      );
      if (!(c['brands'] as List).contains(p.brand)) (c['brands'] as List).add(p.brand);
    }
    return grouped.values.toList();
  }

  List<Map<String, dynamic>> _products(String? category, String? brand) => [
    for (final p in _catalog)
      if ((category == null || p.category == category) && (brand == null || p.brand == brand)) p.toJson(),
  ];

  _Product? _find(String? sku) => _catalog.where((p) => p.sku == sku).firstOrNull;

  // ---- Transaksi ----

  http.Response _purchase(Map<String, dynamic> body) {
    if (body['pin'] != _pin) return _invalid('pin', 'PIN salah');
    final product = _find(body['sku']);
    if (product == null || product.postpaid) return _json({'message': 'Produk tidak ditemukan'}, 404);
    final customerNo = '${body['customer_no'] ?? ''}'.trim();
    if (customerNo.length < 4) return _invalid('customer_no', 'Nomor tujuan tidak valid');
    if (_balance < product.price!) return _json({'message': 'Saldo tidak cukup, silakan isi saldo'}, 422);

    final trx = _newTransaction(product, customerNo, product.price!, kind: 'prepaid');
    _process(trx);
    return _json({'data': trx}, 201);
  }

  http.Response _inquiry(Map<String, dynamic> body) {
    final product = _find(body['sku']);
    if (product == null || !product.postpaid) return _json({'message': 'Produk tidak ditemukan'}, 404);
    final customerNo = '${body['customer_no'] ?? ''}'.trim();
    if (customerNo.length < 6) return _invalid('customer_no', 'ID pelanggan tidak valid');

    final amount = 50000 + _random.nextInt(40) * 5000;
    final bill = {
      'ref_id': _refId('INQ'),
      'sku': product.sku,
      'product': product.name,
      'customer_no': customerNo,
      'customer_name': _names[_random.nextInt(_names.length)],
      'price': amount + 2500,
      'detail': {'tagihan': amount, 'admin': 2500, 'periode': _period()},
      'expires_at': DateTime.now().add(const Duration(minutes: 30)).toUtc().toIso8601String(),
    };
    _bills[bill['ref_id'] as String] = bill;
    return _json(bill);
  }

  http.Response _payBill(String refId, Map<String, dynamic> body) {
    if (body['pin'] != _pin) return _invalid('pin', 'PIN salah');
    final bill = _bills.remove(refId);
    if (bill == null) return _json({'message': 'Tagihan sudah kedaluwarsa, cek ulang'}, 404);
    final price = bill['price'] as int;
    if (_balance < price) {
      _bills[refId] = bill;
      return _json({'message': 'Saldo tidak cukup, silakan isi saldo'}, 422);
    }

    final trx = _newTransaction(_find(bill['sku'])!, bill['customer_no'], price, kind: 'postpaid')
      ..['detail'] = {'customer_name': bill['customer_name'], ...bill['detail'] as Map};
    _process(trx);
    return _json({'data': trx}, 201);
  }

  http.Response _show(String refId) {
    final trx = _transactions.where((t) => t['ref_id'] == refId).firstOrNull;
    return trx == null ? _json({'message': 'Tidak ditemukan'}, 404) : _json({'data': trx});
  }

  Map<String, dynamic> _newTransaction(_Product product, String customerNo, int price, {required String kind}) {
    _addLedger(-price, 'purchase', '${product.name} ke $customerNo');
    final trx = <String, dynamic>{
      'ref_id': _refId('TRX'),
      'kind': kind,
      'status': 'pending',
      'product': {'sku': product.sku, 'name': product.name, 'brand': product.brand, 'category': product.category},
      'customer_no': customerNo,
      'price': price,
      'sn': null,
      'message': 'Transaksi sedang diproses',
      'detail': null,
      'created_at': _now(),
      'finished_at': null,
    };
    _transactions.insert(0, trx);
    return trx;
  }

  /// Selesaikan transaksi setelah jeda. Nomor tujuan berakhiran 0000 sengaja dibuat gagal
  /// agar alur pengembalian saldo bisa dicoba.
  void _process(Map<String, dynamic> trx) {
    Timer(processDelay, () {
      trx['finished_at'] = _now();
      if ((trx['customer_no'] as String).endsWith('0000')) {
        trx['status'] = 'failed';
        trx['message'] = 'Nomor tujuan salah atau tidak aktif';
        _addLedger(trx['price'] as int, 'refund', 'Refund ${trx['ref_id']}');
        return;
      }
      trx['status'] = 'success';
      trx['message'] = 'Transaksi Sukses';
      trx['sn'] = trx['product']['category'] == 'PLN'
          ? List.generate(5, (_) => (_random.nextInt(9000) + 1000).toString()).join('-')
          : List.generate(20, (_) => _random.nextInt(10)).join();
    });
  }

  // ---- Saldo ----

  http.Response _createDeposit(Map<String, dynamic> body) {
    final amount = body['amount'] is int ? body['amount'] as int : int.tryParse('${body['amount']}') ?? 0;
    if (amount < 10000) return _invalid('amount', 'Minimal deposit Rp 10.000');
    final code = 100 + _random.nextInt(900);
    final deposit = <String, dynamic>{
      'id': _deposits.length + 1,
      'amount': amount,
      'unique_code': code,
      'total': amount + code,
      'status': 'pending',
      'bank_info': 'BCA 1234567890 a.n. ZPP Reload (demo)',
      'created_at': _now(),
      'paid_at': null,
    };
    _deposits.insert(0, deposit);
    // Di mode demo deposit dianggap dibayar & dikonfirmasi admin setelah 10 detik.
    Timer(const Duration(seconds: 10), () {
      deposit['status'] = 'paid';
      deposit['paid_at'] = _now();
      _addLedger(deposit['total'] as int, 'deposit', 'Deposit #${deposit['id']}');
    });
    return _json(deposit, 201);
  }

  void _addLedger(int amount, String type, String description) {
    _balance += amount;
    _ledger.insert(0, {
      'id': _ledger.length + 1,
      'amount': amount,
      'balance_after': _balance,
      'type': type,
      'description': description,
      'created_at': _now(),
    });
  }

  // ---- Bantuan ----

  Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {
    'data': items,
    'meta': {'current_page': 1, 'last_page': 1, 'total': items.length},
  };

  http.Response _json(Object? data, [int status = 200]) => http.Response(
    data == null ? '' : jsonEncode(data),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  http.Response _invalid(String field, String message) => _json({
    'message': message,
    'errors': {
      field: [message],
    },
  }, 422);

  String _refId(String prefix) => '$prefix${DateTime.now().millisecondsSinceEpoch}${++_seq}';

  String _now() => DateTime.now().toUtc().toIso8601String();

  String _period() {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MEI', 'JUN', 'JUL', 'AGU', 'SEP', 'OKT', 'NOV', 'DES'];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }

  static const _names = ['BUDI SANTOSO', 'SITI RAHAYU', 'AGUS PRASETYO', 'DEWI LESTARI', 'RINA WATI'];
}

class _Product {
  const _Product(this.sku, this.name, this.category, this.brand, this.price, {this.postpaid = false});

  final String sku;
  final String name;
  final String category;
  final String brand;
  final int? price;
  final bool postpaid;

  Map<String, dynamic> toJson() => {
    'sku': sku,
    'name': name,
    'category': category,
    'brand': brand,
    'type': 'Umum',
    'is_postpaid': postpaid,
    'price': price,
    'description': postpaid ? 'Harga final muncul setelah cek tagihan' : 'Proses otomatis 24 jam',
  };
}

/// Harga contoh, kira-kira setara harga pasar (modal + markup member).
final List<_Product> _catalog = [
  for (final (brand, code, extra) in [
    ('TELKOMSEL', 'tsel', 1650),
    ('INDOSAT', 'isat', 1450),
    ('XL', 'xl', 1350),
    ('AXIS', 'axis', 1300),
    ('TRI', 'tri', 1250),
    ('SMARTFREN', 'sf', 1400),
  ])
    for (final nominal in [5000, 10000, 20000, 25000, 50000, 100000])
      _Product('$code$nominal', '$brand ${_k(nominal)}', 'Pulsa', brand, nominal + extra),
  for (final (brand, code, packs) in [
    (
      'TELKOMSEL',
      'tseldata',
      [('Internet 2GB 7 Hari', 18500), ('Internet 8GB 30 Hari', 62000), ('OMG 15GB 30 Hari', 98000)],
    ),
    (
      'INDOSAT',
      'isatdata',
      [('Freedom 3GB 15 Hari', 21500), ('Freedom 10GB 30 Hari', 52000), ('Freedom 25GB 30 Hari', 89000)],
    ),
    ('XL', 'xldata', [('Xtra Combo 6GB', 33500), ('Xtra Combo 12GB', 55000), ('Xtra Combo 25GB', 87000)]),
  ])
    for (final (i, (name, price)) in packs.indexed) _Product('$code$i', '$brand $name', 'Data', brand, price),
  for (final nominal in [20000, 50000, 100000, 200000, 500000])
    _Product('pln$nominal', 'Token PLN ${_k(nominal)}', 'PLN', 'PLN', nominal + 1750),
  for (final (brand, code) in [('DANA', 'dana'), ('OVO', 'ovo'), ('GOPAY', 'gopay'), ('SHOPEEPAY', 'spay')])
    for (final nominal in [20000, 50000, 100000])
      _Product('$code$nominal', '$brand ${_k(nominal)}', 'E-Money', brand, nominal + 1200),
  for (final (dm, price) in [(86, 23500), (172, 46000), (257, 68500), (514, 136000)])
    _Product('ml$dm', 'Mobile Legends $dm Diamond', 'Games', 'MOBILE LEGENDS', price),
  for (final (dm, price) in [(70, 10500), (140, 20500), (355, 50000), (720, 99000)])
    _Product('ff$dm', 'Free Fire $dm Diamond', 'Games', 'FREE FIRE', price),
  for (final nominal in [10000, 20000, 50000])
    _Product('gplay$nominal', 'Google Play ${_k(nominal)}', 'Voucher', 'GOOGLE PLAY', nominal + 1500),
  const _Product('plnpasca', 'PLN Pascabayar', 'PLN Pascabayar', 'PLN PASCABAYAR', null, postpaid: true),
  const _Product('bpjs', 'BPJS Kesehatan', 'BPJS', 'BPJS KESEHATAN', null, postpaid: true),
  const _Product('indihome', 'IndiHome', 'Internet', 'INDIHOME', null, postpaid: true),
  const _Product('pdam', 'PDAM', 'PDAM', 'PDAM', null, postpaid: true),
];

String _k(int nominal) => nominal.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
