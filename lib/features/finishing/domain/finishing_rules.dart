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

/// A project's account: one running balance of what the client paid minus what was spent.
class FinishingBalance {
  const FinishingBalance({this.net = 0, this.received = 0, this.cost = 0, this.returned = 0, this.allocation = 0});

  /// received − spent − returned. Positive: the client's money still with me (عليا).
  /// Negative: I spent more than I received, the client owes me (ليا).
  final int net;

  /// Total received from the client.
  final int received;

  /// Total cost of the work (التكلفة).
  final int cost;

  /// Total returned to the client.
  final int returned;

  /// Personal money earmarked for the project (older records only) — not spent.
  final int allocation;

  /// The client's money still with me.
  int get custody => net > 0 ? net : 0;

  /// What the client owes me.
  int get receivable => net < 0 ? -net : 0;

  bool get canClose => net == 0;
}

/// One event as the rules see it.
class FinishingMove {
  const FinishingMove(this.kind, this.amount, {this.custodyShare = 0, this.personalShare = 0});
  final FinishingKind kind;
  final int amount;

  /// Kept for older records; the project account no longer splits costs.
  final int custodyShare;
  final int personalShare;
}

class FinishingRules {
  /// Applies [m] to [b], or throws [FinishingRuleError] without changing anything.
  static FinishingBalance apply(FinishingBalance b, FinishingMove m) {
    if (m.amount <= 0) throw const FinishingRuleError('amount');
    var net = b.net, received = b.received, cost = b.cost, returned = b.returned, allocation = b.allocation;
    switch (m.kind) {
      // Money from the client (an advance, or paying back what I spent).
      case FinishingKind.clientAdvance || FinishingKind.clientRepayPersonal:
        net += m.amount;
        received += m.amount;
      case FinishingKind.cost:
        net -= m.amount;
        cost += m.amount;
      case FinishingKind.returnCustody:
        if (m.amount > (net > 0 ? net : 0)) throw const FinishingRuleError('custody');
        net -= m.amount;
        returned += m.amount;
      // Older records: moving money between custody and receivable leaves the account unchanged.
      case FinishingKind.reimburseFromCustody:
        break;
      case FinishingKind.personalAllocation:
        allocation += m.amount;
      case FinishingKind.reversal:
        throw const FinishingRuleError('kind');
    }
    return FinishingBalance(net: net, received: received, cost: cost, returned: returned, allocation: allocation);
  }

  /// Replays events in order. Throws if any step breaks a rule.
  static FinishingBalance replay(Iterable<FinishingMove> moves) => moves.fold(const FinishingBalance(), apply);
}
