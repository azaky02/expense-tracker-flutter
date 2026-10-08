import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/tables.dart';
import 'sync_api.dart';
import 'sync_schema.dart';

const _cursorKey = 'sync_cursor';
const _userKey = 'sync_user_id';
const _lastSyncKey = 'sync_last_at';
const _ledgerCursorKey = 'sync_ledger_cursor';
const _notifCursorKey = 'sync_notification_cursor';
const _chunk = 1500; // the server accepts at most 2000 records per entity per request

class SyncReport {
  const SyncReport({this.pushed = 0, this.pulled = 0, this.skipped = 0, this.ledgerErrors = 0});
  final int pushed;
  final int pulled;
  /// Ledger operations the server refused (e.g. an entry with yourself); the local copy is corrected.
  final int ledgerErrors;
  /// Remote records that referenced something this device does not have (kept out, not lost on the server).
  final int skipped;
}

typedef _Json = Map<String, dynamic>;

String _iso(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true).toIso8601String();
int _secs(String iso) => DateTime.parse(iso).millisecondsSinceEpoch ~/ 1000;
String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime _parseYmd(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// Pushes local changes and pulls remote ones. Local writes are tracked by SQLite triggers
/// (see sync_schema.dart); this class only reads the `dirty` rows and tombstones, talks to the
/// server, and applies the answer inside one DB transaction with the trigger guard raised.
class SyncService {
  SyncService(this._db, this._api);
  final AppDatabase _db;
  final SyncApi _api;

  Future<String?> _meta(String key) async =>
      (await (_db.select(_db.meta)..where((m) => m.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _setMeta(String key, String value) =>
      _db.into(_db.meta).insertOnConflictUpdate(MetaCompanion.insert(key: key, value: value));

  Future<void> _delMeta(String key) =>
      (_db.delete(_db.meta)..where((m) => m.key.equals(key))).go();

  static Future<String?> lastSyncAt(AppDatabase db) async =>
      (await (db.select(db.meta)..where((m) => m.key.equals(_lastSyncKey))).getSingleOrNull())?.value;

  /// First sign-in on this device (or switching to another account): everything local has to be
  /// uploaded and the pull cursor starts over.
  Future<void> prepareForAccount(String userId) async {
    final previous = await _meta(_userKey);
    if (previous == userId) return;
    await _db.transaction(() async {
      for (final t in syncTables) {
        await _db.customStatement('UPDATE ${t.table} SET dirty = 1');
      }
      await _db.customStatement('DELETE FROM sync_tombstones');
      if (previous != null) {
        // The ledger replica belongs to the other account (its server copy stays there).
        await _db.customStatement('DELETE FROM ledger_outbox');
        await _db.customStatement('DELETE FROM ledger_entries');
        await _db.customStatement('DELETE FROM app_notifications');
      }
      await _setMeta(_cursorKey, '0');
      await _setMeta(_ledgerCursorKey, '0');
      await _setMeta(_notifCursorKey, '0');
      await _setMeta(_userKey, userId);
    });
  }

  /// Removes every synced row from this device (used by "sign out and wipe") and re-seeds defaults.
  Future<void> wipeLocalData() async {
    await _db.transaction(() async {
      await _setMeta(syncApplyingKey, '1');
      await _db.customStatement('DELETE FROM ledger_entries');
      for (final t in syncTables.reversed) {
        await _db.customStatement('DELETE FROM ${t.table}');
      }
      await _db.customStatement('DELETE FROM sync_tombstones');
      await _db.customStatement('DELETE FROM ledger_outbox');
      await _db.customStatement('DELETE FROM ledger_entries');
      await _db.customStatement('DELETE FROM app_notifications');
      await _delMeta(syncApplyingKey);
      for (final k in [_cursorKey, _ledgerCursorKey, _notifCursorKey, _userKey, _lastSyncKey, 'seed-completed-v1']) {
        await _delMeta(k);
      }
    });
  }

  Future<SyncReport> run() async {
    var cursor = int.tryParse(await _meta(_cursorKey) ?? '') ?? 0;

    final outbox = await _collect();
    var pushedCount = outbox.records.values.fold<int>(0, (a, l) => a + l.length);
    final pending = {for (final e in outbox.records.entries) e.key: List<_Json>.from(e.value)};

    var ledgerCursor = int.tryParse(await _meta(_ledgerCursorKey) ?? '') ?? 0;
    var notifCursor = int.tryParse(await _meta(_notifCursorKey) ?? '') ?? 0;
    final ops = await _db.select(_db.ledgerOutbox).get();
    final readIds = await (_db.select(_db.appNotifications)..where((n) => n.readPending.equals(true))).get();
    var firstRound = true;
    var ledgerResults = <_Json>[];
    final ledgerEntries = <_Json>[];
    final notifications = <_Json>[];

    final pulled = <String, List<_Json>>{};
    while (true) {
      final changes = <String, List<_Json>>{};
      for (final e in pending.entries) {
        if (e.value.isEmpty) continue;
        final n = e.value.length < _chunk ? e.value.length : _chunk;
        changes[e.key] = e.value.sublist(0, n);
        e.value.removeRange(0, n);
      }
      final res = await _api.sync({
        'cursor': cursor,
        'changes': changes,
        'ledgerCursor': ledgerCursor,
        'notificationCursor': notifCursor,
        // Ops and read receipts go with the first request only; they are idempotent on the server.
        if (firstRound) 'ledgerOps': [for (final o in ops) jsonDecode(o.payload)],
        if (firstRound) 'readNotifications': [for (final n in readIds) n.id],
      });
      if (firstRound) ledgerResults = ((res['ledgerResults'] as List?) ?? const []).cast<_Json>();
      firstRound = false;
      cursor = (res['cursor'] as num).toInt();
      final ledger = res['ledger'] as _Json?;
      if (ledger != null) {
        ledgerEntries.addAll((ledger['entries'] as List).cast<_Json>());
        ledgerCursor = (ledger['cursor'] as num).toInt();
      }
      final notif = res['notifications'] as _Json?;
      if (notif != null) {
        notifications.addAll((notif['items'] as List).cast<_Json>());
        notifCursor = (notif['cursor'] as num).toInt();
      }
      (res['changes'] as Map<String, dynamic>).forEach((entity, list) {
        pulled.putIfAbsent(entity, () => []).addAll((list as List).cast<_Json>());
      });
      final hasMore = res['hasMore'] == true;
      final morePending = pending.values.any((l) => l.isNotEmpty);
      if (!hasMore && !morePending) break;
    }

    var skipped = 0;
    var pulledCount = 0;
    var ledgerErrors = 0;
    await _db.transaction(() async {
      await _setMeta(syncApplyingKey, '1');
      final stats = await _apply(pulled);
      skipped = stats.skipped;
      pulledCount = stats.applied;
      // Only rows that did not change again while we were talking to the server become clean.
      for (final p in outbox.pushedRows) {
        await _db.customUpdate(
          'UPDATE ${p.table} SET dirty = 0 WHERE id = ? AND updated_at = ?',
          variables: [Variable.withInt(p.id), Variable.withInt(p.updatedAt)],
        );
      }
      if (outbox.tombstoneIds.isNotEmpty) {
        await (_db.delete(_db.syncTombstones)..where((t) => t.id.isIn(outbox.tombstoneIds))).go();
      }
      await _setMeta(_cursorKey, '$cursor');
      await _setMeta(_lastSyncKey, DateTime.now().toUtc().toIso8601String());
      await _delMeta(syncApplyingKey);

      // Ledger: outside the trigger guard on purpose, so people created/linked here sync too.
      ledgerErrors = await _applyLedgerResults(ops, ledgerResults);
      for (final e in ledgerEntries) {
        await _applyLedgerEntry(e);
      }
      for (final n in notifications) {
        await _applyNotification(n);
      }
      if (readIds.isNotEmpty) {
        await (_db.update(_db.appNotifications)..where((n) => n.id.isIn(readIds.map((r) => r.id))))
            .write(const AppNotificationsCompanion(readPending: Value(false)));
      }
      await _setMeta(_ledgerCursorKey, '$ledgerCursor');
      await _setMeta(_notifCursorKey, '$notifCursor');
    });
    return SyncReport(
      pushed: pushedCount + ops.length,
      pulled: pulledCount + ledgerEntries.length,
      skipped: skipped,
      ledgerErrors: ledgerErrors,
    );
  }

  // ───────────────────────────── push ─────────────────────────────

  Future<_Outbox> _collect() async {
    final banks = await _db.select(_db.banks).get();
    final cats = await _db.select(_db.categories).get();
    final cards = await _db.select(_db.cards).get();
    final bankSync = {for (final b in banks) b.id: b.syncId};
    final catSync = {for (final c in cats) c.id: c.syncId};
    final cardSync = {for (final c in cards) c.id: c.syncId};

    final records = <String, List<_Json>>{};
    final rows = <_PushedRow>[];
    void add(String entity, String table, int id, int updatedAt, _Json json) {
      (records[entity] ??= []).add({...json, 'updatedAt': _iso(updatedAt)});
      rows.add(_PushedRow(table, id, updatedAt));
    }

    for (final b in banks.where((b) => b.dirty && b.syncId != null)) {
      add('banks', 'banks', b.id, b.updatedAt, {
        'id': b.syncId, 'name': b.name, 'logoUri': b.logoUri, 'isCustom': b.isCustom,
      });
    }
    for (final c in cats.where((c) => c.dirty && c.syncId != null)) {
      final parent = c.parentCategoryId == null ? null : catSync[c.parentCategoryId];
      if (c.parentCategoryId != null && parent == null) continue;
      add('categories', 'categories', c.id, c.updatedAt, {
        'id': c.syncId, 'parentId': parent, 'name': c.name, 'icon': c.icon, 'color': c.color,
        'type': c.type.name, 'isDefault': c.isDefault,
      });
    }
    for (final c in cards.where((c) => c.dirty && c.syncId != null)) {
      final bank = bankSync[c.bankId];
      if (bank == null) continue;
      add('cards', 'cards', c.id, c.updatedAt, {
        'id': c.syncId, 'bankId': bank, 'cardType': c.cardType.name,
        'cardCategory': c.cardCategory.name, 'nickname': c.nickname, 'last4Digits': c.last4Digits,
        'dueDateDay': c.dueDateDay, 'statementDateDay': c.statementDateDay,
        'creditLimit': c.creditLimit, 'color': c.color, 'isActive': c.isActive,
      });
    }
    for (final b in await (_db.select(_db.beneficiaries)..where((b) => b.dirty.equals(true))).get()) {
      add('beneficiaries', 'beneficiaries', b.id, b.updatedAt, {
        'name': b.name, 'lastUsedAt': b.lastUsedAt.toUtc().toIso8601String(),
      });
    }
    for (final t in await (_db.select(_db.transactions)..where((t) => t.dirty.equals(true))).get()) {
      final cat = catSync[t.categoryId];
      final card = t.cardId == null ? null : cardSync[t.cardId];
      if (t.syncId == null || cat == null || (t.cardId != null && card == null)) continue;
      add('transactions', 'transactions', t.id, t.updatedAt, {
        'id': t.syncId, 'amount': t.amount, 'type': t.type.name, 'categoryId': cat,
        'paymentMethodType': t.paymentMethodType.name, 'cardId': card, 'date': _ymd(t.date),
        'note': t.note, 'beneficiaryName': t.beneficiaryName,
        'createdAt': t.createdAt.toUtc().toIso8601String(),
      });
    }
    for (final b in await (_db.select(_db.categoryBudgets)..where((b) => b.dirty.equals(true))).get()) {
      final cat = catSync[b.categoryId];
      if (cat == null) continue;
      add('categoryBudgets', 'category_budgets', b.id, b.updatedAt, {
        'categoryId': cat, 'monthlyLimit': b.monthlyLimit, 'isEnabled': b.isEnabled,
      });
    }

    for (final p in await (_db.select(_db.people)..where((p) => p.dirty.equals(true))).get()) {
      if (p.syncId == null) continue;
      add('people', 'people', p.id, p.updatedAt, {
        'id': p.syncId, 'name': p.name, 'phone': p.phone, 'email': p.email, 'notes': p.notes,
        'linkedUserId': p.linkedUserId,
      });
    }

    final tombstones = await _db.select(_db.syncTombstones).get();
    for (final t in tombstones) {
      final keyName = switch (t.entity) {
        'beneficiaries' => 'name',
        'categoryBudgets' => 'categoryId',
        _ => 'id',
      };
      (records[t.entity] ??= []).add({keyName: t.key, 'updatedAt': _iso(t.deletedAt), 'deletedAt': _iso(t.deletedAt)});
    }
    return _Outbox(records, rows, tombstones.map((t) => t.id).toList());
  }

  // ───────────────────────────── pull ─────────────────────────────

  Future<({int applied, int skipped})> _apply(Map<String, List<_Json>> pulled) async {
    var applied = 0;
    var skipped = 0;
    List<_Json> live(String e) => (pulled[e] ?? const []).where((r) => r['deletedAt'] == null).toList();
    List<_Json> dead(String e) => (pulled[e] ?? const []).where((r) => r['deletedAt'] != null).toList();

    // Upserts, parents first.
    for (final r in live('banks')) {
      if (await _upsertBank(r)) applied++;
    }
    final cats = live('categories')..sort((a, b) => (a['parentId'] == null ? 0 : 1) - (b['parentId'] == null ? 0 : 1));
    for (final r in cats) {
      final ok = await _upsertCategory(r);
      if (ok == null) {
        skipped++;
      } else if (ok) {
        applied++;
      }
    }
    for (final r in live('cards')) {
      final ok = await _upsertCard(r);
      if (ok == null) {
        skipped++;
      } else if (ok) {
        applied++;
      }
    }
    for (final r in live('beneficiaries')) {
      if (await _upsertBeneficiary(r)) applied++;
    }
    for (final r in live('transactions')) {
      final ok = await _upsertTransaction(r);
      if (ok == null) {
        skipped++;
      } else if (ok) {
        applied++;
      }
    }
    for (final r in live('people')) {
      if (await _upsertPerson(r)) applied++;
    }
    for (final r in live('categoryBudgets')) {
      final ok = await _upsertBudget(r);
      if (ok == null) {
        skipped++;
      } else if (ok) {
        applied++;
      }
    }

    // Deletes, children first.
    for (final r in dead('categoryBudgets')) {
      if (await _deleteBudget(r)) applied++;
    }
    for (final r in dead('transactions')) {
      if (await _deleteBySyncId('transactions', r)) applied++;
    }
    for (final r in dead('beneficiaries')) {
      final local = await (_db.select(_db.beneficiaries)..where((b) => b.name.equals(r['name'] as String))).getSingleOrNull();
      if (local != null && local.updatedAt <= _secs(r['deletedAt'] as String)) {
        await (_db.delete(_db.beneficiaries)..where((b) => b.id.equals(local.id))).go();
        applied++;
      }
    }
    for (final r in dead('people')) {
      final id = r['id'] as String;
      final local = await (_db.select(_db.people)..where((p) => p.syncId.equals(id))).getSingleOrNull();
      final used = local == null
          ? true
          : (await (_db.select(_db.ledgerEntries)..where((e) => e.personId.equals(local.id))..limit(1)).get()).isNotEmpty;
      // A person with ledger history on this device is kept (history is never dropped).
      if (!used && local.updatedAt <= _secs(r['deletedAt'] as String)) {
        await (_db.delete(_db.people)..where((p) => p.id.equals(local.id))).go();
        applied++;
      }
    }
    for (final r in dead('cards')) {
      if (await _deleteBySyncId('cards', r)) applied++;
    }
    final deadCats = dead('categories')..sort((a, b) => (b['parentId'] == null ? 0 : 1) - (a['parentId'] == null ? 0 : 1));
    for (final r in deadCats) {
      if (await _deleteBySyncId('categories', r)) applied++;
    }
    for (final r in dead('banks')) {
      if (await _deleteBySyncId('banks', r)) applied++;
    }
    return (applied: applied, skipped: skipped);
  }

  /// A remote version replaces the local one only if it is strictly newer (last writer wins).
  bool _newer(int? localUpdatedAt, _Json remote) =>
      localUpdatedAt == null || _secs(remote['updatedAt'] as String) > localUpdatedAt;

  Future<bool> _upsertPerson(_Json r) async {
    final id = r['id'] as String;
    final local = await (_db.select(_db.people)..where((p) => p.syncId.equals(id))).getSingleOrNull();
    if (!_newer(local?.updatedAt, r)) return false;
    final comp = PeopleCompanion(
      syncId: Value(id),
      name: Value(r['name'] as String),
      phone: Value(r['phone'] as String?),
      email: Value(r['email'] as String?),
      notes: Value(r['notes'] as String?),
      linkedUserId: Value(r['linkedUserId'] as String?),
      updatedAt: Value(_secs(r['updatedAt'] as String)),
      dirty: const Value(false),
    );
    if (local == null) {
      await _db.into(_db.people).insert(comp);
    } else {
      await (_db.update(_db.people)..where((p) => p.id.equals(local.id))).write(comp);
    }
    return true;
  }

  // ───────────────────────────── ledger ─────────────────────────────

  /// Drops the sent ops; where the server refused one, corrects the optimistic local copy.
  Future<int> _applyLedgerResults(List<LedgerOutboxItem> sent, List<_Json> results) async {
    if (sent.isEmpty) return 0;
    var errors = 0;
    for (final r in results) {
      if (r['ok'] == true) continue;
      errors++;
      final id = r['id'] as String;
      final status = r['status'] as String?;
      if (r['op'] == 'create' || r['error'] == 'not_found') {
        await (_db.delete(_db.ledgerEntries)..where((e) => e.entryId.equals(id))).go();
      } else if (status != null) {
        await (_db.update(_db.ledgerEntries)..where((e) => e.entryId.equals(id))).write(LedgerEntriesCompanion(
              status: Value(_enum(LedgerStatus.values, status.toLowerCase(), LedgerStatus.pending)),
              queued: const Value(false),
            ));
      }
    }
    await (_db.delete(_db.ledgerOutbox)..where((o) => o.id.isIn(sent.map((o) => o.id)))).go();
    return errors;
  }

  /// The local People row for a feed entry: by my own person id, else by the other user's account
  /// (linking an existing person by e-mail), else a new person for them.
  Future<int?> _personFor(_Json e) async {
    final cp = (e['counterparty'] as _Json?) ?? const {};
    final userId = cp['userId'] as String?;
    final email = (cp['email'] as String?)?.toLowerCase();
    final name = (cp['name'] as String?)?.trim();
    Person? person;
    if (e['personId'] != null) {
      person = await (_db.select(_db.people)..where((p) => p.syncId.equals(e['personId'] as String))).getSingleOrNull();
    }
    if (person == null && userId != null) {
      person = await (_db.select(_db.people)..where((p) => p.linkedUserId.equals(userId))).getSingleOrNull();
    }
    if (person == null && email != null) {
      person = await (_db.select(_db.people)..where((p) => p.email.lower().equals(email))..limit(1)).getSingleOrNull();
    }
    if (person == null && userId == null && name != null && name.isNotEmpty) {
      person = await (_db.select(_db.people)..where((p) => p.name.equals(name))..limit(1)).getSingleOrNull();
    }
    if (person == null) {
      if (name == null || name.isEmpty) return null;
      return _db.into(_db.people).insert(PeopleCompanion.insert(
            name: name,
            email: Value(email),
            linkedUserId: Value(userId),
            // Same id on every device of this user, so they converge on one person.
            syncId: Value(userId != null ? 'u-$userId' : null),
          ));
    }
    if (userId != null && person.linkedUserId != userId) {
      await (_db.update(_db.people)..where((p) => p.id.equals(person!.id)))
          .write(PeopleCompanion(linkedUserId: Value(userId)));
    }
    return person.id;
  }

  Future<void> _applyLedgerEntry(_Json e) async {
    final id = e['id'] as String;
    final local = await (_db.select(_db.ledgerEntries)..where((x) => x.entryId.equals(id))).getSingleOrNull();
    final stillQueued = (await (_db.select(_db.ledgerOutbox)..where((o) => o.entryId.equals(id))..limit(1)).get()).isNotEmpty;
    final personId = local?.personId ?? await _personFor(e);
    final cp = (e['counterparty'] as _Json?) ?? const {};
    final otherUser = cp['userId'] as String?;
    if (personId != null && otherUser != null) {
      // The server found an account for this person: remember it (syncs to my other devices).
      await (_db.update(_db.people)..where((p) => p.id.equals(personId) & (p.linkedUserId.isNull() | p.linkedUserId.equals(otherUser).not())))
          .write(PeopleCompanion(linkedUserId: Value(otherUser)));
    }
    final comp = LedgerEntriesCompanion(
      entryId: Value(id),
      personId: Value(personId),
      kind: Value(_enum(LedgerKind.values, (e['kind'] as String).toLowerCase(), LedgerKind.other)),
      direction: Value(_enum(LedgerDirection.values, (e['direction'] as String).toLowerCase(), LedgerDirection.gave)),
      amount: Value((e['amount'] as num).toDouble()),
      currency: Value(e['currency'] as String? ?? 'EGP'),
      date: Value(_parseYmd(e['date'] as String)),
      description: Value(e['description'] as String?),
      // A newer local action (made while this request was in flight) keeps its optimistic status.
      status: stillQueued && local != null
          ? const Value.absent()
          : Value(_enum(LedgerStatus.values, (e['status'] as String).toLowerCase(), LedgerStatus.pending)),
      rejectReason: Value(e['rejectReason'] as String?),
      settlesEntryId: Value(e['settlesEntryId'] as String?),
      createdByMe: Value(e['createdByMe'] == true),
      counterpartUserId: Value(cp['userId'] as String?),
      counterpartName: Value(cp['name'] as String?),
      queued: Value(stillQueued),
      createdAt: Value(DateTime.parse(e['createdAt'] as String)),
    );
    if (local == null) {
      await _db.into(_db.ledgerEntries).insert(comp);
    } else {
      await (_db.update(_db.ledgerEntries)..where((x) => x.id.equals(local.id))).write(comp);
    }
  }

  Future<void> _applyNotification(_Json n) async {
    final id = n['id'] as String;
    final local = await (_db.select(_db.appNotifications)..where((x) => x.id.equals(id))).getSingleOrNull();
    final serverRead = n['readAt'] == null ? null : DateTime.parse(n['readAt'] as String);
    await _db.into(_db.appNotifications).insertOnConflictUpdate(AppNotificationsCompanion(
          id: Value(id),
          type: Value(n['type'] as String),
          entryId: Value(n['entryId'] as String?),
          actorName: Value(n['actorName'] as String?),
          amount: Value((n['amount'] as num?)?.toDouble()),
          currency: Value(n['currency'] as String?),
          createdAt: Value(DateTime.parse(n['createdAt'] as String)),
          readAt: Value(local?.readPending == true ? local!.readAt : serverRead),
          readPending: Value(local?.readPending == true && serverRead == null),
        ));
  }

  Future<bool> _deleteBySyncId(String table, _Json r) async {
    final id = r['id'] as String;
    final rows = await _db.customSelect(
      'SELECT updated_at FROM $table WHERE sync_id = ?',
      variables: [Variable.withString(id)],
    ).get();
    if (rows.isEmpty) return false;
    if (rows.first.read<int>('updated_at') > _secs(r['deletedAt'] as String)) return false;
    await _db.customUpdate('DELETE FROM $table WHERE sync_id = ?', variables: [Variable.withString(id)]);
    return true;
  }

  Future<bool> _upsertBank(_Json r) async {
    final id = r['id'] as String;
    final local = await (_db.select(_db.banks)..where((b) => b.syncId.equals(id))).getSingleOrNull();
    if (!_newer(local?.updatedAt, r)) return false;
    final comp = BanksCompanion(
      syncId: Value(id),
      name: Value(r['name'] as String),
      logoUri: Value(r['logoUri'] as String?),
      isCustom: Value(r['isCustom'] as bool),
      updatedAt: Value(_secs(r['updatedAt'] as String)),
      dirty: const Value(false),
    );
    if (local == null) {
      await _db.into(_db.banks).insert(comp);
    } else {
      await (_db.update(_db.banks)..where((b) => b.id.equals(local.id))).write(comp);
    }
    return true;
  }

  Future<Map<String, int>> _idMap(String table) async {
    final rows = await _db.customSelect('SELECT id, sync_id FROM $table WHERE sync_id IS NOT NULL').get();
    return {for (final r in rows) r.read<String>('sync_id'): r.read<int>('id')};
  }

  /// Returns null when the record references something unknown on this device.
  Future<bool?> _upsertCategory(_Json r) async {
    final id = r['id'] as String;
    int? parentId;
    if (r['parentId'] != null) {
      parentId = (await _idMap('categories'))[r['parentId'] as String];
      if (parentId == null) return null;
    }
    final local = await (_db.select(_db.categories)..where((c) => c.syncId.equals(id))).getSingleOrNull();
    if (!_newer(local?.updatedAt, r)) return false;
    final comp = CategoriesCompanion(
      syncId: Value(id),
      parentCategoryId: Value(parentId),
      name: Value(r['name'] as String),
      icon: Value(r['icon'] as String),
      color: Value(r['color'] as String),
      type: Value(_enum(CategoryType.values, r['type'], CategoryType.expense)),
      isDefault: Value(r['isDefault'] as bool),
      updatedAt: Value(_secs(r['updatedAt'] as String)),
      dirty: const Value(false),
    );
    if (local == null) {
      await _db.into(_db.categories).insert(comp);
    } else {
      await (_db.update(_db.categories)..where((c) => c.id.equals(local.id))).write(comp);
    }
    return true;
  }

  Future<bool?> _upsertCard(_Json r) async {
    final id = r['id'] as String;
    final bankId = (await _idMap('banks'))[r['bankId'] as String];
    if (bankId == null) return null;
    final local = await (_db.select(_db.cards)..where((c) => c.syncId.equals(id))).getSingleOrNull();
    if (!_newer(local?.updatedAt, r)) return false;
    final comp = CardsCompanion(
      syncId: Value(id),
      bankId: Value(bankId),
      cardType: Value(_enum(CardType.values, r['cardType'], CardType.visa)),
      cardCategory: Value(_enum(CardCategory.values, r['cardCategory'], CardCategory.credit)),
      nickname: Value(r['nickname'] as String),
      last4Digits: Value(r['last4Digits'] as String),
      dueDateDay: Value(r['dueDateDay'] as int?),
      statementDateDay: Value(r['statementDateDay'] as int?),
      creditLimit: Value((r['creditLimit'] as num?)?.toDouble()),
      color: Value(r['color'] as String),
      isActive: Value(r['isActive'] as bool),
      updatedAt: Value(_secs(r['updatedAt'] as String)),
      dirty: const Value(false),
    );
    if (local == null) {
      await _db.into(_db.cards).insert(comp);
    } else {
      await (_db.update(_db.cards)..where((c) => c.id.equals(local.id))).write(comp);
    }
    return true;
  }

  Future<bool> _upsertBeneficiary(_Json r) async {
    final name = r['name'] as String;
    final local = await (_db.select(_db.beneficiaries)..where((b) => b.name.equals(name))).getSingleOrNull();
    if (!_newer(local?.updatedAt, r)) return false;
    final comp = BeneficiariesCompanion(
      name: Value(name),
      lastUsedAt: Value(DateTime.parse(r['lastUsedAt'] as String)),
      updatedAt: Value(_secs(r['updatedAt'] as String)),
      dirty: const Value(false),
    );
    if (local == null) {
      await _db.into(_db.beneficiaries).insert(comp);
    } else {
      await (_db.update(_db.beneficiaries)..where((b) => b.id.equals(local.id))).write(comp);
    }
    return true;
  }

  Future<bool?> _upsertTransaction(_Json r) async {
    final id = r['id'] as String;
    final categoryId = (await _idMap('categories'))[r['categoryId'] as String];
    if (categoryId == null) return null;
    int? cardId;
    if (r['cardId'] != null) {
      cardId = (await _idMap('cards'))[r['cardId'] as String];
      if (cardId == null) return null;
    }
    final local = await (_db.select(_db.transactions)..where((t) => t.syncId.equals(id))).getSingleOrNull();
    if (!_newer(local?.updatedAt, r)) return false;
    final comp = TransactionsCompanion(
      syncId: Value(id),
      amount: Value((r['amount'] as num).toDouble()),
      type: Value(_enum(TransactionType.values, r['type'], TransactionType.expense)),
      categoryId: Value(categoryId),
      paymentMethodType: Value(_enum(PaymentMethodType.values, r['paymentMethodType'], PaymentMethodType.cash)),
      cardId: Value(cardId),
      date: Value(_parseYmd(r['date'] as String)),
      note: Value(r['note'] as String?),
      beneficiaryName: Value(r['beneficiaryName'] as String?),
      createdAt: Value(DateTime.parse(r['createdAt'] as String)),
      updatedAt: Value(_secs(r['updatedAt'] as String)),
      dirty: const Value(false),
    );
    if (local == null) {
      await _db.into(_db.transactions).insert(comp);
    } else {
      // attachment_uri is device-local and deliberately left untouched.
      await (_db.update(_db.transactions)..where((t) => t.id.equals(local.id))).write(comp);
    }
    return true;
  }

  Future<bool?> _upsertBudget(_Json r) async {
    final categoryId = (await _idMap('categories'))[r['categoryId'] as String];
    if (categoryId == null) return null;
    final local = await (_db.select(_db.categoryBudgets)..where((b) => b.categoryId.equals(categoryId))).getSingleOrNull();
    if (!_newer(local?.updatedAt, r)) return false;
    final comp = CategoryBudgetsCompanion(
      syncId: Value(r['categoryId'] as String),
      categoryId: Value(categoryId),
      monthlyLimit: Value((r['monthlyLimit'] as num).toDouble()),
      isEnabled: Value(r['isEnabled'] as bool),
      updatedAt: Value(_secs(r['updatedAt'] as String)),
      dirty: const Value(false),
    );
    if (local == null) {
      await _db.into(_db.categoryBudgets).insert(comp);
    } else {
      await (_db.update(_db.categoryBudgets)..where((b) => b.id.equals(local.id))).write(comp);
    }
    return true;
  }

  Future<bool> _deleteBudget(_Json r) async {
    final categoryId = (await _idMap('categories'))[r['categoryId'] as String];
    if (categoryId == null) return false;
    final local = await (_db.select(_db.categoryBudgets)..where((b) => b.categoryId.equals(categoryId))).getSingleOrNull();
    if (local == null || local.updatedAt > _secs(r['deletedAt'] as String)) return false;
    await (_db.delete(_db.categoryBudgets)..where((b) => b.id.equals(local.id))).go();
    return true;
  }
}

class _PushedRow {
  const _PushedRow(this.table, this.id, this.updatedAt);
  final String table;
  final int id;
  final int updatedAt;
}

class _Outbox {
  const _Outbox(this.records, this.pushedRows, this.tombstoneIds);
  final Map<String, List<_Json>> records;
  final List<_PushedRow> pushedRows;
  final List<int> tombstoneIds;
}
