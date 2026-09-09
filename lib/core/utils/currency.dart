import 'package:intl/intl.dart';

final _formatter = NumberFormat.decimalPattern('en');

String formatAmount(double amount) => _formatter.format(amount);
