import { verifyFirebaseIdToken } from './firebase_auth';
import {
  objectKeyForUid,
  publicPhotoUrl,
  validateJpegRequest,
} from './upload';

export interface Env {
  AVATARS: R2Bucket;
  FIREBASE_PROJECT_ID: string;
  PUBLIC_BASE_URL: string;
}

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'PUT, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
};

function jsonResponse(
  body: unknown,
  status: number,
  extraHeaders?: Record<string, string>,
): Response {
  return Response.json(body, {
    status,
    headers: { ...corsHeaders, ...extraHeaders },
  });
}

function parseBearerToken(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice('Bearer '.length).trim();
  return token.length > 0 ? token : null;
}

async function handlePutAvatar(
  request: Request,
  env: Env,
): Promise<Response> {
  const token = parseBearerToken(request);
  if (!token) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  let uid: string;
  try {
    ({ uid } = await verifyFirebaseIdToken(token, env.FIREBASE_PROJECT_ID));
  } catch {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  const body = await request.arrayBuffer();
  const validation = validateJpegRequest(
    request.headers.get('Content-Type'),
    body.byteLength,
  );
  if (validation !== 'ok') {
    return jsonResponse({ error: 'invalid_image' }, 400);
  }

  if (!env.PUBLIC_BASE_URL?.trim()) {
    return new Response('Server misconfiguration', { status: 500 });
  }

  try {
    await env.AVATARS.put(objectKeyForUid(uid), body, {
      httpMetadata: {
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=3600',
      },
    });
  } catch {
    return jsonResponse({ error: 'upload_failed' }, 502);
  }

  return jsonResponse(
    { photoUrl: publicPhotoUrl(env.PUBLIC_BASE_URL, uid) },
    200,
  );
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    if (request.method === 'GET' && url.pathname === '/v1/health') {
      return Response.json({ ok: true });
    }

    if (request.method === 'PUT' && url.pathname === '/v1/avatar') {
      return handlePutAvatar(request, env);
    }

    return new Response('Not found', { status: 404 });
  },
};
