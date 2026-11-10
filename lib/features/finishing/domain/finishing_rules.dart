/// Money rules for finishing projects. Pure Dart, no database.
/// All amounts are integer piasters (قرش): 1 EGP = 100.
library;

enum FinishingKind {
  clientAdvance,
  personalAllocation,
  cost,
  reimburseFromCustody,
  clientRepayPersonal,
  returnCustody,
  reversal;

  static FinishingKind parse(String s) => values.firstWhere((k) => k.name == s);
}

enum CostType { materials, labor, other }

int toPiasters(double egp) => (egp * 100).round();
double fromPiasters(int p) => p / 100;

/// Why an event was refused (keys under `finishing.err.*`).
class FinishingRuleError implements Exception {
  const FinishingRuleError(this.code);
  final String code;
  @override
  String toString() => 'FinishingRuleError($code)';
}

/// The four separate figures of a project.
class FinishingBalance {
  const FinishingBalance({this.custody = 0, this.receivable = 0, this.cost = 0, this.allocation = 0});

  /// Client money still under my management (العهدة).
  final int custody;

  /// What I paid from my own pocket and have not got back (المستحقات).
  final int receivable;

  /// Total cost of the work (التكلفة).
  final int cost;

  /// Personal money earmarked for the project — not spent, not custody.
  final int allocation;

  bool get canClose => custody == 0 && receivable == 0;
}

/// One event as the rules see it.
class FinishingMove {
  const FinishingMove(this.kind, this.amount, {this.custodyShare = 0, this.personalShare = 0});
  final FinishingKind kind;
  final int amount;
  final int custodyShare;
  final int personalShare;
}

class FinishingRules {
  /// Applies [m] to [b], or throws [FinishingRuleError] without changing anything.
  static FinishingBalance apply(FinishingBalance b, FinishingMove m) {
    if (m.amount <= 0) throw const FinishingRuleError('amount');
    if (m.custodyShare < 0 || m.personalShare < 0) throw const FinishingRuleError('split');
    var custody = b.custody, receivable = b.receivable, cost = b.cost, allocation = b.allocation;
    switch (m.kind) {
      case FinishingKind.clientAdvance:
        custody += m.amount;
      case FinishingKind.personalAllocation:
        allocation += m.amount;
      case FinishingKind.cost:
        if (m.custodyShare + m.personalShare != m.amount) throw const FinishingRuleError('split');
        if (m.custodyShare > custody) throw const FinishingRuleError('custody');
        custody -= m.custodyShare;
        receivable += m.personalShare;
        cost += m.amount;
      case FinishingKind.reimburseFromCustody:
        if (m.amount > custody) throw const FinishingRuleError('custody');
        if (m.amount > receivable) throw const FinishingRuleError('receivable');
        custody -= m.amount;
        receivable -= m.amount;
      case FinishingKind.clientRepayPersonal:
        if (m.amount > receivable) throw const FinishingRuleError('receivable');
        receivable -= m.amount;
      case FinishingKind.returnCustody:
        if (m.amount > custody) throw const FinishingRuleError('custody');
        custody -= m.amount;
      case FinishingKind.reversal:
        throw const FinishingRuleError('kind');
    }
    return FinishingBalance(custody: custody, receivable: receivable, cost: cost, allocation: allocation);
  }

  /// Replays events in order. Throws if any step breaks a rule.
  static FinishingBalance replay(Iterable<FinishingMove> moves) => moves.fold(const FinishingBalance(), apply);
}
