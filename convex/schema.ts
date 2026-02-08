// @ts-ignore
import { defineSchema, defineTable } from 'convex/server';
// @ts-ignore
import { v } from 'convex/values';

export default defineSchema({
  groups: defineTable({
    name: v.string(),
    currencyCode: v.string(),
    createdAt: v.number(),
    updatedAt: v.number(),
  }),
  participants: defineTable({
    groupId: v.id('groups'),
    name: v.string(),
    order: v.number(),
    createdAt: v.number(),
    updatedAt: v.number(),
  }).index('by_group', ['groupId']),
  expenses: defineTable({
    groupId: v.id('groups'),
    payerParticipantId: v.id('participants'),
    amountCents: v.number(),
    currencyCode: v.string(),
    title: v.string(),
    date: v.number(),
    splitType: v.string(),
    splitSharesJson: v.string(),
    createdAt: v.number(),
    updatedAt: v.number(),
    type: v.optional(v.string()),
    toParticipantId: v.optional(v.id('participants')),
  }).index('by_group', ['groupId']),
});
