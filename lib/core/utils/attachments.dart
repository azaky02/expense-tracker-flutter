import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _attachmentsDirName = 'attachments';

/// Copies a picked image (camera/gallery temp path) into persistent app-support storage
/// (excluded from iCloud backup on iOS, since these may be financial receipt photos).
/// One attachment max per transaction — callers should deleteAttachment() the old one first
/// when replacing.
Future<String> persistAttachment(String pickedPath) async {
  final supportDir = await getApplicationSupportDirectory();
  final attachmentsDir = Directory(p.join(supportDir.path, _attachmentsDirName));
  if (!await attachmentsDir.exists()) {
    await attachmentsDir.create(recursive: true);
  }
  final extension = p.extension(pickedPath);
  final destination = p.join(
    attachmentsDir.path,
    '${DateTime.now().microsecondsSinceEpoch}$extension',
  );
  await File(pickedPath).copy(destination);
  return destination;
}

Future<void> deleteAttachment(String? path) async {
  if (path == null) return;
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
