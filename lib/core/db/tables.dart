import 'package:drift/drift.dart';

/// `trust` is the single system category that carries amanat (money held for / paid to a person).
enum CategoryType { expense, income, trust }

enum CardType { visa, mastercard, meeza }

enum CardCategory { credit, debit }

enum PaymentMethodType { cash, card }

/// trustIn = cash received from a person to hold for them; trustOut = cash paid out to a person.
/// Neither counts as income or expense.
enum TransactionType { expense, income, trustIn, trustOut }

enum NotificationKind { dueDateReminder, budgetAlert, dailyReminder }

/// Shared Ledger (V2). Server values are the upper-case names (LOAN, GAVE, PENDING, ...).
enum LedgerKind { loan, advance, settlement, other }

/// From *this* user's point of view: gave = I handed money to the person, received = I got money.
enum LedgerDirection { gave, received }

enum LedgerStatus { pending, confirmed, rejected, cancelled }


/// Columns that make a table syncable. They are maintained entirely by SQLite triggers (see
/// sync_schema.dart), so repositories never touch them: every local write stamps updated_at and
/// sets dirty = 1, and deletes leave a row in sync_tombstones.
mixin SyncColumns on Table {
  /// Stable cross-device id (random hex, or 'seed-...' for the built-in defaults).
  TextColumn get syncId => text().nullable()();
  /// Unix seconds of the last local change, or of the remote version that was applied.
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  /// True while the row has local changes the server has not seen yet.
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
}

/// Rows deleted locally that still have to be reported to the server.
class SyncTombstones extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get key => text()();
  IntColumn get deletedAt => integer()();
}

class Banks extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get logoUri => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
}

/// Two-level hierarchy only: parentCategoryId NULL = main category, set = sub-category.
/// "Only one level of nesting" and "transactions must pick a leaf" are enforced in the
/// categories repository, not here — drift/SQLite can't express that declaratively.
class Categories extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get parentCategoryId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get color => text()(); // hex string
  TextColumn get type => textEnum<CategoryType>()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

class Cards extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bankId => integer().references(Banks, #id)();
  TextColumn get cardType => textEnum<CardType>()();
  TextColumn get cardCategory => textEnum<CardCategory>()();
  TextColumn get nickname => text()();
  TextColumn get last4Digits => text().withLength(min: 4, max: 4)();
  /// Day-of-month (1-31), credit cards only. Clamped to each month's real last day at use.
  IntColumn get dueDateDay => integer().nullable()();
  IntColumn get statementDateDay => integer().nullable()();
  RealColumn get creditLimit => real().nullable()();
  /// Rotates through AppSemanticColors.cardColorRotation at creation; user-editable later.
  TextColumn get color => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Fast autocomplete without scanning/DISTINCT-ing the whole transactions table.
class Beneficiaries extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  DateTimeColumn get lastUsedAt => dateTime()();
}

class Transactions extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get type => textEnum<TransactionType>()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get paymentMethodType => textEnum<PaymentMethodType>()();
  /// Non-null only when paymentMethodType = card — enforced by the form validator.
  IntColumn get cardId => integer().nullable().references(Cards, #id)();
  /// Gregorian, single source of truth — Hijri display/input converts only at the UI boundary.
  DateTimeColumn get date => dateTime()();
  /// Free-text note; the long-press "quick note" on the list edits this same column.
  TextColumn get note => text().nullable()();
  /// Persistent file path in app-support storage (outside iCloud backup on iOS); one max.
  TextColumn get attachmentUri => text().nullable()();
  TextColumn get beneficiaryName => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Per-main-category monthly budget thresholds (optional budget-exceeded alerts).
class CategoryBudgets extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().unique().references(Categories, #id)();
  RealColumn get monthlyLimit => real()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
}

/// User-configurable notification preferences. The mandatory 3-day card reminder is NOT
/// stored here — it's always-on and never surfaced as a togglable row (shown locked-on in UI).
class NotificationPreferences extends Table {
  TextColumn get key => text()(); // 'extraDueDateReminders' | 'dailyLogReminder'
  BoolColumn get isEnabled => boolean().withDefault(const Constant(false))();
  /// JSON-encoded config specific to the key, e.g. {"daysBefore":[7,1]} or {"hour":20}.
  TextColumn get configJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Tracks which OS-level local notification ids are currently scheduled per card/policy so
/// the reconciliation engine can cancel-then-reschedule precisely instead of enumerating
/// every pending notification on the device.
class ScheduledNotifications extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId => integer().nullable().references(Cards, #id)();
  TextColumn get kind => textEnum<NotificationKind>()();
  /// e.g. 3, 7, 1 — days-before-due-date for dueDateReminder policies.
  IntColumn get daysBefore => integer().nullable()();
  DateTimeColumn get triggerDate => dateTime()();
  /// The id used with flutter_local_notifications' zonedSchedule/cancel.
  IntColumn get osNotificationId => integer()();
}

/// Internal flags (seed-completed, etc). Single-row-per-key table.
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Counterparties (the People module). Synced like the other personal data.
@DataClassName('Person')
class People extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  /// If this e-mail belongs to an account on the server, entries with this person are shared with
  /// them and need their confirmation.
  TextColumn get email => text().nullable()();
  TextColumn get notes => text().nullable()();
  /// Server user id once an entry has shown this person has an account.
  TextColumn get linkedUserId => text().nullable()();
}

/// Local replica of the server's Shared Ledger (the server is the source of truth), seen from
/// this user's side. Rows created on this device are `queued` until the server accepts them.
class LedgerEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entryId => text().unique()();
  IntColumn get personId => integer().nullable().references(People, #id)();
  TextColumn get kind => textEnum<LedgerKind>()();
  TextColumn get direction => textEnum<LedgerDirection>()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('EGP'))();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text().nullable()();
  TextColumn get status => textEnum<LedgerStatus>()();
  TextColumn get rejectReason => text().nullable()();
  TextColumn get settlesEntryId => text().nullable()();
  BoolColumn get createdByMe => boolean().withDefault(const Constant(true))();
  TextColumn get counterpartUserId => text().nullable()();
  TextColumn get counterpartName => text().nullable()();
  BoolColumn get queued => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Ledger operations waiting to be sent (create / confirm / reject / cancel), in order.
@DataClassName('LedgerOutboxItem')
class LedgerOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entryId => text()();
  TextColumn get op => text()();
  TextColumn get payload => text()(); // JSON body of the op
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// In-app notifications pulled from the server.
class AppNotifications extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get entryId => text().nullable()();
  TextColumn get actorName => text().nullable()();
  RealColumn get amount => real().nullable()();
  TextColumn get currency => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get readAt => dateTime().nullable()();
  /// Read here, not yet reported to the server.
  BoolColumn get readPending => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
