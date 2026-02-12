// @ts-ignore
import { httpAction, internalMutation } from './_generated/server';
// @ts-ignore
import { internal } from './_generated/api';
// @ts-ignore
import { v } from 'convex/values';

export const insertEvent = internalMutation({
  args: {
    event: v.string(),
    timestamp: v.string(),
    data: v.optional(v.any()),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert('telemetry', args);
  },
});

export const ingest = httpAction(async (ctx, request) => {
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    const body = await request.json();
    const event = body?.event;
    const timestamp = body?.timestamp ?? new Date().toISOString();
    const data = body?.data;

    if (!event || typeof event !== 'string') {
      return new Response(null, { status: 400 });
    }

    await ctx.runMutation(internal.telemetry.insertEvent, {
      event,
      timestamp,
      data,
    });

    const headers = new Headers({
      'Access-Control-Allow-Origin': '*',
      Vary: 'origin',
    });
    return new Response(null, { status: 200, headers });
  } catch {
    return new Response(null, { status: 400 });
  }
});
