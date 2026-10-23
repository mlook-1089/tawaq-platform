<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../supabase';
  import { roles, session } from '../stores';
  import { fmtDate } from '../utils';
  import PageHead from '../components/PageHead.svelte';
  import HostingForm from './HostingForm.svelte';
  import HostingModal from '../components/HostingModal.svelte';
  import { assignmentSelect, swapSelect, canManageHosting, hostingError, type Assignment, type Swap } from './hosting';

  let assignments = $state<Assignment[]>([]);
  let swaps = $state<Swap[]>([]);
  let pendingIds = $state<string[]>([]);
  let loading = $state(true);
  let refreshing = $state(false);
  let error = $state('');
  let liveError = $state('');
  let success = $state('');
  let busy = $state('');
  let form = $state<{ mode: 'assignment' | 'swap'; assignment: Assignment | null } | null>(null);
  let deleting = $state<Assignment | null>(null);
  let historyLimit = $state(20);
  let hasMore = $state(false);
  let disposed = false;
  let loadVersion = 0;
  const canManage = $derived(canManageHosting($roles));
  const userId = $derived($session?.user.id);
  const pending = $derived(new Set(pendingIds));
  const rows = $derived(assignments.map(assignment => ({
    ...assignment,
    host_a_name: assignment.host_a?.full_name || 'عضو غير متاح',
    host_b_name: assignment.host_b?.full_name || 'عضو غير متاح',
    host_a_confirmed: assignment.confirmations.some(value => value.user_id === assignment.host_a_user_id),
    host_b_confirmed: assignment.confirmations.some(value => value.user_id === assignment.host_b_user_id)
  })));
  const statusLabels: Record<Swap['status'], string> = {
    pending: 'قيد المراجعة', approved: 'مقبول', rejected: 'مرفوض', cancelled: 'ملغى'
  };

  async function load() {
    const version = ++loadVersion;
    refreshing = true;
    try {
      const [roster, history, requests] = await Promise.all([
        supabase.from('hosting_assignments').select(assignmentSelect).is('deleted_at', null)
          .eq('event.type', 'weekly').eq('event.status', 'scheduled').is('event.deleted_at', null)
          .gte('event.start_datetime', new Date().toISOString())
          .order('start_datetime', { referencedTable: 'event', ascending: true }),
        supabase.from('hosting_swaps').select(swapSelect).order('created_at', { ascending: false })
          .order('id').range(0, historyLimit),
        supabase.from('hosting_swaps').select('assignment_id').eq('status', 'pending')
      ]);
      if (roster.error) throw roster.error;
      if (history.error) throw history.error;
      if (requests.error) throw requests.error;
      if (disposed || version !== loadVersion) return;
      assignments = ((roster.data || []) as unknown as Assignment[])
        .sort((a, b) => a.event.start_datetime.localeCompare(b.event.start_datetime));
      swaps = (history.data || []).slice(0, historyLimit) as unknown as Swap[];
      hasMore = (history.data?.length || 0) > historyLimit;
      pendingIds = (requests.data || []).map(value => value.assignment_id);
      error = '';
    } catch (err) {
      if (!disposed && version === loadVersion) error = hostingError(err, 'تعذّر تحميل جدول المعازيب.');
    } finally {
      if (!disposed && version === loadVersion) { loading = false; refreshing = false; }
    }
  }

  onMount(() => {
    let timer: ReturnType<typeof setTimeout>;
    const refresh = () => { clearTimeout(timer); timer = setTimeout(() => void load(), 150); };
    const channel = supabase.channel('hosting')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'hosting_assignments' }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'hosting_confirmations' }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'hosting_swaps' }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'events' }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'users' }, refresh)
      .subscribe(status => {
        if (disposed) return;
        if (status === 'SUBSCRIBED') { liveError = ''; refresh(); }
        else if (['CHANNEL_ERROR', 'TIMED_OUT', 'CLOSED'].includes(status)) liveError = 'انقطع التحديث المباشر. يمكنك تحديث القائمة يدويًا.';
      });
    void load();
    window.addEventListener('focus', refresh);
    window.addEventListener('online', refresh);
    const interval = setInterval(refresh, 60_000);
    return () => {
      disposed = true; ++loadVersion; clearTimeout(timer); clearInterval(interval);
      window.removeEventListener('focus', refresh); window.removeEventListener('online', refresh);
      void supabase.removeChannel(channel);
    };
  });

  async function act(key: string, action: () => Promise<void>, message: string) {
    if (busy) return;
    busy = key; error = ''; success = '';
    try { await action(); success = message; await load(); }
    catch (err) { error = hostingError(err); }
    finally { busy = ''; }
  }
  function confirmHosting(assignment: Assignment) {
    void act(`confirm:${assignment.id}`, async () => {
      const { data, error: err } = await supabase.rpc('confirm_hosting', { p_assignment_id: assignment.id });
      if (err) throw err;
      if (data?.ok === false) throw new Error('تعذّر تأكيد المشاركة. حدّث القائمة.');
    }, 'تم تأكيد مشاركتك.');
  }
  function deleteAssignment() {
    const assignment = deleting;
    if (!assignment || !canManage) return;
    void act(`delete:${assignment.id}`, async () => {
      const { data: requests, error: readError } = await supabase.from('hosting_swaps')
        .select('id').eq('assignment_id', assignment.id).eq('status', 'pending').limit(1);
      if (readError) throw readError;
      if (requests?.length) throw new Error('احسم طلب التبديل المعلّق قبل حذف التكليف.');
      const { error: err } = await supabase.from('hosting_assignments')
        .update({ deleted_at: new Date().toISOString(), status: 'cancelled' })
        .eq('id', assignment.id).eq('updated_at', assignment.updated_at).is('deleted_at', null).select('id').single();
      if (err) throw err;
      deleting = null;
    }, 'تم حذف التكليف.');
  }
  function resolveSwap(swap: Swap, approve: boolean) {
    if (!canManage) return;
    void act(`resolve:${swap.id}`, async () => {
      if (approve) {
        const { data, error: err } = await supabase.from('hosting_assignments')
          .select('host_a_user_id,host_b_user_id,event:events!inner(start_datetime,status)')
          .eq('id', swap.assignment_id).is('deleted_at', null).single();
        if (err) throw err;
        const assignment = data as unknown as { host_a_user_id: string; host_b_user_id: string; event: { start_datetime: string; status: string } };
        const hosts = [assignment.host_a_user_id, assignment.host_b_user_id];
        if (!hosts.includes(swap.requested_by_user_id) || hosts.includes(swap.requested_with_user_id)) throw new Error('تغيّر المعازيب؛ ارفض الطلب القديم ثم اطلب تبديلًا جديدًا.');
        if (assignment.event.status !== 'scheduled' || Date.parse(assignment.event.start_datetime) <= Date.now()) throw new Error('لم تعد الطلعة متاحة للتبديل. يمكنك رفض الطلب.');
      }
      const { data, error: err } = await supabase.rpc('resolve_swap', { p_swap_id: swap.id, p_approve: approve, p_note: null });
      if (err) throw err;
      if (data?.ok === false) throw new Error('تعذّر حسم الطلب. حدّث القائمة.');
    }, approve ? 'تم قبول التبديل وتحديث المعازيب.' : 'تم رفض طلب التبديل.');
  }
  function saved() { form = null; success = 'تم الحفظ بنجاح.'; void load(); }
</script>

<PageHead icon="🫖" title="جدول المعازيب" />
<div class="chips">
  <span class="chip">طلعات الأربعاء القادمة</span>
  <button class="btn-sm" onclick={() => load()} disabled={refreshing || !!busy}>{refreshing ? 'جارٍ التحديث…' : 'تحديث'}</button>
  {#if canManage}<button class="add" disabled={!!busy} onclick={() => form = { mode: 'assignment', assignment: null }}>+ ربط معازيب بطلعة</button>{/if}
</div>
{#if error}<div class="alert err" role="alert">{error}</div>{/if}
{#if liveError}<div class="alert err" role="alert">{liveError}</div>{/if}
{#if success}<div class="alert success" role="status">{success}</div>{/if}
{#if loading}
  <div class="skel" role="status" aria-label="جارٍ تحميل جدول المعازيب"></div><div class="skel"></div><div class="skel"></div>
{:else if !rows.length && !error}
  <div class="empty"><div class="ic" aria-hidden="true">🫖</div><p>لا توجد تكليفات استضافة لطلعات قادمة</p></div>
{:else}
  {#each rows as assignment (assignment.id)}
    {@const isHost = userId === assignment.host_a_user_id || userId === assignment.host_b_user_id}
    {@const confirmed = userId === assignment.host_a_user_id ? assignment.host_a_confirmed : assignment.host_b_confirmed}
    <article class="card">
      <div class="day-h">{fmtDate(assignment.event.start_datetime)}</div>
      <h2 class="tt">{assignment.event.title}</h2>
      <div class="hosts">
        <div class="host"><span>{assignment.host_a_name}</span><span class="badge" class:ok={assignment.host_a_confirmed}>{assignment.host_a_confirmed ? 'مؤكّد' : 'بانتظار التأكيد'}</span></div>
        <div class="host"><span>{assignment.host_b_name}</span><span class="badge" class:ok={assignment.host_b_confirmed}>{assignment.host_b_confirmed ? 'مؤكّد' : 'بانتظار التأكيد'}</span></div>
      </div>
      <div class="mt"><span>العدد المتوقع: <b>{assignment.expected_count}</b></span></div>
      <div class="items" aria-label="عناصر الضيافة">
        {#each assignment.items as item, index (index)}<span class="chip">{item}</span>{:else}<span class="notes">لم تُحدّد عناصر الضيافة بعد</span>{/each}
      </div>
      {#if pending.has(assignment.id)}<p class="notes">يوجد طلب تبديل قيد المراجعة لهذا التكليف.</p>{/if}
      {#if isHost || canManage}
        <div class="actions">
          {#if isHost && !confirmed}<button class="btn" disabled={!!busy} onclick={() => confirmHosting(assignment)}>{busy === `confirm:${assignment.id}` ? 'جارٍ التأكيد…' : 'أكّد مشاركتك'}</button>{/if}
          {#if isHost && !pending.has(assignment.id)}<button class="btn-sm" disabled={!!busy || !!error} onclick={() => form = { mode: 'swap', assignment }}>طلب تبديل</button>{/if}
          {#if canManage}
            <button class="btn-sm" disabled={!!busy} onclick={() => form = { mode: 'assignment', assignment }}>تعديل</button>
            <button class="btn-sm danger" disabled={!!busy} onclick={() => { error = ''; deleting = assignment; }}>حذف</button>
          {/if}
        </div>
      {/if}
    </article>
  {/each}
{/if}

<h2 class="section-title">سجل طلبات التبديل</h2>
{#if loading}
  <div class="skel"></div>
{:else if !swaps.length && !error}
  <div class="empty"><p>لا توجد طلبات تبديل متاحة لعرضها</p></div>
{:else}
  {#each swaps as swap (swap.id)}
    <article class="card">
      <div class="mt"><span class="badge" class:ok={swap.status === 'approved'} class:bad={swap.status === 'rejected'}>{statusLabels[swap.status] || swap.status}</span><span>طُلب في {fmtDate(swap.created_at)}</span></div>
      <h3 class="tt swap-title">{swap.requester?.full_name || 'عضو غير متاح'} <span class="notes">مع</span> {swap.replacement?.full_name || 'عضو غير متاح'}</h3>
      {#if swap.assignment?.event}<p class="notes">{swap.assignment.event.title} · {fmtDate(swap.assignment.event.start_datetime)}</p>{:else}<p class="notes">التكليف غير متاح</p>{/if}
      {#if swap.assignment?.deleted_at}<p class="notes">حُذف التكليف المرتبط بهذا الطلب</p>{/if}
      <p class="reason">{swap.reason || 'لم يُذكر سبب'}</p>
      {#if swap.resolution_note}<p class="notes">ملاحظة القرار: {swap.resolution_note}</p>{/if}
      {#if canManage && swap.status === 'pending'}
        <div class="actions">
          <button class="btn" disabled={!!busy || !swap.assignment || !!swap.assignment.deleted_at} onclick={() => resolveSwap(swap, true)}>قبول التبديل</button>
          <button class="btn-sm danger" disabled={!!busy} onclick={() => resolveSwap(swap, false)}>رفض الطلب</button>
          {#if busy === `resolve:${swap.id}`}<span class="notes" role="status">جارٍ حسم الطلب…</span>{/if}
        </div>
      {/if}
    </article>
  {/each}
  {#if hasMore}<button class="btn-sm more" disabled={refreshing} onclick={() => { historyLimit += 20; void load(); }}>عرض المزيد</button>{/if}
{/if}

{#if form}<HostingForm mode={form.mode} assignment={form.assignment} onclose={() => form = null} onsaved={saved} />{/if}
{#if deleting}
  <HostingModal title="حذف تكليف المعازيب" busy={!!busy} onclose={() => deleting = null}>
    <div class="mb">
      <p>حذف تكليف {deleting.event.title} بتاريخ {fmtDate(deleting.event.start_datetime)}؟</p>
      {#if error}<div class="alert err" role="alert">{error}</div>{/if}
      <div class="mf"><button class="btn-sm" disabled={!!busy} onclick={() => deleting = null}>إلغاء</button><button class="btn-sm danger" disabled={!!busy} onclick={deleteAssignment}>{busy ? 'جارٍ الحذف…' : 'حذف التكليف'}</button></div>
    </div>
  </HostingModal>
{/if}

<style>
  .chips, .items { display: flex; gap: 7px; flex-wrap: wrap; align-items: center; margin-bottom: 14px; }
  .chip { padding: 7px 14px; border-radius: 999px; font-size: 11.5px; font-weight: 500; background: var(--card); color: var(--ink2); border: 1px solid var(--line); overflow-wrap: anywhere; max-width: 100%; }
  .add { background: var(--gold); color: var(--on-gold); border: none; border-radius: 10px; padding: 8px 14px; font-size: 12px; font-weight: 700; margin-inline-start: auto; cursor: pointer; min-height: var(--touch); font-family: inherit; }
  .card { background: var(--card); border-radius: 13px; padding: 13px 15px; box-shadow: var(--shadow); border: 1px solid var(--line); border-inline-start: 4px solid var(--brand); margin-bottom: 9px; overflow-wrap: anywhere; }
  .day-h { font-size: 11.5px; font-weight: 700; color: var(--brand-ink); margin-bottom: 9px; }
  .tt { font-weight: 600; font-size: 14px; margin: 0 0 10px; }
  .swap-title { margin-top: 12px; }
  .hosts { display: grid; gap: 8px; margin-bottom: 12px; }
  .host { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; background: var(--brand-softer); padding: 10px; border-radius: 10px; font-size: 13px; }
  .host > span:first-child { flex: 1; min-width: 0; }
  .mt { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; font-size: 12px; color: var(--ink2); }
  .items { margin: 12px 0 0; }
  .notes { font-size: 12px; color: var(--ink2); margin: 8px 0; }
  .reason { font-size: 13px; white-space: pre-wrap; }
  .badge { display: inline-block; font-size: 10px; font-weight: 600; padding: 4px 9px; border-radius: 999px; background: var(--warn-soft); color: var(--warn); }
  .badge.ok { background: var(--ok-soft); color: var(--ok); }
  .badge.bad { background: var(--bad-soft); color: var(--bad); }
  .actions { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 14px; }
  .btn-sm, .btn { min-width: var(--touch); min-height: var(--touch); padding: 10px 14px; background: var(--card); color: var(--ink); border: 1px solid var(--line); border-radius: 9px; cursor: pointer; font-size: 13px; font-family: inherit; font-weight: 600; }
  .btn { background: var(--brand); color: var(--on-brand); border-color: var(--brand); }
  .btn-sm:hover { background: var(--gold-soft); border-color: var(--gold); }
  .btn-sm.danger { color: var(--bad); }
  .btn-sm.danger:hover { background: var(--bad-soft); border-color: var(--bad); }
  button:disabled { opacity: .6; cursor: not-allowed; }
  button:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; }
  .section-title { font-size: 16px; color: var(--brand-ink); margin: 26px 0 14px; }
  .empty { text-align: center; padding: 40px 16px; color: var(--ink3); background: var(--card); border-radius: 18px; border: 1px solid var(--line); }
  .empty .ic { font-size: 42px; opacity: .4; margin-bottom: 10px; }
  .alert { padding: 12px 14px; border-radius: 12px; font-size: 12.5px; margin-bottom: 12px; font-weight: 500; overflow-wrap: anywhere; }
  .alert.err { background: var(--bad-soft); color: var(--bad); }
  .alert.success { background: var(--ok-soft); color: var(--ok); }
  .skel { height: 100px; background: var(--muted-bg); border-radius: 13px; margin-bottom: 9px; animation: pulse 1.4s ease-in-out infinite; }
  .mb { padding: 20px; overflow-y: auto; }
  .mf { display: flex; flex-wrap: wrap; gap: 8px; justify-content: flex-end; border-top: 1px solid var(--line); padding-top: 10px; }
  .more { display: block; margin: 14px auto; }
  @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: .5; } }
  @media (min-width: 600px) { .hosts { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
</style>
