import { httpRouter } from 'convex/server';
// @ts-ignore
import { httpAction } from './_generated/server';
import { ingest } from './telemetry';

const http = httpRouter();

http.route({
  path: '/telemetry',
  method: 'POST',
  handler: ingest,
});

// CORS preflight for web clients
http.route({
  path: '/telemetry',
  method: 'OPTIONS',
  handler: httpAction(async () =>
    new Response(null, {
      headers: new Headers({
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Max-Age': '86400',
      }),
    }),
  ),
});

export default http;
