import 'package:intl/intl.dart';

String currency(num n) => NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    ).format(n);

String formatDate(DateTime d) =>
    DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(d);

String formatDayDate(String ymd) {
  final d = DateTime.parse('${ymd}T12:00:00');
  return DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_BR').format(d);
}

String lastOrThisSunday() {
  final d = DateTime.now();
  final sunday = d.subtract(Duration(days: d.weekday % 7));
  return DateFormat('yyyy-MM-dd').format(sunday);
}
