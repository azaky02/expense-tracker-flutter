import assert from 'node:assert/strict';
import test from 'node:test';
import { validateClientAdvance } from '../src/finishing_client_advance.ts';

const valid = {
  eventId: 'advance-1', projectId: 'project-1', accountId: 'account-1',
  trustCategoryId: 'trust-1', amountPiasters: 125050, occurredOn: '2026-11-09',
};

test('accepts positive integer piasters', () => {
  assert.doesNotThrow(() => validateClientAdvance(valid));
});

test('rejects zero, negative, fractional and unsafe amounts', () => {
  for (const amountPiasters of [0, -1, 1.2, Number.MAX_SAFE_INTEGER]) {
    assert.throws(() => validateClientAdvance({ ...valid, amountPiasters }));
  }
});

test('rejects invalid calendar dates and empty identities', () => {
  assert.throws(() => validateClientAdvance({ ...valid, occurredOn: '2026-02-30' }));
  assert.throws(() => validateClientAdvance({ ...valid, projectId: '' }));
  assert.throws(() => validateClientAdvance({ ...valid, eventId: '' }));
});
