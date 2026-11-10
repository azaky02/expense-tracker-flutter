import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../domain/finishing_rules.dart';

/// Trades a new project starts with (they can be renamed or removed while unused).
const defaultTradeKeys = ['electric', 'plumbing', 'plaster', 'carpentry', 'paint', 'ceramic'];

String newFinishingEventId() {
  final r = Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${List.generate(8, (_) => r.nextInt(36).toRadixString(36)).join()}';
}

class ProjectSummary {
  const ProjectSummary(this.project, this.balance, {this.pendingTrades = 0});
  final FinishingProject project;
  final FinishingBalance balance;
  final int pendingTrades;
}

class CashLegView {
  const CashLegView(this.accountName, this.amount, this.source);
  final String accountName;
  final int amount;
  final String source;
}

class FinishingEventView {
  const FinishingEventView({required this.event, this.tradeName, this.legs = const [], this.reversed = false});
  final FinishingEvent event;
  final String? tradeName;
  final List<CashLegView> legs;

  /// Cancelled by a later reversal.
  final bool reversed;
  FinishingKind get kind => FinishingKind.parse(event.kind);
}

class TradeCost {
  const TradeCost(this.trade, this.total, this.count);
  final FinishingTrade trade;
  final int total;
  final int count;
}

class ProjectDetails {
  const ProjectDetails({
    required this.project,
    required this.balance,
    required this.trades,
    required this.events,
    required this.byTrade,
    required this.byType,
    required this.custodyIn,
    required this.custodyOut,
  });
  final FinishingProject project;
  final FinishingBalance balance;
  final List<FinishingTrade> trades;

  /// Newest first, reversals included.
  final List<FinishingEventView> events;
  final List<TradeCost> byTrade;
  final Map<CostType, int> byType;

  /// Total custody received / returned to the client (for the statement).
  final int custodyIn;
  final int custodyOut;
}

class FinishingRepository {
  FinishingRepository(this._db);
  final AppDatabase _db;

  // ---------- projects ----------

  /// Fires whenever anything a project screen shows may have changed.
  Stream<void> _changes() => _db
      .customSelect(
        // A fingerprint of the data, so drift (which skips identical results) emits on real changes.
        "SELECT (SELECT GROUP_CONCAT(id || ':' || updated_at || ':' || closed || ':' || work_status, ',') FROM finishing_projects) AS p, "
        "(SELECT COUNT(*) || ':' || IFNULL(MAX(id), 0) FROM finishing_events) AS e, "
        "(SELECT GROUP_CONCAT(id || ':' || name, ',') FROM finishing_trades) AS t, "
        "(SELECT GROUP_CONCAT(id || ':' || name, ',') FROM accounts) AS a",
        readsFrom: {_db.finishingProjects, _db.finishingEvents, _db.finishingTrades, _db.finishingCashLegs, _db.accounts},
      )
      .watch();

  Stream<List<ProjectSummary>> watchProjects() => _changes().asyncMap((_) async {
    final projects = await (_db.select(_db.finishingProjects)..orderBy([(p) => OrderingTerm.desc(p.updatedAt)])).get();
    final events = await _db.select(_db.finishingEvents).get();
    return [for (final p in projects) ProjectSummary(p, _balanceOf(events.where((e) => e.projectId == p.id)))];
  });

  Stream<ProjectDetails?> watchProject(int id) => _changes().asyncMap((_) => loadProject(id));

  Future<ProjectDetails?> loadProject(int id) async {
    final p = await (_db.select(_db.finishingProjects)..where((x) => x.id.equals(id))).getSingleOrNull();
    return p == null ? null : _details(p);
  }

  Future<ProjectDetails> _details(FinishingProject p) async {
    final events =
        await (_db.select(_db.finishingEvents)
              ..where((e) => e.projectId.equals(p.id))
              ..orderBy([(e) => OrderingTerm.desc(e.date), (e) => OrderingTerm.desc(e.id)]))
            .get();
    final trades =
        await (_db.select(_db.finishingTrades)
              ..where((t) => t.projectId.equals(p.id))
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    final ids = events.map((e) => e.id).toList();
    final legs = ids.isEmpty ? <FinishingCashLeg>[] : await (_db.select(_db.finishingCashLegs)..where((l) => l.eventId.isIn(ids))).get();
    final accounts = {for (final a in await _db.select(_db.accounts).get()) a.id: a.name};
    final reversed = {
      for (final e in events)
        if (e.reversesId != null) e.reversesId!,
    };
    final tradeName = {for (final t in trades) t.id: t.name};
    final active = events.where((e) => e.kind != FinishingKind.reversal.name && !reversed.contains(e.id)).toList();

    final byTradeTotal = <int, (int, int)>{};
    final byType = {for (final t in CostType.values) t: 0};
    var custodyIn = 0, custodyOut = 0;
    for (final e in active) {
      if (e.kind == FinishingKind.cost.name) {
        if (e.tradeId != null) {
          final o = byTradeTotal[e.tradeId!] ?? (0, 0);
          byTradeTotal[e.tradeId!] = (o.$1 + e.amount, o.$2 + 1);
        }
        final t = CostType.values.firstWhere((c) => c.name == e.costType, orElse: () => CostType.other);
        byType[t] = byType[t]! + e.amount;
      }
      if (e.kind == FinishingKind.clientAdvance.name) custodyIn += e.amount;
      if (e.kind == FinishingKind.returnCustody.name) custodyOut += e.amount;
    }
    return ProjectDetails(
      project: p,
      balance: _balanceOf(events),
      trades: trades,
      events: [
        for (final e in events)
          FinishingEventView(
            event: e,
            tradeName: e.tradeId == null ? null : tradeName[e.tradeId],
            legs: [
              for (final l in legs)
                if (l.eventId == e.id) CashLegView(accounts[l.accountId] ?? '—', l.amount, l.source),
            ],
            reversed: reversed.contains(e.id),
          ),
      ],
      byTrade: [for (final t in trades) TradeCost(t, byTradeTotal[t.id]?.$1 ?? 0, byTradeTotal[t.id]?.$2 ?? 0)]
        ..sort((a, b) => b.total.compareTo(a.total)),
      byType: byType,
      custodyIn: custodyIn,
      custodyOut: custodyOut,
    );
  }

  static List<FinishingEvent> _active(Iterable<FinishingEvent> events) {
    final sorted = events.toList()..sort((a, b) => a.id.compareTo(b.id));
    final reversed = {
      for (final e in sorted)
        if (e.reversesId != null) e.reversesId!,
    };
    return [
      for (final e in sorted)
        if (e.kind != FinishingKind.reversal.name && !reversed.contains(e.id)) e,
    ];
  }

  static FinishingMove _move(FinishingEvent e) =>
      FinishingMove(FinishingKind.parse(e.kind), e.amount, custodyShare: e.custodyShare, personalShare: e.personalShare);

  static FinishingBalance _balanceOf(Iterable<FinishingEvent> events) {
    // Stored events were validated when saved; replay without failing on old data.
    var b = const FinishingBalance();
    for (final e in _active(events)) {
      try {
        b = FinishingRules.apply(b, _move(e));
      } on FinishingRuleError {
        // skip
      }
    }
    return b;
  }

  static String? _clean(String? s, [int max = 2000]) {
    final t = s?.trim();
    if (t == null || t.isEmpty) return null;
    return t.length > max ? t.substring(0, max) : t;
  }

  Future<int> createProject({
    required String clientName,
    required String name,
    String? description,
    String? location,
    required DateTime startDate,
    DateTime? plannedEndDate,
    int plannedBudget = 0,
    List<String> trades = const [],
  }) async {
    if (clientName.trim().isEmpty || name.trim().isEmpty) throw const FinishingRuleError('required');
    if (plannedBudget < 0) throw const FinishingRuleError('amount');
    return _db.transaction(() async {
      final id = await _db
          .into(_db.finishingProjects)
          .insert(
            FinishingProjectsCompanion.insert(
              clientName: _clean(clientName, 150)!,
              name: _clean(name, 150)!,
              description: Value(_clean(description)),
              location: Value(_clean(location, 300)),
              startDate: startDate,
              plannedEndDate: Value(plannedEndDate),
              plannedBudget: Value(plannedBudget),
            ),
          );
      for (final t in {for (final t in trades) t.trim()}..remove('')) {
        await _db.into(_db.finishingTrades).insert(FinishingTradesCompanion.insert(projectId: id, name: t));
      }
      return id;
    });
  }

  Future<void> updateProject(
    int id, {
    required String clientName,
    required String name,
    String? description,
    String? location,
    required DateTime startDate,
    DateTime? plannedEndDate,
    int plannedBudget = 0,
    String? workStatus,
  }) async {
    if (clientName.trim().isEmpty || name.trim().isEmpty) throw const FinishingRuleError('required');
    if (plannedBudget < 0) throw const FinishingRuleError('amount');
    await (_db.update(_db.finishingProjects)..where((p) => p.id.equals(id))).write(
      FinishingProjectsCompanion(
        clientName: Value(_clean(clientName, 150)!),
        name: Value(_clean(name, 150)!),
        description: Value(_clean(description)),
        location: Value(_clean(location, 300)),
        startDate: Value(startDate),
        plannedEndDate: Value(plannedEndDate),
        plannedBudget: Value(plannedBudget),
        workStatus: workStatus == null ? const Value.absent() : Value(workStatus),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setWorkStatus(int id, String status) => (_db.update(
    _db.finishingProjects,
  )..where((p) => p.id.equals(id))).write(FinishingProjectsCompanion(workStatus: Value(status), updatedAt: Value(DateTime.now())));

  /// Financial close: only with no custody and no receivable left.
  Future<void> close(int id) => _db.transaction(() async {
    final events = await (_db.select(_db.finishingEvents)..where((e) => e.projectId.equals(id))).get();
    final b = _balanceOf(events);
    if (b.custody != 0) throw const FinishingRuleError('closeCustody');
    if (b.receivable != 0) throw const FinishingRuleError('closeReceivable');
    await (_db.update(_db.finishingProjects)..where((p) => p.id.equals(id))).write(
      FinishingProjectsCompanion(closed: const Value(true), workStatus: const Value('completed'), updatedAt: Value(DateTime.now())),
    );
  });

  Future<void> reopen(int id) => (_db.update(
    _db.finishingProjects,
  )..where((p) => p.id.equals(id))).write(FinishingProjectsCompanion(closed: const Value(false), updatedAt: Value(DateTime.now())));

  /// Deletes a project with all its records (and their account movements).
  Future<void> deleteProject(int id) => _db.transaction(() async {
    final ids = (await (_db.select(_db.finishingEvents)..where((e) => e.projectId.equals(id))).get()).map((e) => e.id).toList();
    if (ids.isNotEmpty) await (_db.delete(_db.finishingCashLegs)..where((l) => l.eventId.isIn(ids))).go();
    await (_db.delete(_db.finishingEvents)..where((e) => e.projectId.equals(id))).go();
    await (_db.delete(_db.finishingTrades)..where((t) => t.projectId.equals(id))).go();
    await (_db.delete(_db.finishingProjects)..where((p) => p.id.equals(id))).go();
  });

  // ---------- trades ----------

  Future<int> addTrade(int projectId, String name) async {
    final n = name.trim();
    if (n.isEmpty) throw const FinishingRuleError('required');
    final exists = await (_db.select(
      _db.finishingTrades,
    )..where((t) => t.projectId.equals(projectId) & t.name.equals(n))).getSingleOrNull();
    if (exists != null) throw const FinishingRuleError('tradeExists');
    return _db.into(_db.finishingTrades).insert(FinishingTradesCompanion.insert(projectId: projectId, name: n));
  }

  Future<void> renameTrade(FinishingTrade trade, String name) async {
    final n = name.trim();
    if (n.isEmpty) throw const FinishingRuleError('required');
    final exists = await (_db.select(
      _db.finishingTrades,
    )..where((t) => t.projectId.equals(trade.projectId) & t.name.equals(n) & t.id.equals(trade.id).not())).getSingleOrNull();
    if (exists != null) throw const FinishingRuleError('tradeExists');
    await (_db.update(_db.finishingTrades)..where((t) => t.id.equals(trade.id))).write(FinishingTradesCompanion(name: Value(n)));
  }

  /// Only a trade no cost uses can be deleted.
  Future<void> deleteTrade(int tradeId) async {
    final used =
        await (_db.select(_db.finishingEvents)
              ..where((e) => e.tradeId.equals(tradeId))
              ..limit(1))
            .getSingleOrNull();
    if (used != null) throw const FinishingRuleError('tradeUsed');
    await (_db.delete(_db.finishingTrades)..where((t) => t.id.equals(tradeId))).go();
  }

  // ---------- events ----------

  /// Records one event and its account movements atomically. [eventId] makes it safe to retry:
  /// the same id with the same data does nothing, with different data it is refused.
  ///
  /// [accountId]: where the money came in / went out. For a cost it pays the custody share;
  /// [personalAccountId] pays the personal share.
  Future<void> record({
    required String eventId,
    required int projectId,
    required FinishingKind kind,
    required int amount,
    int custodyShare = 0,
    int personalShare = 0,
    int? tradeId,
    CostType? costType,
    String? description,
    String? beneficiary,
    required DateTime date,
    int? accountId,
    int? personalAccountId,
  }) => _db.transaction(() async {
    if (kind == FinishingKind.reversal) throw const FinishingRuleError('kind');
    final existing = await (_db.select(_db.finishingEvents)..where((e) => e.eventId.equals(eventId))).getSingleOrNull();
    if (existing != null) {
      final same =
          existing.projectId == projectId &&
          existing.kind == kind.name &&
          existing.amount == amount &&
          existing.custodyShare == custodyShare &&
          existing.personalShare == personalShare;
      if (same) return;
      throw const FinishingRuleError('duplicate');
    }
    final project = await (_db.select(_db.finishingProjects)..where((p) => p.id.equals(projectId))).getSingle();
    if (project.closed) throw const FinishingRuleError('closed');

    if (kind == FinishingKind.cost) {
      if (tradeId == null) throw const FinishingRuleError('trade');
      final trade = await (_db.select(_db.finishingTrades)..where((t) => t.id.equals(tradeId))).getSingleOrNull();
      if (trade == null || trade.projectId != projectId) throw const FinishingRuleError('trade');
      if (_clean(description) == null) throw const FinishingRuleError('description');
    }

    // Validate against everything recorded so far.
    final events = await (_db.select(_db.finishingEvents)..where((e) => e.projectId.equals(projectId))).get();
    FinishingRules.apply(
      _balanceOf(events),
      FinishingMove(
        kind,
        amount,
        custodyShare: kind == FinishingKind.cost ? custodyShare : 0,
        personalShare: kind == FinishingKind.cost ? personalShare : 0,
      ),
    );

    final legs = <(int, int, String)>[];
    void leg(int? account, int signed, String source) {
      if (signed == 0) return;
      if (account == null) throw const FinishingRuleError('account');
      legs.add((account, signed, source));
    }

    switch (kind) {
      case FinishingKind.clientAdvance:
        leg(accountId, amount, 'client');
      case FinishingKind.cost:
        leg(accountId, -custodyShare, 'custody');
        leg(personalAccountId, -personalShare, 'personal');
      case FinishingKind.clientRepayPersonal:
        leg(accountId, amount, 'client');
      case FinishingKind.returnCustody:
        leg(accountId, -amount, 'custody');
      case FinishingKind.personalAllocation || FinishingKind.reimburseFromCustody || FinishingKind.reversal:
        break;
    }

    final id = await _db
        .into(_db.finishingEvents)
        .insert(
          FinishingEventsCompanion.insert(
            eventId: eventId,
            projectId: projectId,
            kind: kind.name,
            amount: amount,
            custodyShare: Value(kind == FinishingKind.cost ? custodyShare : 0),
            personalShare: Value(kind == FinishingKind.cost ? personalShare : 0),
            tradeId: Value(kind == FinishingKind.cost ? tradeId : null),
            costType: Value(kind == FinishingKind.cost ? (costType ?? CostType.other).name : null),
            description: Value(_clean(description)),
            beneficiary: Value(_clean(beneficiary, 150)),
            date: DateTime(date.year, date.month, date.day),
          ),
        );
    for (final (account, signed, source) in legs) {
      await _db
          .into(_db.finishingCashLegs)
          .insert(FinishingCashLegsCompanion.insert(eventId: id, accountId: account, amount: signed, source: source));
    }
    await (_db.update(
      _db.finishingProjects,
    )..where((p) => p.id.equals(projectId))).write(FinishingProjectsCompanion(updatedAt: Value(DateTime.now())));
  });

  /// Cancels an event with a documented reversal (the original stays in the history). Refused
  /// when later events depend on it, e.g. reversing custody that was already spent.
  Future<void> reverse(int eventRowId, {String? reason}) => _db.transaction(() async {
    final e = await (_db.select(_db.finishingEvents)..where((x) => x.id.equals(eventRowId))).getSingle();
    if (e.kind == FinishingKind.reversal.name) throw const FinishingRuleError('kind');
    final project = await (_db.select(_db.finishingProjects)..where((p) => p.id.equals(e.projectId))).getSingle();
    if (project.closed) throw const FinishingRuleError('closed');
    final events = await (_db.select(_db.finishingEvents)..where((x) => x.projectId.equals(e.projectId))).get();
    if (events.any((x) => x.reversesId == e.id)) throw const FinishingRuleError('alreadyReversed');
    final remaining = _active(events).where((x) => x.id != e.id).map(_move);
    try {
      FinishingRules.replay(remaining);
    } on FinishingRuleError {
      throw const FinishingRuleError('reverseBlocked');
    }
    final id = await _db
        .into(_db.finishingEvents)
        .insert(
          FinishingEventsCompanion.insert(
            eventId: 'rev-${e.eventId}',
            projectId: e.projectId,
            kind: FinishingKind.reversal.name,
            amount: e.amount,
            description: Value(_clean(reason)),
            date: todayOnly(),
            reversesId: Value(e.id),
          ),
        );
    final legs = await (_db.select(_db.finishingCashLegs)..where((l) => l.eventId.equals(e.id))).get();
    for (final l in legs) {
      await _db
          .into(_db.finishingCashLegs)
          .insert(FinishingCashLegsCompanion.insert(eventId: id, accountId: l.accountId, amount: -l.amount, source: l.source));
    }
  });

  static DateTime todayOnly() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }
}

final finishingRepositoryProvider = Provider<FinishingRepository>((ref) => FinishingRepository(ref.watch(databaseProvider)));
