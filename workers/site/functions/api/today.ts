// Cloudflare Pages Function for `/api/today`; the logic is in src/handler.ts.

import { handleToday } from '../../src/handler';

export const onRequestGet: PagesFunction = (context) =>
  handleToday(context.request, {
    fetch: (input, init) => fetch(input, init),
    cache: caches.default,
    now: () => new Date(),
    waitUntil: (promise) => context.waitUntil(promise),
  });
