import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json'
};

function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: corsHeaders });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ ok: false, error: 'method_not_allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') || '';

  if (!supabaseUrl || !serviceRoleKey) {
    return json({ ok: false, error: 'missing_configuration' }, 500);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return json({ ok: false, error: 'unauthorized' }, 401);
  }

  // Verify caller is super_admin
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } }
  });
  const { data: { user: caller }, error: callerError } = await userClient.auth.getUser();
  if (callerError || !caller) {
    return json({ ok: false, error: 'invalid_token' }, 401);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false }
  });

  const { data: callerRole } = await adminClient
    .from('user_roles')
    .select('role')
    .eq('user_id', caller.id)
    .eq('role', 'super_admin')
    .maybeSingle();

  if (!callerRole) {
    return json({ ok: false, error: 'forbidden' }, 403);
  }

  let body: { email?: string; full_name?: string; roles?: string[] };
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: 'invalid_json' }, 400);
  }

  const email = body.email?.trim().toLowerCase();
  const fullName = body.full_name?.trim();
  const assignedRoles = Array.isArray(body.roles) && body.roles.length > 0 ? body.roles : ['member'];

  if (!email || !fullName) {
    return json({ ok: false, error: 'email_and_full_name_required' }, 400);
  }

  // Invite user via supabase auth admin
  const { data: inviteData, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(email, {
    data: { full_name: fullName }
  });

  if (inviteError) {
    return json({ ok: false, error: inviteError.message }, 400);
  }

  const newUserId = inviteData.user?.id;
  if (!newUserId) {
    return json({ ok: false, error: 'user_creation_failed' }, 500);
  }

  // Ensure public.users entry
  await adminClient.from('users').upsert({
    id: newUserId,
    email,
    full_name: fullName,
    status: 'active'
  });

  // Assign roles
  for (const r of assignedRoles) {
    await adminClient.from('user_roles').insert({
      user_id: newUserId,
      role: r
    }).select().maybeSingle();
  }

  return json({ ok: true, user: inviteData.user });
});
