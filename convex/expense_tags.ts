// @ts-ignore
import { mutation, query } from './_generated/server';
// @ts-ignore
import { v } from 'convex/values';

export const listByGroup = query({
  args: { groupId: v.id('groups') },
  handler: async (ctx, { groupId }) => {
    return await ctx.db
      .query('expense_tags')
      .withIndex('by_group', (q) => q.eq('groupId', groupId))
      .order('asc')
      .collect();
  },
});

export const get = query({
  args: { id: v.id('expense_tags') },
  handler: async (ctx, { id }) => {
    return await ctx.db.get(id);
  },
});

export const create = mutation({
  args: {
    groupId: v.id('groups'),
    label: v.string(),
    iconName: v.string(),
  },
  handler: async (ctx, { groupId, label, iconName }) => {
    const now = Date.now();
    return await ctx.db.insert('expense_tags', {
      groupId,
      label,
      iconName,
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const update = mutation({
  args: {
    id: v.id('expense_tags'),
    label: v.string(),
    iconName: v.string(),
    updatedAt: v.number(),
  },
  handler: async (ctx, args) => {
    const { id, ...patch } = args;
    await ctx.db.patch(id, patch);
    return id;
  },
});

export const remove = mutation({
  args: { id: v.id('expense_tags') },
  handler: async (ctx, { id }) => {
    await ctx.db.delete(id);
  },
});
