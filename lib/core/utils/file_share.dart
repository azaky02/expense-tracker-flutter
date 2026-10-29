import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../security/lock_provider.dart';

const pdfMime = 'application/pdf';
const xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Hands a generated file to the user: the share sheet (WhatsApp, e-mail, …) on Android/iOS, a
/// download in the browser (PWA), where sharing files is not reliably supported.
Future<void> shareFile(
  BuildContext context, {
  required Uint8List bytes,
  required String name,
  required String mimeType,
  String? subject,
  String? text,
}) async {
  final file = XFile.fromData(bytes, name: name, mimeType: mimeType);
  if (kIsWeb) {
    await file.saveTo(name);
    return;
  }
  final box = context.findRenderObject() as RenderBox?;
  await LockNotifier.runWithoutLock(
    () => SharePlus.instance.share(
      ShareParams(
        files: [file],
        fileNameOverrides: [name],
        subject: subject,
        text: text,
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    ),
  );
}

Future<void> shareTextFile(BuildContext context, {required String content, required String name, String? subject}) =>
    shareFile(context, bytes: Uint8List.fromList(utf8.encode(content)), name: name, mimeType: 'application/octet-stream', subject: subject);
