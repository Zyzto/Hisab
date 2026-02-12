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
      .query('participants')
      .withIndex('by_group', (q) => q.eq('groupId', groupId))
      .order('asc')
      .collect();
  },
});

export const get = query({
  args: { id: v.id('participants') },
  handler: async (ctx, { id }) => {
    return await ctx.db.get(id);
  },
});

export const create = mutation({
  args: { groupId: v.id('groups'), name: v.string(), order: numArg() },
  handler: async (ctx, { groupId, name, order }) => {
    const now = Date.now();
    return await ctx.db.insert('participants', {
      groupId,
      name,
      order: toNum(order),
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const update = mutation({
  args: {
    id: v.id('participants'),
    name: v.string(),
    order: numArg(),
    updatedAt: numArg(),
  },
  handler: async (ctx, args) => {
    const { id, ...rest } = args;
    await ctx.db.patch(id, {
      ...rest,
      order: toNum(rest.order),
      updatedAt: toNum(rest.updatedAt),
    });
    return id;
  },
});

export const remove = mutation({
  args: { id: v.id('participants') },
  handler: async (ctx, { id }) => {
    await ctx.db.delete(id);
  },
});
