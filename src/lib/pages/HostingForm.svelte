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
  <form id="hosting-form" class="u-modal-body" onsubmit={save} aria-busy={loading || saving}>
    {#if error}<div class="u-alert err" role="alert">{error}</div>{/if}

    {#if loading}
      <div class="u-skel u-skel-card" role="status" aria-label="جارٍ تحميل الخيارات"></div>
      <div class="u-skel u-skel-card"></div>
    {:else if mode === 'swap'}
      <p class="u-muted ctx">{assignment?.event.title} · {fmtDate(assignment?.event.start_datetime)}</p>

      <div class="u-field">
        <label for="swap-member" class="u-field-label">العضو البديل *</label>
        <select id="swap-member" class="u-input u-select" bind:value={replacement} required disabled={saving}>
          <option value="">اختر عضوًا</option>
          {#each replacements as member (member.id)}<option value={member.id}>{member.full_name}</option>{/each}
        </select>
      </div>
      {#if !replacements.length}<div class="u-alert warn">لا يوجد أعضاء متاحون للتبديل.</div>{/if}

      <div class="u-field">
        <label for="swap-reason" class="u-field-label">سبب التبديل *</label>
        <textarea id="swap-reason" class="u-input u-textarea" bind:value={reason} required maxlength="500" rows="3" disabled={saving} placeholder="اكتب سبب طلبك…"></textarea>
      </div>
    {:else}
      <div class="u-field">
        <label for="hosting-event" class="u-field-label">الطلعة الأسبوعية *</label>
        <select id="hosting-event" class="u-input u-select" bind:value={eventId} required disabled={saving || isEdit}>
          <option value="">اختر طلعة</option>
          {#each events as event (event.id)}<option value={event.id}>{fmtDate(event.start_datetime)} · {event.title}</option>{/each}
        </select>
        <p class="u-field-hint">تظهر الطلعات القادمة التي لم تُربط بتكليف سابق.</p>
      </div>
      {#if !events.length}<div class="u-alert warn">لا توجد طلعات أسبوعية متاحة للربط.</div>{/if}

      <div class="u-field">
        <label for="hosting-a" class="u-field-label">المعزّب الأول *</label>
        <select id="hosting-a" class="u-input u-select" bind:value={hostA} required disabled={saving}>
          <option value="">اختر المعزّب الأول</option>
          {#each members as member (member.id)}<option value={member.id} disabled={member.id === hostB}>{member.full_name}</option>{/each}
        </select>
      </div>

      <div class="u-field">
        <label for="hosting-b" class="u-field-label">المعزّب الثاني *</label>
        <select id="hosting-b" class="u-input u-select" bind:value={hostB} required disabled={saving}>
          <option value="">اختر المعزّب الثاني</option>
          {#each members as member (member.id)}<option value={member.id} disabled={member.id === hostA}>{member.full_name}</option>{/each}
        </select>
      </div>

      <div class="u-field">
        <label for="hosting-items" class="u-field-label">عناصر الضيافة</label>
        <textarea id="hosting-items" class="u-input u-textarea" bind:value={items} rows="3" disabled={saving} placeholder="قهوة&#10;تمر&#10;عشاء"></textarea>
        <p class="u-field-hint">كل عنصر في سطر، أو افصل العناصر بفاصلة.</p>
      </div>

      <div class="u-field">
        <label for="hosting-count" class="u-field-label">العدد المتوقع *</label>
        <input id="hosting-count" class="u-input" type="number" bind:value={expectedCount} min="0" max="500" step="1" required disabled={saving} inputmode="numeric" />
      </div>
    {/if}
  </form>

  <div class="u-modal-footer">
    <button type="button" class="u-btn u-btn-ghost" disabled={saving} onclick={onclose}>إلغاء</button>
    {#if error}<button type="button" class="u-btn u-btn-ghost" disabled={loading || saving} onclick={load}>تحديث الخيارات</button>{/if}
    <button type="submit" form="hosting-form" class="u-btn u-btn-primary" disabled={saving || loading || (mode === 'swap' ? !replacements.length : !events.length)}>
      {saving ? 'جارٍ الحفظ…' : mode === 'swap' ? 'إرسال الطلب' : isEdit ? 'حفظ' : 'إضافة'}
    </button>
  </div>
</HostingModal>

<style>
  .ctx {
    padding: var(--sp-1) var(--sp-2);
    background: var(--brand-softer);
    border-radius: var(--r-sm);
    margin-bottom: var(--sp-2);
    font-size: var(--fs-sm);
  }
</style>
