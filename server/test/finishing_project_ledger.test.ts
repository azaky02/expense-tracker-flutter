import assert from 'node:assert/strict';
import test from 'node:test';
import { validateFinishingCostAllocation } from '../src/finishing_project_ledger.ts';

test('accepts an exact split in integer piasters', () => {
  assert.equal(validateFinishingCostAllocation({
    projectId: 'p1', eventId: 'e1', custodyPiasters: 7000, personalPiasters: 3000,
  }), 10000);
});

test('rejects fractional, negative, zero and unsafe allocations', () => {
  for (const shares of [[0, 0], [-1, 2], [1.5, 2], [Number.MAX_SAFE_INTEGER, 2]]) {
    assert.throws(() => validateFinishingCostAllocation({
      projectId: 'p1', eventId: 'e1',
      custodyPiasters: shares[0], personalPiasters: shares[1],
    }));
  }
});

test('requires project and event identities', () => {
  assert.throws(() => validateFinishingCostAllocation({
    projectId: '', eventId: 'e1', custodyPiasters: 1, personalPiasters: 0,
  }));
});
