// @ts-ignore
import { mutation, query } from './_generated/server';
// @ts-ignore
import { v } from 'convex/values';

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
    amountCents: v.number(),
    currencyCode: v.string(),
    title: v.string(),
    description: v.optional(v.string()),
    date: v.number(),
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
    amountCents: v.number(),
    date: v.number(),
    splitSharesJson: v.string(),
    updatedAt: v.number(),
    tag: v.optional(v.union(v.string(), v.null())),
    description: v.optional(v.string()),
    lineItemsJson: v.optional(v.string()),
    receiptImagePath: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { id, ...patch } = args;
    await ctx.db.patch(id, patch);
    return id;
  },
});

export const remove = mutation({
  args: { id: v.id('expenses') },
  handler: async (ctx, { id }) => {
    await ctx.db.delete(id);
  },
});
