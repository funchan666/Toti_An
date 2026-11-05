import { createClient } from 'npm:@supabase/supabase-js@2';

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const match = /^Bearer\s+(.+)$/i.exec(request.headers.get('authorization') ?? '');
  if (!match) return new Response('Unauthorized', { status: 401 });
  const secretKeys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}');
  const publicKeys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}');
  const secret = secretKeys.default ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const publishable = publicKeys.default ?? Deno.env.get('SUPABASE_ANON_KEY');
  const url = Deno.env.get('SUPABASE_URL');
  if (!secret || !publishable || !url) return new Response('Service unavailable', { status: 503 });
  const options = { auth: { persistSession: false, autoRefreshToken: false } };
  const admin = createClient(url, secret, options);
  const { data, error: identityError } = await admin.auth.getUser(match[1]);
  if (identityError || !data.user) return new Response('Unauthorized', { status: 401 });
  const userClient = createClient(url, publishable, {
    ...options, global: { headers: { Authorization: `Bearer ${match[1]}` } },
  });
  const { error: beginError } = await userClient.rpc('begin_toti_account_deletion');
  if (beginError) return new Response('Could not start account deletion', { status: 500 });
  const bucket = admin.storage.from('toti-avatars');
  for (;;) {
    const { data: files, error: listError } = await bucket.list(data.user.id, { limit: 1000 });
    if (listError) return new Response('Could not remove account media', { status: 500 });
    if (!files || files.length === 0) break;
    const paths = files.map((file) => `${data.user!.id}/${file.name}`);
    const { error: removeError } = await bucket.remove(paths);
    if (removeError) return new Response('Could not remove account media', { status: 500 });
  }
  const { error } = await admin.auth.admin.deleteUser(data.user.id);
  if (error) return new Response('Could not delete account', { status: 500 });
  return Response.json({ deleted: true });
});
