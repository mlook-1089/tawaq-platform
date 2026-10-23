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

export const route = writable<string>('home');
