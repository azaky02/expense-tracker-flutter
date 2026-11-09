import assert from 'node:assert/strict';
import test from 'node:test';
import { validateFinishingSettlement } from '../src/finishing_settlement.ts';

const base = {
  eventId: 'settlement-1',
  projectId: 'project-1',
  kind: 'return_custody' as const,
  amountPiasters: 10050,
  accountId: 'cash-1',
  categoryId: 'trust-1',
  occurredOn: '2026-11-09',
};

test('accepts cash return and direct client repayment', () => {
  assert.doesNotThrow(() => validateFinishingSettlement(base));
  assert.doesNotThrow(() => validateFinishingSettlement({
    ...base, kind: 'client_repay_personal',
  }));
});

test('internal reimbursement cannot create an additional cash leg', () => {
  assert.doesNotThrow(() => validateFinishingSettlement({
    ...base, kind: 'reimburse_from_custody', accountId: undefined, categoryId: undefined,
  }));
  assert.throws(() => validateFinishingSettlement({
    ...base, kind: 'reimburse_from_custody',
  }));
});

test('rejects invalid amounts, missing account and invalid calendar date', () => {
  for (const amountPiasters of [0, -1, 0.5, Number.MAX_SAFE_INTEGER]) {
    assert.throws(() => validateFinishingSettlement({ ...base, amountPiasters }));
  }
  assert.throws(() => validateFinishingSettlement({ ...base, accountId: undefined }));
  assert.throws(() => validateFinishingSettlement({ ...base, occurredOn: '2026-02-30' }));
});
