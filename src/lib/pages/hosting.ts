import { supabase } from '../supabase';

export type Member = { id: string; full_name: string };
export type WeeklyEvent = { id: string; title: string; start_datetime: string; status: string };
export type Assignment = {
  id: string; event_id: string; week_start_date: string;
  host_a_user_id: string; host_b_user_id: string;
  items: string[]; expected_count: number; status: string; updated_at: string;
  event: WeeklyEvent; host_a: Member | null; host_b: Member | null;
  confirmations: { user_id: string }[];
};
export type Swap = {
  id: string; assignment_id: string; requested_by_user_id: string;
  requested_with_user_id: string; reason: string | null;
  status: 'pending' | 'approved' | 'rejected' | 'cancelled';
  created_at: string; resolution_note: string | null;
  requester: Member | null; replacement: Member | null;
  assignment: { deleted_at: string | null; event: WeeklyEvent | null } | null;
};

export const assignmentSelect = `
  id,event_id,week_start_date,host_a_user_id,host_b_user_id,items,expected_count,status,updated_at,
  event:events!hosting_assignments_event_id_fkey!inner(id,title,start_datetime,status),
  host_a:users!hosting_assignments_host_a_user_id_fkey(id,full_name),
  host_b:users!hosting_assignments_host_b_user_id_fkey(id,full_name),
  confirmations:hosting_confirmations(user_id)
`;
export const swapSelect = `
  id,assignment_id,requested_by_user_id,requested_with_user_id,reason,status,created_at,resolution_note,
  requester:users!hosting_swaps_requested_by_user_id_fkey(id,full_name),
  replacement:users!hosting_swaps_requested_with_user_id_fkey(id,full_name),
  assignment:hosting_assignments!hosting_swaps_assignment_id_fkey(
    deleted_at,event:events!hosting_assignments_event_id_fkey(id,title,start_datetime,status)
  )
`;

export function canManageHosting(roles: string[]) {
  return roles.some(role => ['super_admin', 'mod_hospitality', 'roster.write'].includes(role));
}

export function hostingError(error: unknown, fallback = 'تعذّر إتمام العملية. حاول مرة أخرى.') {
  const detail = error as { code?: string; message?: string } | null;
  if (detail?.code === '23505') return 'يوجد تكليف لهذه الطلعة أو طلب تبديل معلّق بالفعل. حدّث القائمة.';
  if (detail?.code === '42501') return 'لا تملك صلاحية تنفيذ هذه العملية.';
  if (detail?.code === 'PGRST116') return 'تغيّر السجل أو لم يعد متاحًا. حدّث القائمة ثم أعد المحاولة.';
  return detail?.message || fallback;
}

// Sunday in the event's Riyadh calendar week, independent of the viewer's timezone.
export function weekStart(iso: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Riyadh', year: 'numeric', month: '2-digit', day: '2-digit'
  }).formatToParts(new Date(iso));
  const part = (type: string) => parts.find(value => value.type === type)!.value;
  const date = new Date(`${part('year')}-${part('month')}-${part('day')}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() - date.getUTCDay());
  return date.toISOString().slice(0, 10);
}

export async function loadMembers() {
  const members: Member[] = [];
  for (let offset = 0; ; offset += 500) {
    const { data, error } = await supabase.from('users').select('id,full_name')
      .is('deleted_at', null).eq('status', 'active').order('full_name').order('id')
      .range(offset, offset + 499);
    if (error) throw error;
    members.push(...(data || []));
    if (!data || data.length < 500) return members;
  }
}
