import { writable, derived } from 'svelte/store';
import { supabase } from './supabase';
import type { Session } from '@supabase/supabase-js';

export const session = writable<Session | null>(null);
export const profile = writable<any>(null);
export const roles = writable<string[]>([]);

export const isAdmin = derived(roles, ($r) => $r.includes('super_admin'));
export const canWriteNews = derived(roles, ($r) =>
  $r.includes('super_admin') || $r.includes('mod_media')
);
export const canManageFinance = derived(roles, ($r) =>
  $r.includes('super_admin') || $r.includes('mod_hospitality')
);
export const canWriteEvents = derived(roles, ($r) =>
  $r.some(r => ['super_admin','mod_cultural','mod_sports','mod_competitions','mod_trips','mod_hospitality'].includes(r))
);

export async function loadProfile(userId: string) {
  const [{ data: p }, { data: r }] = await Promise.all([
    supabase.from('users').select('*').eq('id', userId).maybeSingle(),
    supabase.from('user_roles').select('role').eq('user_id', userId)
  ]);
  profile.set(p);
  roles.set((r || []).map((x: any) => x.role));
}

const VALID_ROUTES = new Set([
  'home',
  'events',
  'hosting',
  'attendance',
  'members',
  'admin',
  'news',
  'finance',
  'suggestions',
  'reports',
  'account'
]);

function parseRouteFromHash(): string {
  if (typeof window === 'undefined') return 'home';
  const raw = window.location.hash.replace(/^#\/?/, '').split('?')[0].split('&')[0];
  return VALID_ROUTES.has(raw) ? raw : 'home';
}

export const route = writable<string>(parseRouteFromHash());

if (typeof window !== 'undefined') {
  // Sync route -> hash
  route.subscribe((r) => {
    if (!VALID_ROUTES.has(r)) return;
    const current = window.location.hash.replace(/^#\/?/, '').split('?')[0].split('&')[0];
    if (
      current !== r &&
      !window.location.hash.includes('access_token=') &&
      !window.location.hash.includes('type=recovery')
    ) {
      window.location.hash = r;
    }
  });

  // Sync hash -> route
  window.addEventListener('hashchange', () => {
    const fromHash = parseRouteFromHash();
    route.set(fromHash);
  });
}
