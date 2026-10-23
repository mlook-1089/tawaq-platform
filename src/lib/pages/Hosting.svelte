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
  const statusPillCls: Record<Swap['status'], string> = {
    pending: 'warn', approved: 'ok', rejected: 'bad', cancelled: ''
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

<div class="toolbar">
  <span class="u-pill brand">طلعات الأربعاء القادمة</span>
  <button class="u-btn u-btn-ghost sm" onclick={() => load()} disabled={refreshing || !!busy}>
    {refreshing ? 'جارٍ التحديث…' : 'تحديث'}
  </button>
  {#if canManage}
    <button class="u-btn u-btn-gold sm add-btn" disabled={!!busy} onclick={() => form = { mode: 'assignment', assignment: null }}>
      + ربط معازيب بطلعة
    </button>
  {/if}
</div>

{#if error}<div class="u-alert err" role="alert">{error}</div>{/if}
{#if liveError}<div class="u-alert warn" role="alert">{liveError}</div>{/if}
{#if success}<div class="u-alert ok" role="status">{success}</div>{/if}

{#if loading}
  <div class="u-stack">
    <div class="u-skel u-skel-card"></div>
    <div class="u-skel u-skel-card"></div>
    <div class="u-skel u-skel-card"></div>
  </div>
{:else if !rows.length && !error}
  <div class="u-empty">
    <div class="ic" aria-hidden="true">🫖</div>
    <p>لا توجد تكليفات استضافة لطلعات قادمة</p>
  </div>
{:else}
  <div class="u-stack">
    {#each rows as assignment (assignment.id)}
      {@const isHost = userId === assignment.host_a_user_id || userId === assignment.host_b_user_id}
      {@const confirmed = userId === assignment.host_a_user_id ? assignment.host_a_confirmed : assignment.host_b_confirmed}
      <article class="u-card host-card">
        <div class="u-day-head">{fmtDate(assignment.event.start_datetime)}</div>
        <h2 class="host-title">{assignment.event.title}</h2>

        <div class="hosts-grid">
          <div class="host-box">
            <span class="host-name">{assignment.host_a_name}</span>
            <span class="u-pill {assignment.host_a_confirmed ? 'ok' : 'warn'}">
              {assignment.host_a_confirmed ? '✓ مؤكّد' : 'بانتظار التأكيد'}
            </span>
          </div>
          <div class="host-box">
            <span class="host-name">{assignment.host_b_name}</span>
            <span class="u-pill {assignment.host_b_confirmed ? 'ok' : 'warn'}">
              {assignment.host_b_confirmed ? '✓ مؤكّد' : 'بانتظار التأكيد'}
            </span>
          </div>
        </div>

        <div class="count-line">
          <span class="u-muted">العدد المتوقع:</span> <b>{assignment.expected_count}</b>
        </div>

        <div class="items-row" aria-label="عناصر الضيافة">
          {#each assignment.items as item, index (index)}
            <span class="u-chip">{item}</span>
          {:else}
            <span class="u-muted">لم تُحدّد عناصر الضيافة بعد</span>
          {/each}
        </div>

        {#if pending.has(assignment.id)}
          <div class="u-alert warn">يوجد طلب تبديل قيد المراجعة لهذا التكليف.</div>
        {/if}

        {#if isHost || canManage}
          <div class="actions">
            {#if isHost && !confirmed}
              <button class="u-btn u-btn-primary" disabled={!!busy} onclick={() => confirmHosting(assignment)}>
                {busy === `confirm:${assignment.id}` ? 'جارٍ التأكيد…' : 'أكّد مشاركتك'}
              </button>
            {/if}
            {#if isHost && !pending.has(assignment.id)}
              <button class="u-btn u-btn-ghost sm" disabled={!!busy || !!error} onclick={() => form = { mode: 'swap', assignment }}>
                طلب تبديل
              </button>
            {/if}
            {#if canManage}
              <button class="u-btn u-btn-ghost sm" disabled={!!busy} onclick={() => form = { mode: 'assignment', assignment }}>
                تعديل
              </button>
              <button class="u-btn u-btn-ghost sm danger" disabled={!!busy} onclick={() => { error = ''; deleting = assignment; }}>
                حذف
              </button>
            {/if}
          </div>
        {/if}
      </article>
    {/each}
  </div>
{/if}

<h2 class="section-title">سجل طلبات التبديل</h2>

{#if loading}
  <div class="u-skel u-skel-card"></div>
{:else if !swaps.length && !error}
  <div class="u-empty"><p>لا توجد طلبات تبديل متاحة لعرضها</p></div>
{:else}
  <div class="u-stack">
    {#each swaps as swap (swap.id)}
      <article class="u-card swap-card">
        <div class="swap-meta">
          <span class="u-pill {statusPillCls[swap.status]}">{statusLabels[swap.status] || swap.status}</span>
          <span class="u-muted">طُلب في {fmtDate(swap.created_at)}</span>
        </div>
        <h3 class="swap-title">
          {swap.requester?.full_name || 'عضو غير متاح'}
          <span class="u-muted">مع</span>
          {swap.replacement?.full_name || 'عضو غير متاح'}
        </h3>
        {#if swap.assignment?.event}
          <p class="u-muted">{swap.assignment.event.title} · {fmtDate(swap.assignment.event.start_datetime)}</p>
        {:else}
          <p class="u-muted">التكليف غير متاح</p>
        {/if}
        {#if swap.assignment?.deleted_at}
          <p class="u-muted">حُذف التكليف المرتبط بهذا الطلب</p>
        {/if}
        <p class="swap-reason">{swap.reason || 'لم يُذكر سبب'}</p>
        {#if swap.resolution_note}
          <p class="u-muted">ملاحظة القرار: {swap.resolution_note}</p>
        {/if}
        {#if canManage && swap.status === 'pending'}
          <div class="actions">
            <button class="u-btn u-btn-primary sm" disabled={!!busy || !swap.assignment || !!swap.assignment.deleted_at}
              onclick={() => resolveSwap(swap, true)}>قبول التبديل</button>
            <button class="u-btn u-btn-ghost sm danger" disabled={!!busy}
              onclick={() => resolveSwap(swap, false)}>رفض الطلب</button>
            {#if busy === `resolve:${swap.id}`}<span class="u-muted" role="status">جارٍ حسم الطلب…</span>{/if}
          </div>
        {/if}
      </article>
    {/each}
  </div>
  {#if hasMore}
    <button class="u-btn u-btn-ghost sm more-btn" disabled={refreshing} onclick={() => { historyLimit += 20; void load(); }}>
      عرض المزيد
    </button>
  {/if}
{/if}

{#if form}
  <HostingForm mode={form.mode} assignment={form.assignment} onclose={() => form = null} onsaved={saved} />
{/if}

{#if deleting}
  <HostingModal title="حذف تكليف المعازيب" busy={!!busy} onclose={() => deleting = null}>
    <div class="confirm-body">
      <p>حذف تكليف {deleting.event.title} بتاريخ {fmtDate(deleting.event.start_datetime)}؟</p>
      {#if error}<div class="u-alert err" role="alert">{error}</div>{/if}
      <div class="u-modal-footer no-border">
        <button class="u-btn u-btn-ghost sm" disabled={!!busy} onclick={() => deleting = null}>إلغاء</button>
        <button class="u-btn u-btn-danger sm" disabled={!!busy} onclick={deleteAssignment}>
          {busy ? 'جارٍ الحذف…' : 'حذف التكليف'}
        </button>
      </div>
    </div>
  </HostingModal>
{/if}

<style>
  .toolbar {
    display: flex;
    gap: var(--sp-1);
    align-items: center;
    flex-wrap: wrap;
    margin-bottom: var(--sp-2);
  }
  .add-btn { margin-inline-start: auto; }

  .host-card {
    border-inline-start: 4px solid var(--brand);
    position: relative;
  }
  .host-title {
    font: var(--fw-bold) var(--fs-md) var(--font-sans);
    color: var(--ink);
    margin: 0 0 var(--sp-2);
  }

  .hosts-grid {
    display: grid;
    gap: var(--sp-1);
    margin-bottom: var(--sp-2);
  }
  @media (min-width: 600px) {
    .hosts-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  }
  .host-box {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: var(--sp-1);
    background: var(--brand-softer);
    padding: var(--sp-1) var(--sp-2);
    border-radius: var(--r-sm);
    font-size: var(--fs-sm);
    flex-wrap: wrap;
  }
  .host-name {
    flex: 1;
    min-width: 0;
    font: var(--fw-semi) var(--fs-sm) var(--font-sans);
    color: var(--ink);
  }

  .count-line {
    font-size: var(--fs-xs);
    margin-bottom: var(--sp-1);
  }
  .count-line b {
    font-weight: var(--fw-bold);
    color: var(--brand);
  }

  .items-row {
    display: flex;
    flex-wrap: wrap;
    gap: var(--sp-05);
    margin-bottom: var(--sp-1);
  }
  .items-row .u-chip {
    min-height: 28px;
    padding: 4px 10px;
    font-size: var(--fs-tiny);
  }

  .actions {
    display: flex;
    flex-wrap: wrap;
    gap: var(--sp-1);
    margin-top: var(--sp-2);
  }
  .danger { color: var(--bad); }
  .danger:hover:not(:disabled) { background: var(--bad-soft); border-color: var(--bad-soft); }

  .section-title {
    font: var(--fw-bold) var(--fs-md) var(--font-sans);
    color: var(--brand-ink);
    margin: var(--sp-4) 0 var(--sp-2);
  }

  .swap-card { border-inline-start: 3px solid var(--gold); }
  .swap-meta {
    display: flex;
    gap: var(--sp-1);
    align-items: center;
    flex-wrap: wrap;
    margin-bottom: var(--sp-1);
    font-size: var(--fs-xs);
  }
  .swap-title {
    font: var(--fw-semi) var(--fs-base) var(--font-sans);
    margin: 0 0 var(--sp-05);
    color: var(--ink);
  }
  .swap-reason {
    font-size: var(--fs-sm);
    color: var(--ink);
    white-space: pre-wrap;
    margin: var(--sp-1) 0;
    padding: var(--sp-1) var(--sp-2);
    background: var(--bg);
    border-radius: var(--r-sm);
  }
  .more-btn { display: block; margin: var(--sp-2) auto; }

  .confirm-body { padding: var(--sp-3); }
  .confirm-body p { margin: 0 0 var(--sp-2); color: var(--ink); }
  .no-border { border-top: none; padding: var(--sp-1) 0 0; }
</style>
