import 'package:flutter_test/flutter_test.dart';
import 'package:ppob_app/format.dart';
import 'package:ppob_app/printer.dart';

void main() {
  test('format rupiah', () {
    expect(rupiah(11600).replaceAll(' ', ' '), 'Rp 11.600');
  });

  test('receipt text', () {
    final receipt = Receipt.fromTransaction({
      'ref_id': 'TRX1',
      'status': 'success',
      'customer_no': '087800001234',
      'price': 11600,
      'sn': 'SN123',
      'created_at': '2026-10-22T03:00:00Z',
      'product': {'name': 'XL 10.000'},
      'detail': null,
    });
    expect(receipt.asText(), contains('SN: SN123'));
    expect(receipt.asText(), contains('Tujuan: 087800001234'));
  });
}
