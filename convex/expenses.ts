// @ts-ignore
import { mutation, query } from './_generated/server';
// @ts-ignore
import { v } from 'convex/values';

// convex_flutter sends all args as strings; accept both for compatibility
const numArg = () => v.union(v.string(), v.number());

function toNum(x: string | number): number {
  return typeof x === 'string' ? parseFloat(x) : x;
}

export const listByGroup = query({
  args: { groupId: v.id('groups') },
  handler: async (ctx, { groupId }) => {
    return await ctx.db
      .query('expenses')
      .withIndex('by_group', (q) => q.eq('groupId', groupId))
      .order('desc')
      .collect();
  },
});

export const get = query({
  args: { id: v.id('expenses') },
  handler: async (ctx, { id }) => {
    return await ctx.db.get(id);
  },
});

export const create = mutation({
  args: {
    groupId: v.id('groups'),
    payerParticipantId: v.id('participants'),
    amountCents: numArg(),
    currencyCode: v.string(),
    title: v.string(),
    description: v.optional(v.string()),
    date: numArg(),
    splitType: v.string(),
    splitSharesJson: v.string(),
    type: v.optional(v.string()),
    toParticipantId: v.optional(v.id('participants')),
    tag: v.optional(v.string()),
    lineItemsJson: v.optional(v.string()),
    receiptImagePath: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const { type, toParticipantId, tag, lineItemsJson, receiptImagePath, description, ...rest } = args;
    return await ctx.db.insert('expenses', {
      ...rest,
      amountCents: toNum(rest.amountCents),
      date: toNum(rest.date),
      type: type ?? 'expense',
      ...(toParticipantId != null ? { toParticipantId } : {}),
      ...(tag != null ? { tag } : {}),
      ...(description != null ? { description } : {}),
      ...(lineItemsJson != null ? { lineItemsJson } : {}),
      ...(receiptImagePath != null ? { receiptImagePath } : {}),
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const update = mutation({
  args: {
    id: v.id('expenses'),
    title: v.string(),
    amountCents: numArg(),
    date: numArg(),
    splitSharesJson: v.string(),
    updatedAt: numArg(),
    tag: v.optional(v.union(v.string(), v.null())),
    description: v.optional(v.string()),
    lineItemsJson: v.optional(v.string()),
    receiptImagePath: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { id, ...rest } = args;
    await ctx.db.patch(id, {
      ...rest,
      amountCents: toNum(rest.amountCents),
      date: toNum(rest.date),
      updatedAt: toNum(rest.updatedAt),
    });
    return id;
  },
});

export const remove = mutation({
  args: { id: v.id('expenses') },
  handler: async (ctx, { id }) => {
    await ctx.db.delete(id);
  },
});
