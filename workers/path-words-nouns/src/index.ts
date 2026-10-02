import { generateNounCandidates } from './ai';
import { prefetchDateIds } from './dates';
import { hasEnoughNouns, normalizeNouns, MIN_NOUN_COUNT } from './nouns';

export interface Env {
  NOUNS: KVNamespace;
  AI: Ai;
}

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function jsonResponse(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: corsHeaders });
}

function kvKey(dateId: string): string {
  return `path_words_nouns:${dateId}`;
}

function isValidDateId(dateId: string): boolean {
  return /^\d{8}$/.test(dateId);
}

function errorMessage(err: unknown): string {
  if (err instanceof Error) return err.message;
  return String(err);
}

async function readPool(
  env: Env,
  dateId: string,
): Promise<{ dateId: string; words: string[] } | null> {
  const raw = await env.NOUNS.get(kvKey(dateId));
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as { dateId?: string; words?: unknown };
    const words = normalizeNouns(parsed.words);
    if (!hasEnoughNouns(words)) return null;
    return { dateId, words };
  } catch {
    return null;
  }
}

async function getOrCreatePool(
  env: Env,
  dateId: string,
): Promise<{ dateId: string; words: string[] } | null> {
  const existing = await readPool(env, dateId);
  if (existing) return existing;

  if (!env.AI) {
    throw new Error('AI binding is missing');
  }

  let words = await generateNounCandidates(env.AI, dateId);
  if (!hasEnoughNouns(words)) {
    return null;
  }

  const raced = await readPool(env, dateId);
  if (raced) return raced;

  const body = { dateId, words };
  await env.NOUNS.put(kvKey(dateId), JSON.stringify(body));
  return body;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      if (request.method === 'OPTIONS') {
        return new Response(null, { status: 204, headers: corsHeaders });
      }

      const url = new URL(request.url);
      if (request.method === 'GET' && url.pathname === '/v1/health') {
        return jsonResponse({ ok: true, hasAi: Boolean(env.AI) });
      }

      if (request.method === 'GET' && url.pathname === '/v1/path-words/nouns') {
        const dateId = url.searchParams.get('dateId') ?? '';
        if (!isValidDateId(dateId)) {
          return jsonResponse({ error: 'invalid_dateId' }, 400);
        }
        const pool = await getOrCreatePool(env, dateId);
        if (!pool) {
          return jsonResponse(
            { error: 'insufficient_nouns', min: MIN_NOUN_COUNT },
            503,
          );
        }
        return jsonResponse(pool);
      }

      return jsonResponse({ error: 'not_found' }, 404);
    } catch (err) {
      return jsonResponse(
        { error: 'worker_exception', message: errorMessage(err) },
        500,
      );
    }
  },

  async scheduled(
    _controller: ScheduledController,
    env: Env,
    ctx: ExecutionContext,
  ): Promise<void> {
    const ids = prefetchDateIds();
    ctx.waitUntil(
      Promise.all(ids.map((id) => getOrCreatePool(env, id).catch(() => null))),
    );
  },
};
