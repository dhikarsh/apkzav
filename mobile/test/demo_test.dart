import 'package:flutter_test/flutter_test.dart';
import 'package:ppob_app/api.dart';
import 'package:ppob_app/demo.dart';

void main() {
  Future<Api> loggedIn() async {
    final api = Api(client: DemoBackend(processDelay: const Duration(milliseconds: 10)).client);
    final res = await api.post('/auth/login', {'phone': '081234567890', 'pin': '123456', 'device_name': 't'});
    api.token = res['token'];
    return api;
  }

  test('demo: beli pulsa memotong saldo lalu sukses dengan SN', () async {
    final api = await loggedIn();
    final products = await api.get('/products', {'category': 'Pulsa', 'brand': 'XL'}) as List;
    final product = products.first;

    final res = await api.post('/transactions', {
      'sku': product['sku'],
      'customer_no': '087812345678',
      'pin': '123456',
    });
    expect(res['data']['status'], 'pending');
    expect((await api.get('/me'))['data']['balance'], 1000000 - product['price']);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    final trx = (await api.get('/transactions/${res['data']['ref_id']}'))['data'];
    expect(trx['status'], 'success');
    expect(trx['sn'], isNotNull);
  });

  test('demo: nomor berakhiran 0000 gagal dan saldo kembali', () async {
    final api = await loggedIn();
    await api.post('/transactions', {'sku': 'xl5000', 'customer_no': '087800000000', 'pin': '123456'});
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final list = await api.get('/transactions');
    expect(list['data'].first['status'], 'failed');
    expect((await api.get('/me'))['data']['balance'], 1000000);
  });

  test('demo: PIN salah ditolak', () async {
    final api = await loggedIn();
    expect(
      api.post('/transactions', {'sku': 'xl5000', 'customer_no': '087812345678', 'pin': '000000'}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'PIN salah')),
    );
  });
}
