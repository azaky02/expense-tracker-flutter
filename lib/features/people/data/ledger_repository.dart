import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';

/// Balance with one person, derived only from CONFIRMED ledger entries (never stored).
class PersonBalance {
  const PersonBalance({
    required this.heOwesMe,
    required this.iOweHim,
    required this.pendingCount,
    required this.lastDate,
  });

  /// Receivable: what the person still owes me.
  final double heOwesMe;
  /// Payable: what I still owe the person.
  final double iOweHim;
  /// Entries waiting for the other side (or for the server).
  final int pendingCount;
  final DateTime? lastDate;

  double get net => heOwesMe - iOweHim;

  static const zero = PersonBalance(heOwesMe: 0, iOweHim: 0, pendingCount: 0, lastDate: null);

  /// Loans/advances create an obligation; settlements pay one down. A settlement larger than the
  /// obligation on its side flips over to the other side, so `net` always equals gave - received.
  static PersonBalance of(Iterable<LedgerEntry> entries) {
    var loansIn = 0.0, loansOut = 0.0, repaidByMe = 0.0, repaidToMe = 0.0;
    var pending = 0;
    DateTime? last;
    for (final e in entries) {
      if (e.status == LedgerStatus.pending || e.queued) pending++;
      if (e.status != LedgerStatus.confirmed) continue;
      final isSettlement = e.kind == LedgerKind.settlement;
      if (e.direction == LedgerDirection.received) {
        isSettlement ? repaidToMe += e.amount : loansIn += e.amount;
      } else {
        isSettlement ? repaidByMe += e.amount : loansOut += e.amount;
      }
      if (last == null || e.date.isAfter(last)) last = e.date;
    }
    var iOwe = loansIn - repaidByMe;
    var heOwes = loansOut - repaidToMe;
    if (iOwe < 0) {
      heOwes += -iOwe;
      iOwe = 0;
    }
    if (heOwes < 0) {
      iOwe += -heOwes;
      heOwes = 0;
    }
    return PersonBalance(heOwesMe: _r(heOwes), iOweHim: _r(iOwe), pendingCount: pending, lastDate: last);
  }

  static double _r(double v) => (v * 100).roundToDouble() / 100;
}

class PersonWithBalance {
  const PersonWithBalance(this.person, this.balance);
  final Person person;
  final PersonBalance balance;
}

/// One line of a statement: an entry with the running balance after it (from my side; > 0 = he owes me).
class StatementLine {
  const StatementLine(this.entry, this.runningBalance);
  final LedgerEntry entry;
  final double runningBalance;
}

String newEntryId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // uuid v4
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class LedgerRepository {
  LedgerRepository(this._db);
  final AppDatabase _db;

  // ───────────── people ─────────────

  Stream<List<PersonWithBalance>> watchPeopleWithBalances() {
    final people = _db.select(_db.people)..orderBy([(p) => OrderingTerm.asc(p.name)]);
    return _combineLatest(people.watch(), _db.select(_db.ledgerEntries).watch(), (list, entries) {
      {
        final byPerson = <int, List<LedgerEntry>>{};
        for (final e in entries) {
          if (e.personId != null) (byPerson[e.personId!] ??= []).add(e);
        }
        final out = [
          for (final p in list) PersonWithBalance(p, PersonBalance.of(byPerson[p.id] ?? const [])),
        ];
        // People you have open balances with first, then most recent activity.
        out.sort((a, b) {
          final ao = a.balance.net != 0 ? 0 : 1, bo = b.balance.net != 0 ? 0 : 1;
          if (ao != bo) return ao - bo;
          final ad = a.balance.lastDate, bd = b.balance.lastDate;
          if (ad != null && bd != null) return bd.compareTo(ad);
          if (ad != null) return -1;
          if (bd != null) return 1;
          return a.person.name.compareTo(b.person.name);
        });
        return out;
      }
    });
  }

  Stream<Person?> watchPerson(int id) =>
      (_db.select(_db.people)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<int> createPerson({required String name, String? phone, String? email, String? notes}) {
    return _db.into(_db.people).insert(PeopleCompanion.insert(
          name: name.trim(),
          phone: Value(_blank(phone)),
          email: Value(_blank(email)?.toLowerCase()),
          notes: Value(_blank(notes)),
        ));
  }

  Future<void> updatePerson(int id, {required String name, String? phone, String? email, String? notes}) async {
    final old = await (_db.select(_db.people)..where((p) => p.id.equals(id))).getSingle();
    final newEmail = _blank(email)?.toLowerCase();
    await (_db.update(_db.people)..where((p) => p.id.equals(id))).write(PeopleCompanion(
          name: Value(name.trim()),
          phone: Value(_blank(phone)),
          email: Value(newEmail),
          notes: Value(_blank(notes)),
          // A different e-mail may be a different account: forget the old link.
          linkedUserId: newEmail == old.email ? const Value.absent() : const Value(null),
        ));
  }

  /// Only people without any ledger history can be deleted (history is never thrown away).
  Future<bool> deletePerson(int id) async {
    final used = await (_db.select(_db.ledgerEntries)..where((e) => e.personId.equals(id))..limit(1)).get();
    if (used.isNotEmpty) return false;
    await (_db.delete(_db.people)..where((p) => p.id.equals(id))).go();
    return true;
  }

  // ───────────── entries ─────────────

  Stream<List<LedgerEntry>> watchEntriesFor(int personId) {
    final q = _db.select(_db.ledgerEntries)
      ..where((e) => e.personId.equals(personId))
      ..orderBy([(e) => OrderingTerm.desc(e.date), (e) => OrderingTerm.desc(e.createdAt)]);
    return q.watch();
  }

  Stream<LedgerEntry?> watchEntry(String entryId) =>
      (_db.select(_db.ledgerEntries)..where((e) => e.entryId.equals(entryId))).watchSingleOrNull();

  /// Confirmed entries oldest first, each with the balance after it.
  Stream<List<StatementLine>> watchStatement(int personId) {
    final q = _db.select(_db.ledgerEntries)
      ..where((e) => e.personId.equals(personId) & e.status.equalsValue(LedgerStatus.confirmed))
      ..orderBy([(e) => OrderingTerm.asc(e.date), (e) => OrderingTerm.asc(e.createdAt)]);
    return q.watch().map((rows) {
      var balance = 0.0;
      return [
        for (final e in rows)
          StatementLine(e, balance = ((balance + (e.direction == LedgerDirection.gave ? e.amount : -e.amount)) * 100).roundToDouble() / 100),
      ];
    });
  }

  /// Saved locally at once (works offline) and queued for the server.
  Future<String> createEntry({
    required int personId,
    required LedgerKind kind,
    required LedgerDirection direction,
    required double amount,
    required DateTime date,
    String? description,
    String? settlesEntryId,
  }) async {
    final person = await (_db.select(_db.people)..where((p) => p.id.equals(personId))).getSingle();
    final id = newEntryId();
    final shared = person.email != null && person.email!.isNotEmpty;
    await _db.transaction(() async {
      await _db.into(_db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
            entryId: id,
            personId: Value(personId),
            kind: kind,
            direction: direction,
            amount: amount,
            date: date,
            description: Value(_blank(description)),
            // Without an account on the other side the entry is final right away; with one it waits
            // for their confirmation. The server decides; this is just what to show until it answers.
            status: shared ? LedgerStatus.pending : LedgerStatus.confirmed,
            settlesEntryId: Value(settlesEntryId),
            counterpartName: Value(person.name),
            queued: const Value(true),
          ));
      await _enqueue(id, 'create', {
        'kind': kind.name.toUpperCase(),
        'direction': direction.name.toUpperCase(),
        'amount': amount,
        'currency': 'EGP',
        'date': _ymd(date),
        'description': _blank(description),
        'personId': person.syncId,
        'counterpartEmail': person.email,
        'counterpartName': person.name,
        'settlesEntryId': settlesEntryId,
      });
    });
    return id;
  }

  Future<void> confirm(String entryId) => _transition(entryId, 'confirm', LedgerStatus.confirmed);
  Future<void> reject(String entryId, String? reason) =>
      _transition(entryId, 'reject', LedgerStatus.rejected, {'reason': _blank(reason)});
  Future<void> cancel(String entryId) => _transition(entryId, 'cancel', LedgerStatus.cancelled);

  Future<void> _transition(String entryId, String op, LedgerStatus optimistic, [Map<String, dynamic> extra = const {}]) {
    return _db.transaction(() async {
      await (_db.update(_db.ledgerEntries)..where((e) => e.entryId.equals(entryId))).write(
            LedgerEntriesCompanion(status: Value(optimistic), queued: const Value(true)),
          );
      await _enqueue(entryId, op, extra);
    });
  }

  Future<void> _enqueue(String entryId, String op, Map<String, dynamic> fields) {
    return _db.into(_db.ledgerOutbox).insert(LedgerOutboxCompanion.insert(
          entryId: entryId,
          op: op,
          payload: jsonEncode({'op': op, 'id': entryId, ...fields}..removeWhere((k, v) => v == null)),
        ));
  }

  // ───────────── notifications ─────────────

  Stream<List<AppNotification>> watchNotifications() =>
      (_db.select(_db.appNotifications)..orderBy([(n) => OrderingTerm.desc(n.createdAt)])).watch();

  Stream<int> watchUnreadCount() {
    final count = _db.appNotifications.id.count();
    final q = _db.selectOnly(_db.appNotifications)
      ..addColumns([count])
      ..where(_db.appNotifications.readAt.isNull());
    return q.watchSingle().map((r) => r.read(count) ?? 0);
  }

  Future<void> markAllRead() async {
    await (_db.update(_db.appNotifications)..where((n) => n.readAt.isNull())).write(
          AppNotificationsCompanion(readAt: Value(DateTime.now()), readPending: const Value(true)),
        );
  }

  Future<int?> personIdForEntry(String entryId) async =>
      (await (_db.select(_db.ledgerEntries)..where((e) => e.entryId.equals(entryId))).getSingleOrNull())?.personId;
}

/// Emits [combine] of the latest values of both streams once each has emitted at least once.
Stream<R> _combineLatest<A, B, R>(Stream<A> a, Stream<B> b, R Function(A, B) combine) {
  late StreamController<R> controller;
  StreamSubscription<A>? sa;
  StreamSubscription<B>? sb;
  A? la;
  B? lb;
  var hasA = false, hasB = false;
  void emit() {
    if (hasA && hasB) controller.add(combine(la as A, lb as B));
  }

  controller = StreamController<R>(
    onListen: () {
      sa = a.listen((v) {
        la = v;
        hasA = true;
        emit();
      }, onError: controller.addError);
      sb = b.listen((v) {
        lb = v;
        hasB = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await sa?.cancel();
      await sb?.cancel();
    },
  );
  return controller.stream;
}

String? _blank(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}
