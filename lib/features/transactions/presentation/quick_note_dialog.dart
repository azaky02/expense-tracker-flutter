import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

Future<String?> showQuickNoteDialog(BuildContext context, String initialNote) {
  final controller = TextEditingController(text: initialNote);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('transactions.quickNote'.tr()),
      content: TextField(controller: controller, maxLines: 3, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text('common.save'.tr()),
        ),
      ],
    ),
  );
}
