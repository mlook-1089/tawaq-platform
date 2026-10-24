<script lang="ts">
  import { onMount } from 'svelte';
  import { Clock, MapPin, Pencil, Plus, Trash2 } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { roles } from '../stores';
  import { fmtDate, fmtTime, hijriDate, EVENT_TYPES, myAllowedTypes, canCreateType } from '../utils';
  import { confirmDialog, toastErr, toastOk } from '../toast';
  import Icon from '../components/Icon.svelte';
  import EmptyIllustrations from '../components/EmptyIllustrations.svelte';
  import EventForm from './EventForm.svelte';
  import EventDetailModal from './EventDetailModal.svelte';

  const eventPill: Record<string, string> = {
    weekly: 'brand', sport: 'gold', cultural: 'info',
    competition: 'warn', event: 'brand', hospitality: 'gold'
  };

  let events = $state<any[]>([]);
  let loading = $state(true);
  let error = $state('');
  let filter = $state('all');
  let showForm = $state(false);
  let editingEvent = $state<any>(null);
  let selectedEvent = $state<any>(null);

  const allowedTypes = $derived(myAllowedTypes($roles));

  async function load() {
    loading = true; error = '';
    const { data, error: err } = await supabase
      .from('events')
      .select('*')
      .is('deleted_at', null)
      .gte('start_datetime', new Date().toISOString())
      .order('start_datetime', { ascending: true });
    if (err) { error = err.message; } else { events = data || []; }
    loading = false;
  }

  onMount(load);

  const filtered = $derived(
    filter === 'all' ? events : events.filter(e => e.type === filter)
  );

  const eventCounts = $derived.by(() => {
    const c: Record<string, number> = {};
    for (const e of events) {
      c[e.type] = (c[e.type] || 0) + 1;
    }
    return c;
  });

  const groupedByDay = $derived.by(() => {
    const g: Record<string, any[]> = {};
    for (const e of filtered) {
      const k = new Date(e.start_datetime).toISOString().slice(0, 10);
      (g[k] = g[k] || []).push(e);
    }
    return Object.entries(g).sort(([a], [b]) => a.localeCompare(b));
  });

  function openCreate() { editingEvent = null; showForm = true; }
  function openEdit(e: any) { editingEvent = e; showForm = true; }
  function onSaved() { showForm = false; load(); }

  async function deleteEvent(e: any) {
    const ok = await confirmDialog({
      title: 'حذف الفعالية',
      message: `هل أنت متأكد من حذف "${e.title}"؟`,
      confirmLabel: 'حذف',
      danger: true
    });
    if (!ok) return;
    const { error: err } = await supabase.from('events').update({ deleted_at: new Date().toISOString() }).eq('id', e.id);
    if (err) toastErr(err.message);
    else { toastOk('تم حذف الفعالية'); load(); }
  }
</script>

<div class="u-page">
  <div class="u-top">
    <div>
      <div class="u-sub">{events.length} فعالية قادمة</div>
      <h1>جدول الفعاليات</h1>
    </div>
    {#if allowedTypes.length}
      <div class="u-actions">
        <button class="u-btn u-btn-primary sm" onclick={openCreate}>
          <Icon icon={Plus} size={15} /> إضافة
        </button>
      </div>
    {/if}
  </div>

  <div class="u-chips">
    <button class="u-chip" class:on={filter === 'all'} onclick={() => filter = 'all'}>
      الكل <span class="chip-count">{events.length}</span>
    </button>
    {#each Object.entries(EVENT_TYPES) as [k, v] (k)}
      <button class="u-chip" class:on={filter === k} onclick={() => filter = k}>
        {v.label}{eventCounts[k] ? ` ` : ''}
        {#if eventCounts[k]}<span class="chip-count">{eventCounts[k]}</span>{/if}
      </button>
    {/each}
  </div>

  {#if loading}
    <div class="u-stack">
      <div class="u-skel event-skel"></div>
      <div class="u-skel event-skel"></div>
      <div class="u-skel event-skel"></div>
    </div>
  {:else if error}
    <div class="u-alert err">{error}</div>
  {:else if filtered.length === 0}
    <div class="u-empty">
      <EmptyIllustrations kind="calendar" />
      <h3>لا توجد فعاليات في هذا التصنيف</h3>
      <p>جرّب تصنيفًا آخر أو أضف فعالية جديدة.</p>
    </div>
  {:else}
    {#each groupedByDay as [day, dayEvents] (day)}
      <div class="u-day-head">
        {fmtDate(day)}
        <span class="hijri">· {hijriDate(day)}</span>
      </div>
      <section class="u-card flush">
        <div class="u-list">
          {#each dayEvents as e (e.id)}
            <div class="u-item tap event-row" onclick={() => (selectedEvent = e)}
              onkeydown={(ev) => ev.key === 'Enter' && (selectedEvent = e)}
              tabindex="0" role="button">
              <div class="date-chip">
                <div class="d-num">{new Date(e.start_datetime).getDate()}</div>
                <div class="d-mo">{new Intl.DateTimeFormat('ar', { month: 'short' }).format(new Date(e.start_datetime))}</div>
              </div>
              <div class="u-grow">
                <div class="u-name">{e.title}</div>
                <div class="u-muted event-meta">
                  <span><Icon icon={Clock} size={12} /> {fmtTime(e.start_datetime)}</span>
                  {#if e.location_name}<span><Icon icon={MapPin} size={12} /> {e.location_name}</span>{/if}
                </div>
              </div>
              <div class="row-end" onclick={(ev) => ev.stopPropagation()} role="presentation">
                <span class="u-pill {eventPill[e.type] || 'brand'}">{EVENT_TYPES[e.type]?.label || e.type}</span>
                {#if canCreateType($roles, e.type)}
                  <div class="actions">
                    <button class="u-btn-icon" onclick={() => openEdit(e)} aria-label="تعديل"><Icon icon={Pencil} size={15} /></button>
                    <button class="u-btn-icon danger-btn" onclick={() => deleteEvent(e)} aria-label="حذف"><Icon icon={Trash2} size={15} /></button>
                  </div>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      </section>
    {/each}
  {/if}
</div>

{#if showForm}
  <EventForm event={editingEvent} onclose={() => showForm = false} onsaved={onSaved} />
{/if}

{#if selectedEvent}
  <EventDetailModal event={selectedEvent} onclose={() => (selectedEvent = null)} />
{/if}

<style>
  .event-skel { height: 64px; border-radius: var(--r-md); }

  .u-day-head .hijri {
    color: var(--ink3);
    font-weight: var(--fw-regular);
    margin-inline-start: var(--sp-05);
    text-transform: none;
  }

  .chip-count {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 20px;
    padding: 0 6px;
    height: 18px;
    background: var(--muted-bg);
    color: var(--ink2);
    border-radius: var(--r-pill);
    font: var(--fw-bold) 10.5px var(--font-sans);
    font-variant-numeric: tabular-nums;
    margin-inline-start: 4px;
  }
  :global(.u-chip.on) .chip-count {
    background: color-mix(in oklab, var(--bg) 25%, transparent);
    color: var(--bg);
  }

  .event-row {
    padding: var(--sp-2) 0;
    gap: var(--sp-2);
  }
  .date-chip {
    width: 44px;
    text-align: center;
    padding: 4px 0;
    background: var(--brand-soft);
    border-radius: var(--r-sm);
    flex-shrink: 0;
  }
  .date-chip .d-num {
    font: var(--fw-bold) 18px/1 var(--font-sans);
    color: var(--brand-ink);
    font-variant-numeric: tabular-nums;
  }
  .date-chip .d-mo {
    font-size: 10px;
    color: var(--ink3);
    font-weight: var(--fw-medium);
    margin-top: 1px;
  }
  .event-meta {
    display: flex;
    flex-wrap: wrap;
    gap: var(--sp-1);
    margin-top: 2px;
  }
  .event-meta span {
    display: inline-flex;
    align-items: center;
    gap: 3px;
  }
  .row-end {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 4px;
    flex-shrink: 0;
  }
  .actions { display: flex; gap: var(--sp-05); }
  .danger-btn:hover { background: var(--bad-soft); color: var(--bad); border-color: var(--bad-soft); }
</style>
