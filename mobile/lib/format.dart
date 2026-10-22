import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

String rupiah(num? value) => _rupiah.format(value ?? 0);

String dateTime(String? iso) =>
    iso == null ? '-' : _dateTime.format(DateTime.parse(iso).toLocal());

String statusLabel(String status) => switch (status) {
      'success' => 'Sukses',
      'failed' => 'Gagal',
      _ => 'Diproses',
    };

Color statusColor(String status) => switch (status) {
      'success' => Colors.green,
      'failed' => Colors.red,
      _ => Colors.orange,
    };

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error.toString())));
}
