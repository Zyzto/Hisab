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
  args: { name: v.string(), currencyCode: v.string() },
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
  },
  handler: async (ctx, { id, name, currencyCode, updatedAt }) => {
    await ctx.db.patch(id, { name, currencyCode, updatedAt });
    return id;
  },
});

export const remove = mutation({
  args: { id: v.id('groups') },
  handler: async (ctx, { id }) => {
    await ctx.db.delete(id);
  },
});
