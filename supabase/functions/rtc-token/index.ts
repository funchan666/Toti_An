// Issues a scoped LiveKit token only after Supabase authorizes the session.
const json = (status: number, value: Record<string, unknown>) =>
  new Response(JSON.stringify(value), {
    status,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
  });

function base64url(bytes: Uint8Array): string {
  let raw = '';
  for (const byte of bytes) raw += String.fromCharCode(byte);
  return btoa(raw).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return json(405, { error: 'Method not allowed' });
  const auth = req.headers.get('authorization') ?? '';
  if (!auth.startsWith('Bearer ')) return json(401, { error: 'Sign in required' });
  const base = Deno.env.get('SUPABASE_URL');
  const anon = Deno.env.get('SUPABASE_ANON_KEY');
  const liveUrl = Deno.env.get('LIVEKIT_URL');
  const apiKey = Deno.env.get('LIVEKIT_API_KEY');
  const secret = Deno.env.get('LIVEKIT_API_SECRET');
  if (!base || !anon || !liveUrl || !apiKey || !secret) {
    return json(503, { error: 'Real-time service unavailable' });
  }
  try {
    const url = new URL(liveUrl);
    if (url.protocol !== 'wss:' || !url.hostname.endsWith('.livekit.cloud')) {
      return json(503, { error: 'Real-time service unavailable' });
    }
    const input = await req.json();
    if (typeof input.sessionId !== 'string' ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input.sessionId)) {
      return json(400, { error: 'Invalid session' });
    }
    const headers = { apikey: anon, authorization: auth, 'content-type': 'application/json' };
    const userResponse = await fetch(`${base}/auth/v1/user`, { headers });
    if (!userResponse.ok) return json(401, { error: 'Sign in required' });
    const user = await userResponse.json();
    if (typeof user.id !== 'string' || user.is_anonymous) {
      return json(401, { error: 'Sign in required' });
    }
    const allowed = await fetch(`${base}/rest/v1/rpc/toti_rtc_token_claims`, {
      method: 'POST', headers, body: JSON.stringify({ p_id: input.sessionId }),
    });
    if (!allowed.ok) return json(403, { error: 'Session unavailable' });
    const rows = await allowed.json();
    const claims = Array.isArray(rows) ? rows[0] : null;
    if (!claims || typeof claims.room_name !== 'string' ||
        typeof claims.can_publish !== 'boolean') {
      return json(403, { error: 'Session unavailable' });
    }
    const now = Math.floor(Date.now() / 1000);
    const payload = {
      iss: apiKey, sub: user.id, nbf: now - 10, exp: now + 600,
      video: {
        roomJoin: true, room: claims.room_name,
        canPublish: claims.can_publish, canSubscribe: true,
        canPublishData: true,
        ...(claims.can_publish && (claims.session_kind === 'voice_room' || claims.session_kind === 'voice_call')
          ? { canPublishSources: ['microphone'] } : {}),
      },
    };
    const encode = (v: unknown) => base64url(new TextEncoder().encode(JSON.stringify(v)));
    const unsigned = `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode(payload)}`;
    const key = await crypto.subtle.importKey(
      'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
    );
    const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(unsigned));
    return json(200, { url: liveUrl, token: `${unsigned}.${base64url(new Uint8Array(signature))}` });
  } catch (_) {
    return json(500, { error: 'Unable to join session' });
  }
});
