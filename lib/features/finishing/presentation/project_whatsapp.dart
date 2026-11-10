import '../../people/presentation/whatsapp_message.dart';
import '../domain/finishing_rules.dart';

String _money(double v) => v.toStringAsFixed(2);

/// The project balance from the client's side of the message.
String projectBalanceText(double net) {
  if (net > 0.005) return 'رصيد لك عندي';
  if (net < -0.005) return 'مستحق لي عندك';
  return 'الحساب متسوي';
}

/// Same layout as the people message, plus the project name.
String buildProjectWhatsAppMessage({
  required String clientName,
  required String projectName,
  required FinishingKind kind,
  required double amount,
  required DateTime date,
  required double previousBalance,
  required double currentBalance,
  String? description,
  String? trade,
}) {
  final (type, details) = switch (kind) {
    FinishingKind.clientAdvance => ('استلام دفعة', 'استلمت منك مبلغ ${_money(amount)} جنيه لحساب المشروع.'),
    FinishingKind.returnCustody => ('إرجاع مبلغ', 'رجّعتلك مبلغ ${_money(amount)} جنيه من حساب المشروع.'),
    _ => ('مصروف على المشروع', 'تم صرف مبلغ ${_money(amount)} جنيه على المشروع${trade == null ? '' : ' (بند $trade)'}.'),
  };
  return buildWhatsAppNotice(
    personName: clientName,
    typeLabel: type,
    amount: amount,
    date: date,
    details: details,
    notes: description,
    previousBalance: previousBalance,
    currentBalance: currentBalance,
    describe: projectBalanceText,
    extraHeader: ['🏗️ المشروع: $projectName'],
  );
}
