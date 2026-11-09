/// Pure financial rules for finishing projects.
/// This module does not write real account transactions or sync data.
/// All amounts are integer EGP piasters; never use floating-point for posting.
enum FinishingEventKind {
  clientAdvance,
  personalAllocation,
  cost,
  reimburseFromCustody,
  clientRepayPersonal,
  returnCustody,
}

class FinishingFinancialState {
  const FinishingFinancialState({
    this.custodyPiasters = 0,
    this.receivablePiasters = 0,
    this.costPiasters = 0,
    this.personalLiquidityPiasters = 0,
  });

  final int custodyPiasters;
  final int receivablePiasters;
  final int costPiasters;

  /// Optional project earmarking, not client-owned custody and not real cash.
  final int personalLiquidityPiasters;

  bool get canClose => custodyPiasters == 0 && receivablePiasters == 0;
}

class FinishingFinancialCommand {
  const FinishingFinancialCommand({
    required this.kind,
    required this.amountPiasters,
    this.custodySharePiasters = 0,
    this.personalSharePiasters = 0,
  });

  final FinishingEventKind kind;
  final int amountPiasters;
  final int custodySharePiasters;
  final int personalSharePiasters;
}

class FinishingFinancialRules {
  static FinishingFinancialState apply(
    FinishingFinancialState state,
    FinishingFinancialCommand command,
  ) {
    final amount = command.amountPiasters;
    if (amount <= 0) throw ArgumentError.value(amount, 'amountPiasters', 'must be positive');
    if (command.custodySharePiasters < 0 || command.personalSharePiasters < 0) {
      throw ArgumentError('negative funding allocation');
    }
    if (command.kind != FinishingEventKind.cost &&
        (command.custodySharePiasters != 0 || command.personalSharePiasters != 0)) {
      throw ArgumentError('funding allocations are only valid for costs');
    }

    var custody = state.custodyPiasters;
    var receivable = state.receivablePiasters;
    var cost = state.costPiasters;
    var personalLiquidity = state.personalLiquidityPiasters;

    switch (command.kind) {
      case FinishingEventKind.clientAdvance:
        custody += amount;
      case FinishingEventKind.personalAllocation:
        personalLiquidity += amount;
      case FinishingEventKind.cost:
        if (command.custodySharePiasters + command.personalSharePiasters != amount) {
          throw ArgumentError('funding allocations must sum to cost');
        }
        if (command.custodySharePiasters > custody) {
          throw StateError('insufficient client custody');
        }
        custody -= command.custodySharePiasters;
        receivable += command.personalSharePiasters;
        cost += amount;
      case FinishingEventKind.reimburseFromCustody:
        if (amount > custody || amount > receivable) {
          throw StateError('reimbursement exceeds custody or receivable');
        }
        custody -= amount;
        receivable -= amount;
      case FinishingEventKind.clientRepayPersonal:
        if (amount > receivable) throw StateError('repayment exceeds receivable');
        receivable -= amount;
      case FinishingEventKind.returnCustody:
        if (amount > custody) throw StateError('return exceeds client custody');
        custody -= amount;
    }
    return FinishingFinancialState(
      custodyPiasters: custody,
      receivablePiasters: receivable,
      costPiasters: cost,
      personalLiquidityPiasters: personalLiquidity,
    );
  }
}
