<script lang="ts">
  import { onMount, untrack } from 'svelte';
  import { supabase } from '../supabase';
  import { roles, session } from '../stores';
  import { fmtDate } from '../utils';
  import HostingModal from '../components/HostingModal.svelte';
  import { canManageHosting, hostingError, loadMembers, weekStart, type Assignment, type Member, type WeeklyEvent } from './hosting';

  let { mode, assignment = null, onclose, onsaved }: {
    mode: 'assignment' | 'swap'; assignment?: Assignment | null;
    onclose: () => void; onsaved: () => void;
  } = $props();
  const initial = untrack(() => assignment);
  const isEdit = $derived(mode === 'assignment' && !!assignment);
  const title = $derived(mode === 'swap' ? 'طلب تبديل الاستضافة' : isEdit ? 'تعديل تكليف المعازيب' : 'ربط معازيب بطلعة');
  let eventId = $state(initial?.event_id || '');
  let hostA = $state(initial?.host_a_user_id || '');
  let hostB = $state(initial?.host_b_user_id || '');
  let items = $state(initial?.items.join('\n') || '');
  let expectedCount = $state<number | undefined>(initial?.expected_count ?? 0);
  let replacement = $state('');
  let reason = $state('');
  let members = $state<Member[]>([]);
  let events = $state<WeeklyEvent[]>([]);
  let loading = $state(true);
  let saving = $state(false);
  let error = $state('');
  let disposed = false;
  const replacements = $derived(members.filter(member =>
    member.id !== assignment?.host_a_user_id && member.id !== assignment?.host_b_user_id));

  async function load() {
    loading = true; error = '';
    try {
      const [loadedMembers, eventResult, linkedResult] = await Promise.all([
        loadMembers(),
        mode === 'assignment' ? supabase.from('events').select('id,title,start_datetime,status')
          .eq('type', 'weekly').is('deleted_at', null).eq('status', 'scheduled')
          .gte('start_datetime', new Date().toISOString()).order('start_datetime') : null,
        mode === 'assignment' ? supabase.from('hosting_assignments').select('id,event_id') : null
      ]);
      if (eventResult?.error) throw eventResult.error;
      if (linkedResult?.error) throw linkedResult.error;
      if (disposed) return;
      members = loadedMembers;
      for (const member of [assignment?.host_a, assignment?.host_b]) {
        if (member && !members.some(value => value.id === member.id)) members.push(member);
      }
      const linked = new Set((linkedResult?.data || []).filter(row => row.id !== assignment?.id).map(row => row.event_id));
      events = (eventResult?.data || []).filter(event => !linked.has(event.id));
    } catch (err) { if (!disposed) error = hostingError(err); }
    finally { if (!disposed) loading = false; }
  }
  onMount(() => { void load(); return () => { disposed = true; }; });

  async function save(event: SubmitEvent) {
    event.preventDefault();
    if (saving || loading) return;
    saving = true; error = '';
    try {
      const userId = $session?.user.id;
      if (!userId) throw new Error('يجب تسجيل الدخول.');
      if (mode === 'swap') {
        if (!assignment || ![assignment.host_a_user_id, assignment.host_b_user_id].includes(userId)) throw new Error('لست من المعازيب لهذا التكليف.');
        if (!replacement || !replacements.some(member => member.id === replacement)) throw new Error('اختر عضوًا آخر غير المعازيب الحاليين.');
        if (!reason.trim()) throw new Error('أدخل سبب طلب التبديل.');
        const { data: current, error: readError } = await supabase.from('hosting_assignments')
          .select('host_a_user_id,host_b_user_id,updated_at,event:events!inner(id)')
          .eq('id', assignment.id).is('deleted_at', null).eq('event.type', 'weekly')
          .eq('event.status', 'scheduled').is('event.deleted_at', null)
          .gte('event.start_datetime', new Date().toISOString()).single();
        if (readError) throw readError;
        if (current.updated_at !== assignment.updated_at || ![current.host_a_user_id, current.host_b_user_id].includes(userId)) throw new Error('تغيّر التكليف. أغلق النافذة وحدّث القائمة.');
        const { error: err } = await supabase.from('hosting_swaps').insert({
          assignment_id: assignment.id, requested_by_user_id: userId,
          requested_with_user_id: replacement, reason: reason.trim()
        });
        if (err) throw err;
      } else {
        if (!canManageHosting($roles)) throw new Error('لا تملك صلاحية إدارة المعازيب.');
        const selected = events.find(value => value.id === eventId);
        if (!selected || Date.parse(selected.start_datetime) <= Date.now()) throw new Error('اختر طلعة أسبوعية قادمة.');
        if (!hostA || !hostB || hostA === hostB) throw new Error('اختر معزّبين مختلفين.');
        if (expectedCount === undefined || !Number.isInteger(expectedCount) || expectedCount < 0 || expectedCount > 500) throw new Error('العدد المتوقع يجب أن يكون عددًا صحيحًا بين ٠ و٥٠٠.');
        const { data: currentEvent, error: eventError } = await supabase.from('events')
          .select('id,start_datetime').eq('id', eventId).eq('type', 'weekly')
          .eq('status', 'scheduled').is('deleted_at', null)
          .gte('start_datetime', new Date().toISOString()).single();
        if (eventError) throw eventError;
        const hostsChanged = !!assignment && (hostA !== assignment.host_a_user_id || hostB !== assignment.host_b_user_id);
        if (assignment && hostsChanged) {
          const { data, error: err } = await supabase.from('hosting_swaps').select('id')
            .eq('assignment_id', assignment.id).eq('status', 'pending').limit(1);
          if (err) throw err;
          if (data?.length) throw new Error('احسم طلب التبديل المعلّق قبل تغيير المعازيب.');
        }
        const payload = {
          event_id: eventId, week_start_date: weekStart(currentEvent.start_datetime),
          host_a_user_id: hostA, host_b_user_id: hostB,
          items: [...new Set(items.split(/[\n,،]+/).map(item => item.trim()).filter(Boolean))],
          expected_count: expectedCount,
          ...(hostsChanged ? { status: 'assigned' } : {})
        };
        const result = assignment
          ? await supabase.from('hosting_assignments').update(payload).eq('id', assignment.id)
            .eq('updated_at', assignment.updated_at).is('deleted_at', null).select('id').single()
          : await supabase.from('hosting_assignments').insert({ ...payload, created_by: userId }).select('id').single();
        if (result.error) throw result.error;
      }
      onsaved();
    } catch (err) { error = hostingError(err); }
    finally { saving = false; }
  }
</script>

<HostingModal {title} busy={saving} {onclose}>
  <form class="mb" onsubmit={save} aria-busy={loading || saving}>
    {#if error}<div class="alert err" role="alert">{error}</div>{/if}
    {#if loading}
      <div class="skel" role="status" aria-label="جارٍ تحميل الخيارات"></div><div class="skel"></div>
    {:else if mode === 'swap'}
      <p class="notes">{assignment?.event.title} · {fmtDate(assignment?.event.start_datetime)}</p>
      <div class="field">
        <label for="swap-member">العضو البديل *</label>
        <select id="swap-member" bind:value={replacement} required disabled={saving}>
          <option value="">اختر عضوًا</option>
          {#each replacements as member (member.id)}<option value={member.id}>{member.full_name}</option>{/each}
        </select>
      </div>
      {#if !replacements.length}<div class="empty">لا يوجد أعضاء متاحون للتبديل.</div>{/if}
      <div class="field">
        <label for="swap-reason">سبب التبديل *</label>
        <textarea id="swap-reason" bind:value={reason} required maxlength="500" rows="3" disabled={saving} placeholder="اكتب سبب طلبك…"></textarea>
      </div>
    {:else}
      <div class="field">
        <label for="hosting-event">الطلعة الأسبوعية *</label>
        <select id="hosting-event" bind:value={eventId} required disabled={saving || isEdit}>
          <option value="">اختر طلعة</option>
          {#each events as event (event.id)}<option value={event.id}>{fmtDate(event.start_datetime)} · {event.title}</option>{/each}
        </select>
        <p class="notes">تظهر الطلعات القادمة التي لم تُربط بتكليف سابق.</p>
      </div>
      {#if !events.length}<div class="empty">لا توجد طلعات أسبوعية متاحة للربط.</div>{/if}
      <div class="field">
        <label for="hosting-a">المعزّب الأول *</label>
        <select id="hosting-a" bind:value={hostA} required disabled={saving}>
          <option value="">اختر المعزّب الأول</option>
          {#each members as member (member.id)}<option value={member.id} disabled={member.id === hostB}>{member.full_name}</option>{/each}
        </select>
      </div>
      <div class="field">
        <label for="hosting-b">المعزّب الثاني *</label>
        <select id="hosting-b" bind:value={hostB} required disabled={saving}>
          <option value="">اختر المعزّب الثاني</option>
          {#each members as member (member.id)}<option value={member.id} disabled={member.id === hostA}>{member.full_name}</option>{/each}
        </select>
      </div>
      <div class="field">
        <label for="hosting-items">عناصر الضيافة</label>
        <textarea id="hosting-items" bind:value={items} rows="3" disabled={saving} placeholder="قهوة&#10;تمر&#10;عشاء"></textarea>
        <p class="notes">كل عنصر في سطر، أو افصل العناصر بفاصلة.</p>
      </div>
      <div class="field">
        <label for="hosting-count">العدد المتوقع *</label>
        <input id="hosting-count" type="number" bind:value={expectedCount} min="0" max="500" step="1" required disabled={saving} inputmode="numeric" />
      </div>
    {/if}
    <div class="mf">
      <button type="button" class="btn ghost" disabled={saving} onclick={onclose}>إلغاء</button>
      {#if error}<button type="button" class="btn ghost" disabled={loading || saving} onclick={load}>تحديث الخيارات</button>{/if}
      <button type="submit" class="btn" disabled={saving || loading || (mode === 'swap' ? !replacements.length : !events.length)}>
        {saving ? 'جارٍ الحفظ…' : mode === 'swap' ? 'إرسال الطلب' : isEdit ? 'حفظ' : 'إضافة'}
      </button>
    </div>
  </form>
</HostingModal>

<style>
  .mb { padding: 20px; overflow-y: auto; min-height: 0; flex: 1; }
  .field { margin-bottom: 14px; }
  .field label { display: block; font-size: 12px; font-weight: 600; margin-bottom: 6px; color: var(--brand-ink); }
  .field input, .field select, .field textarea { width: 100%; min-height: var(--touch); padding: 12px 13px; border: 1.5px solid var(--line); border-radius: 12px; font-family: inherit; font-size: 16px; background: var(--card); color: var(--ink); }
  .field textarea { resize: vertical; }
  .field input:focus, .field select:focus, .field textarea:focus { outline: none; border-color: var(--brand); box-shadow: var(--shadow-focus); }
  .notes { font-size: 12px; color: var(--ink2); margin: 6px 0 12px; overflow-wrap: anywhere; }
  .alert { padding: 10px 14px; border-radius: 10px; font-size: 12.5px; margin-bottom: 12px; font-weight: 500; overflow-wrap: anywhere; }
  .alert.err { background: var(--bad-soft); color: var(--bad); }
  .empty { text-align: center; padding: 20px 12px; color: var(--ink3); background: var(--card); border-radius: 18px; border: 1px solid var(--line); margin-bottom: 14px; }
  .mf { padding-top: 10px; padding-bottom: env(safe-area-inset-bottom); border-top: 1px solid var(--line); display: flex; flex-wrap: wrap; gap: 8px; justify-content: flex-end; position: sticky; bottom: -20px; background: var(--card); }
  .btn { min-height: var(--touch); padding: 11px 16px; background: var(--brand); color: var(--on-brand); border: 1.5px solid var(--brand); border-radius: 11px; font-family: inherit; font-size: 13.5px; font-weight: 600; cursor: pointer; }
  .btn.ghost { background: var(--card); color: var(--brand-ink); border-color: var(--line); }
  button:disabled, input:disabled, select:disabled, textarea:disabled { opacity: .6; cursor: not-allowed; }
  button:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; }
  .skel { height: 70px; background: var(--muted-bg); border-radius: 13px; margin-bottom: 9px; animation: pulse 1.4s ease-in-out infinite; }
  @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: .5; } }
</style>
