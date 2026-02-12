// @ts-ignore
import { mutation, query } from './_generated/server';
// @ts-ignore
import { v } from 'convex/values';

export const list = query({
  args: {},
  handler: async (ctx) => {
    return await ctx.db.query('groups').order('desc').collect();
  },
});

export const get = query({
  args: { id: v.id('groups') },
  handler: async (ctx, { id }) => {
    return await ctx.db.get(id);
  },
});

export const create = mutation({
  args: {
    name: v.string(),
    currencyCode: v.string(),
  },
  handler: async (ctx, { name, currencyCode }) => {
    const now = Date.now();
    return await ctx.db.insert('groups', {
      name,
      currencyCode,
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const update = mutation({
  args: {
    id: v.id('groups'),
    name: v.string(),
    currencyCode: v.string(),
    updatedAt: v.number(),
    settlementMethod: v.optional(v.string()),
    treasurerParticipantId: v.optional(v.id('participants')),
    settlementFreezeAt: v.optional(v.number()),
    settlementSnapshotJson: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { id, name, currencyCode, updatedAt, ...rest } = args;
    const patch: Record<string, unknown> = {
      name,
      currencyCode,
      updatedAt,
    };
    if (rest.settlementMethod !== undefined) patch.settlementMethod = rest.settlementMethod;
    if (rest.treasurerParticipantId !== undefined) patch.treasurerParticipantId = rest.treasurerParticipantId;
    if (rest.settlementFreezeAt !== undefined) patch.settlementFreezeAt = rest.settlementFreezeAt;
    if (rest.settlementSnapshotJson !== undefined) patch.settlementSnapshotJson = rest.settlementSnapshotJson;
    await ctx.db.patch(id, patch);
    return id;
  },
});

export const freezeSettlement = mutation({
  args: {
    id: v.id('groups'),
    settlementSnapshotJson: v.string(),
    settlementFreezeAt: v.number(),
  },
  handler: async (ctx, { id, settlementSnapshotJson, settlementFreezeAt }) => {
    await ctx.db.patch(id, {
      settlementSnapshotJson,
      settlementFreezeAt,
      updatedAt: Date.now(),
    });
    return id;
  },
});

export const unfreezeSettlement = mutation({
  args: { id: v.id('groups') },
  handler: async (ctx, { id }) => {
    await ctx.db.patch(id, {
      settlementSnapshotJson: undefined,
      settlementFreezeAt: undefined,
      updatedAt: Date.now(),
    });
    return id;
  },
});

export const remove = mutation({
  args: { id: v.id('groups') },
  handler: async (ctx, { id }) => {
    await ctx.db.delete(id);
  },
});
