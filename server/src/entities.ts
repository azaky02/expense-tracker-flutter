import { z } from 'zod';

export type Kind = 'text' | 'int' | 'num' | 'bool' | 'date' | 'ts';
export interface Col {
  api: string; // JSON key (camelCase)
  db: string; // column name
  kind: Kind;
  nullable?: boolean;
  oneOf?: readonly string[];
  max?: number;
}
export interface Entity {
  name: string; // JSON key in sync payloads
  table: string;
  keys: Col[]; // primary key (after user_id)
  cols: Col[];
}

const t = (api: string, db: string, extra: Partial<Col> = {}): Col => ({ api, db, kind: 'text', ...extra });
const col = (api: string, db: string, kind: Kind, extra: Partial<Col> = {}): Col => ({ api, db, kind, ...extra });

export const ENTITIES: Entity[] = [
  {
    name: 'banks', table: 'banks',
    keys: [t('id', 'id', { max: 64 })],
    cols: [t('name', 'name', { max: 200 }), t('logoUri', 'logo_uri', { nullable: true, max: 500 }), col('isCustom', 'is_custom', 'bool')],
  },
  {
    name: 'categories', table: 'categories',
    keys: [t('id', 'id', { max: 64 })],
    cols: [
      t('parentId', 'parent_id', { nullable: true, max: 64 }),
      t('name', 'name', { max: 200 }), t('icon', 'icon', { max: 16 }), t('color', 'color', { max: 16 }),
      t('type', 'type', { oneOf: ['expense', 'income', 'trust'] }), col('isDefault', 'is_default', 'bool'),
    ],
  },
  {
    name: 'cards', table: 'cards',
    keys: [t('id', 'id', { max: 64 })],
    cols: [
      t('bankId', 'bank_id', { max: 64 }),
      t('cardType', 'card_type', { oneOf: ['visa', 'mastercard', 'meeza'] }),
      t('cardCategory', 'card_category', { oneOf: ['credit', 'debit'] }),
      t('nickname', 'nickname', { max: 100 }),
      t('last4Digits', 'last4_digits', { max: 4 }),
      col('dueDateDay', 'due_date_day', 'int', { nullable: true }),
      col('statementDateDay', 'statement_date_day', 'int', { nullable: true }),
      col('creditLimit', 'credit_limit', 'num', { nullable: true }),
      t('color', 'color', { max: 16 }),
      col('isActive', 'is_active', 'bool'),
    ],
  },
  {
    name: 'beneficiaries', table: 'beneficiaries',
    keys: [t('name', 'name', { max: 200 })],
    cols: [col('lastUsedAt', 'last_used_at', 'ts')],
  },
  {
    name: 'transactions', table: 'transactions',
    keys: [t('id', 'id', { max: 64 })],
    cols: [
      col('amount', 'amount', 'num'),
      t('type', 'type', { oneOf: ['expense', 'income', 'trustIn', 'trustOut'] }),
      t('categoryId', 'category_id', { max: 64 }),
      t('paymentMethodType', 'payment_method_type', { oneOf: ['cash', 'card'] }),
      t('cardId', 'card_id', { nullable: true, max: 64 }),
      col('date', 'date', 'date'),
      t('note', 'note', { nullable: true, max: 2000 }),
      t('beneficiaryName', 'beneficiary_name', { nullable: true, max: 200 }),
      col('createdAt', 'created_at', 'ts'),
    ],
  },
  {
    name: 'categoryBudgets', table: 'category_budgets',
    keys: [t('categoryId', 'category_id', { max: 64 })],
    cols: [col('monthlyLimit', 'monthly_limit', 'num'), col('isEnabled', 'is_enabled', 'bool')],
  },
];

const isoTs = z.string().datetime({ offset: true });
const ymd = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine((s) => !Number.isNaN(Date.parse(s + 'T00:00:00Z')), 'invalid date');

function fieldSchema(c: Col): z.ZodType {
  let s: z.ZodType;
  switch (c.kind) {
    case 'text':
      s = c.oneOf ? z.enum(c.oneOf as [string, ...string[]]) : z.string().max(c.max ?? 500);
      break;
    case 'int':
      s = z.number().int().min(1).max(31);
      break;
    case 'num':
      s = z.number().finite().min(-1e11).max(1e11);
      break;
    case 'bool':
      s = z.boolean();
      break;
    case 'date':
      s = ymd;
      break;
    case 'ts':
      s = isoTs;
      break;
  }
  return c.nullable ? s.nullable().optional() : s;
}

/** A full record, or a bare tombstone (keys + updatedAt + deletedAt) for rows deleted before they ever synced. */
export function recordSchema(e: Entity) {
  const full: Record<string, z.ZodType> = {
    updatedAt: isoTs,
    deletedAt: isoTs.nullable().optional(),
  };
  const tomb: Record<string, z.ZodType> = { updatedAt: isoTs, deletedAt: isoTs };
  for (const c of e.keys) {
    full[c.api] = fieldSchema(c);
    tomb[c.api] = fieldSchema(c);
  }
  for (const c of e.cols) full[c.api] = fieldSchema(c);
  return z.union([z.object(full), z.object(tomb)]);
}

export const MAX_RECORDS_PER_ENTITY = 2000;

export const pushSchema = z.object({
  cursor: z.number().int().min(0).default(0),
  changes: z
    .object(Object.fromEntries(ENTITIES.map((e) => [e.name, z.array(recordSchema(e)).max(MAX_RECORDS_PER_ENTITY).optional()])))
    .default({}),
});
