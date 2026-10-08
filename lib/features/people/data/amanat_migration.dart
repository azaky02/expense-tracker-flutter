import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import 'ledger_repository.dart';

const _flag = 'amanat-to-ledger-v1';

/// v1.1 recorded amanat as transactions (trustIn / trustOut + a beneficiary name). V2 replaces that
/// with People + the Shared Ledger: each such transaction becomes a confirmed one-sided ledger entry
/// with that person, queued for the server, and the old transaction is deleted (the delete syncs).
/// Runs once; ids are deterministic so two devices migrating the same data converge.
Future<void> migrateAmanatToLedger(AppDatabase db) async {
  final done = await (db.select(db.meta)..where((m) => m.key.equals(_flag))).getSingleOrNull();
  if (done != null) return;

  final legacy = await (db.select(db.transactions)
        ..where((t) => t.type.isIn([TransactionType.trustIn.name, TransactionType.trustOut.name])))
      .get();

  await db.transaction(() async {
    final people = <String, int>{};
    for (final t in legacy) {
      final name = t.beneficiaryName?.trim();
      if (name == null || name.isEmpty) continue;
      final personId = people[name] ??= await _personFor(db, name);
      final entryId = t.syncId ?? newEntryId();
      final exists = await (db.select(db.ledgerEntries)..where((e) => e.entryId.equals(entryId))).getSingleOrNull();
      if (exists == null) {
        final direction = t.type == TransactionType.trustIn ? LedgerDirection.received : LedgerDirection.gave;
        final person = await (db.select(db.people)..where((p) => p.id.equals(personId))).getSingle();
        await db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
              entryId: entryId,
              personId: Value(personId),
              // Money handed back is a settlement of what was held, so the balance nets correctly.
              kind: t.type == TransactionType.trustOut ? LedgerKind.settlement : LedgerKind.other,
              direction: direction,
              amount: t.amount,
              date: t.date,
              description: Value(t.note),
              status: LedgerStatus.confirmed,
              counterpartName: Value(name),
              queued: const Value(true),
              createdAt: Value(t.createdAt),
            ));
        final d = t.date;
        await db.into(db.ledgerOutbox).insert(LedgerOutboxCompanion.insert(
              entryId: entryId,
              op: 'create',
              payload: jsonEncode({
                'op': 'create',
                'id': entryId,
                'kind': t.type == TransactionType.trustOut ? 'SETTLEMENT' : 'OTHER',
                'direction': direction.name.toUpperCase(),
                'amount': t.amount,
                'currency': 'EGP',
                'date': '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                if (t.note != null && t.note!.isNotEmpty) 'description': t.note,
                'personId': person.syncId,
                'counterpartName': name,
              }),
            ));
      }
      await (db.delete(db.transactions)..where((x) => x.id.equals(t.id))).go();
    }
    await db.into(db.meta).insert(MetaCompanion.insert(key: _flag, value: 'true'));
  });
}

Future<int> _personFor(AppDatabase db, String name) async {
  final existing = await (db.select(db.people)..where((p) => p.name.equals(name))..limit(1)).getSingleOrNull();
  if (existing != null) return existing.id;
  final hash = await Sha256().hash(utf8.encode(name));
  final syncId = 'amanat-${hash.bytes.take(12).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  return db.into(db.people).insert(PeopleCompanion.insert(name: name, syncId: Value(syncId)));
}
