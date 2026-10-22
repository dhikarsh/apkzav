import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'format.dart';

/// Isi struk, dipakai untuk cetak dan bagikan teks.
class Receipt {
  Receipt({required this.lines, required this.time, required this.refId});

  final List<(String, String)> lines;
  final String time;
  final String refId;

  factory Receipt.fromTransaction(Map<String, dynamic> trx) {
    final detail = trx['detail'] is Map ? trx['detail'] as Map : const {};
    return Receipt(
      time: dateTime(trx['created_at']),
      refId: trx['ref_id'],
      lines: [
        ('Produk', trx['product']['name'] as String),
        ('Tujuan', trx['customer_no'] as String),
        if (detail['customer_name'] != null) ('Nama', detail['customer_name'].toString()),
        ('SN', (trx['sn'] ?? '-') as String),
        ('Harga', rupiah(trx['price'])),
        ('Status', statusLabel(trx['status'])),
      ],
    );
  }

  String asText() => [
        'STRUK PEMBELIAN',
        time,
        for (final (label, value) in lines) '$label: $value',
        'Ref: $refId',
      ].join('\n');
}

/// Printer thermal Bluetooth 58mm (ESC/POS). Printer harus sudah di-pair di pengaturan Bluetooth HP.
class Printer {
  static const _storage = FlutterSecureStorage();

  static Future<String?> get savedAddress => _storage.read(key: 'printer_mac');
  static Future<String> get header async =>
      await _storage.read(key: 'receipt_header') ?? 'BHOBU RELOAD';
  static Future<String> get footer async =>
      await _storage.read(key: 'receipt_footer') ?? 'Terima kasih';

  static Future<void> saveSettings({String? address, String? header, String? footer}) async {
    if (address != null) await _storage.write(key: 'printer_mac', value: address);
    if (header != null) await _storage.write(key: 'receipt_header', value: header);
    if (footer != null) await _storage.write(key: 'receipt_footer', value: footer);
  }

  static Future<List<BluetoothInfo>> pairedPrinters() async {
    await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw 'Bluetooth belum aktif';
    }
    return PrintBluetoothThermal.pairedBluetooths;
  }

  static Future<void> printReceipt(Receipt receipt) async {
    final address = await savedAddress;
    if (address == null) throw 'Pilih printer dulu di menu Pengaturan';

    await [Permission.bluetoothConnect].request();
    if (!await PrintBluetoothThermal.connectionStatus &&
        !await PrintBluetoothThermal.connect(macPrinterAddress: address)) {
      throw 'Gagal terhubung ke printer';
    }

    final gen = Generator(PaperSize.mm58, await CapabilityProfile.load());
    final bytes = <int>[
      ...gen.reset(),
      ...gen.text(await header,
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2)),
      ...gen.text(receipt.time, styles: const PosStyles(align: PosAlign.center)),
      ...gen.hr(),
      for (final (label, value) in receipt.lines)
        ...gen.row([
          PosColumn(text: label, width: 4),
          PosColumn(text: value, width: 8, styles: const PosStyles(align: PosAlign.right)),
        ]),
      ...gen.hr(),
      ...gen.text('Ref ${receipt.refId}', styles: const PosStyles(align: PosAlign.center)),
      ...gen.text(await footer, styles: const PosStyles(align: PosAlign.center)),
      ...gen.feed(3),
    ];

    if (!await PrintBluetoothThermal.writeBytes(bytes)) {
      throw 'Gagal mengirim ke printer';
    }
  }
}
