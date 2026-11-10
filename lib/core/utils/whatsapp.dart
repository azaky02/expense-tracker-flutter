import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens WhatsApp on [digits] (international, no +) with [message] typed in, ready to send.
Future<bool> openWhatsApp(BuildContext context, String digits, String message) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(Uri.https('wa.me', '/$digits', {'text': message}), mode: LaunchMode.externalApplication);
  if (!ok) messenger.showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب.')));
  return ok;
}
