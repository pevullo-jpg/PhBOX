String formatAmount(double value) {
  final sign = value < 0 ? '-' : '';
  final number = value.abs().toStringAsFixed(2).replaceAll('.', ',');
  return '$sign€$number';
}

String formatDateShort(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final y = date.year.toString();
  return '$d/$m/$y';
}

String formatDateFull(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final y = date.year.toString();
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '$d/$m/$y $hh:$mm';
}

String formatPercent(double value) {
  return '${value.toStringAsFixed(1)}%';
}
