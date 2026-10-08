import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/database_provider.dart';
import '../db/seed.dart';
import 'sync_api.dart';
import 'sync_service.dart';

enum SyncStatus { signedOut, idle, syncing, error }

class SyncState {
  const SyncState({
    this.loaded = false,
    this.session,
    this.status = SyncStatus.signedOut,
    this.lastSyncAt,
    this.errorCode,
    this.lastReport,
  });

  final bool loaded;
  final SyncSession? session;
  final SyncStatus status;
  final DateTime? lastSyncAt;
  final String? errorCode;
  final SyncReport? lastReport;

  bool get signedIn => session != null;

  SyncState copyWith({
    bool? loaded,
    SyncSession? session,
    bool clearSession = false,
    SyncStatus? status,
    DateTime? lastSyncAt,
    String? errorCode,
    bool clearError = false,
    SyncReport? lastReport,
  }) =>
      SyncState(
        loaded: loaded ?? this.loaded,
        session: clearSession ? null : (session ?? this.session),
        status: status ?? this.status,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
        lastReport: lastReport ?? this.lastReport,
      );
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(SyncController.new);

class SyncController extends Notifier<SyncState> with WidgetsBindingObserver {
  Timer? _debounce;
  StreamSubscription<Set<TableUpdate>>? _dbWatch;
  bool _running = false;

  AppDatabase get _db => ref.read(databaseProvider);

  @override
  SyncState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _debounce?.cancel();
      _dbWatch?.cancel();
    });
    Future.microtask(_load);
    return const SyncState();
  }

  Future<void> _load() async {
    final session = await SyncSession.load();
    final last = await SyncService.lastSyncAt(_db);
    state = SyncState(
      loaded: true,
      session: session,
      status: session == null ? SyncStatus.signedOut : SyncStatus.idle,
      lastSyncAt: last == null ? null : DateTime.tryParse(last)?.toLocal(),
    );
    if (session != null) {
      _watchLocalChanges();
      _schedule(const Duration(seconds: 2));
    }
  }

  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState state_) {
    if (state_ == AppLifecycleState.resumed && state.signedIn) _schedule(const Duration(seconds: 1));
  }

  /// Any local write to a synced table → sync a few seconds later (debounced).
  void _watchLocalChanges() {
    _dbWatch?.cancel();
    final db = _db;
    _dbWatch = db
        .tableUpdates(TableUpdateQuery.onAllTables([
          db.banks, db.categories, db.cards, db.beneficiaries, db.transactions, db.categoryBudgets,
        ]))
        .listen((_) {
      if (!_running) _schedule(const Duration(seconds: 4));
    });
  }

  void _schedule(Duration d) {
    _debounce?.cancel();
    _debounce = Timer(d, () => syncNow());
  }

  Future<void> signIn({
    required String serverUrl,
    required String email,
    required String password,
    bool register = false,
    String name = '',
    String? signupCode,
  }) async {
    final url = normalizeServerUrl(serverUrl);
    final api = SyncApi(url);
    try {
      final session = register
          ? await api.register(email.trim(), password, name.trim(), signupCode)
          : await api.login(email.trim(), password);
      await session.save();
      await SyncService(_db, api).prepareForAccount(session.userId);
      state = state.copyWith(
        loaded: true,
        session: session,
        status: SyncStatus.idle,
        clearError: true,
      );
      _watchLocalChanges();
      unawaited(syncNow());
    } finally {
      api.close();
    }
  }

  Future<void> syncNow() async {
    final session = state.session;
    if (session == null || _running) return;
    _running = true;
    state = state.copyWith(status: SyncStatus.syncing, clearError: true);
    final api = SyncApi(
      session.serverUrl,
      session: session,
      onSessionChanged: (updated) {
        state = state.copyWith(session: updated);
        updated.save();
      },
    );
    try {
      final report = await SyncService(_db, api).run();
      final last = await SyncService.lastSyncAt(_db);
      state = state.copyWith(
        status: SyncStatus.idle,
        lastSyncAt: last == null ? DateTime.now() : DateTime.tryParse(last)?.toLocal(),
        lastReport: report,
        clearError: true,
      );
    } on ApiException catch (e) {
      // The refresh token was rejected: the login is gone, ask the user to sign in again.
      if (e.status == 401) {
        await SyncSession.clear();
        state = state.copyWith(clearSession: true, status: SyncStatus.signedOut, errorCode: 'session_expired');
      } else {
        state = state.copyWith(status: SyncStatus.error, errorCode: e.code);
      }
    } catch (e) {
      debugPrint('sync failed: $e');
      state = state.copyWith(status: SyncStatus.error, errorCode: 'unexpected');
    } finally {
      _running = false;
      api.close();
    }
  }

  /// Signs out; with [wipe] the synced data is also removed from this device (and defaults re-seeded).
  Future<void> signOut({bool wipe = false}) async {
    final session = state.session;
    _dbWatch?.cancel();
    _debounce?.cancel();
    if (session != null) {
      final api = SyncApi(session.serverUrl, session: session);
      await api.logout();
      api.close();
    }
    await SyncSession.clear();
    if (wipe) {
      await SyncService(_db, SyncApi('')).wipeLocalData();
      await seedIfNeeded(_db);
    }
    state = const SyncState(loaded: true);
  }

  /// Deletes the account and all its server data; local data stays on the device.
  Future<void> deleteAccount(String password) async {
    final session = state.session;
    if (session == null) return;
    final api = SyncApi(session.serverUrl, session: session, onSessionChanged: (s) => s.save());
    try {
      await api.deleteAccount(password);
    } finally {
      api.close();
    }
    await signOut();
  }
}
