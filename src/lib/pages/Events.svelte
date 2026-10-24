<script lang="ts">
  import { onMount } from 'svelte';
  import { CalendarDays, Clock, MapPin, Pencil, Plus, Trash2 } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { roles } from '../stores';
  import { fmtDate, fmtTime, hijriDate, EVENT_TYPES, myAllowedTypes, canCreateType } from '../utils';
  import PageHead from '../components/PageHead.svelte';
  import Icon from '../components/Icon.svelte';
  import EmptyIllustrations from '../components/EmptyIllustrations.svelte';
  import EventForm from './EventForm.svelte';
  import EventDetailModal from './EventDetailModal.svelte';

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
    if (!confirm('حذف هذه الفعالية؟')) return;
    const { error: err } = await supabase.from('events').update({ deleted_at: new Date().toISOString() }).eq('id', e.id);
    if (err) alert(err.message); else load();
  }
</script>

<PageHead icon={CalendarDays} title="جدول الفعاليات" subtitle="الفعاليات القادمة مرتبة حسب اليوم">
  {#snippet action()}
    {#if allowedTypes.length}
      <button class="u-btn u-btn-primary sm" onclick={openCreate}>
        <Icon icon={Plus} size={15} /> إضافة
      </button>
    {/if}
  {/snippet}
</PageHead>

<div class="filters">
  <div class="u-chips">
    <button class="u-chip" class:on={filter === 'all'} onclick={() => filter = 'all'}>الكل</button>
    {#each Object.entries(EVENT_TYPES) as [k, v] (k)}
      <button class="u-chip" class:on={filter === k} onclick={() => filter = k}>{v.label}</button>
    {/each}
  </div>
</div>

{#if loading}
  <div class="u-stack">
    <div class="u-skel event-skeleton"></div>
    <div class="u-skel event-skeleton"></div>
    <div class="u-skel event-skeleton"></div>
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
    {#each dayEvents as e (e.id)}
      <div
        class="tw-event interactive"
        onclick={() => (selectedEvent = e)}
        onkeydown={(ev) => ev.key === 'Enter' && (selectedEvent = e)}
        tabindex="0"
        role="button"
      >
        <time class="tw-event-date" datetime={e.start_datetime}>
          <span class="day-name">{fmtDate(e.start_datetime).split(' ')[0]}</span>
          <span class="day-number">{new Date(e.start_datetime).getDate()}</span>
        </time>
        <div class="body">
          <div class="title-line">
            <span class={`type-dot type-${e.type}`} aria-hidden="true"></span>
            <div class="title">{e.title}</div>
          </div>
          <div class="meta">
            <span class="meta-item"><Icon icon={Clock} size={14} />{fmtTime(e.start_datetime)}</span>
            {#if e.location_name}<span class="meta-item"><Icon icon={MapPin} size={14} />{e.location_name}</span>{/if}
            <span>{EVENT_TYPES[e.type]?.label || e.type}</span>
          </div>
          {#if e.description}<div class="desc">{e.description}</div>{/if}
        </div>
        {#if canCreateType($roles, e.type)}
          <div class="actions" onclick={(ev) => ev.stopPropagation()} role="presentation">
            <button class="u-btn-icon" onclick={() => openEdit(e)} aria-label="تعديل"><Icon icon={Pencil} size={15} /></button>
            <button class="u-btn-icon danger-btn" onclick={() => deleteEvent(e)} aria-label="حذف"><Icon icon={Trash2} size={15} /></button>
          </div>
        {/if}
      </div>
    {/each}
  {/each}
{/if}

{#if showForm}
  <EventForm event={editingEvent} onclose={() => showForm = false} onsaved={onSaved} />
{/if}

{#if selectedEvent}
  <EventDetailModal event={selectedEvent} onclose={() => (selectedEvent = null)} />
{/if}

<style>
  .filters {
    display: flex;
    gap: var(--sp-1);
    align-items: center;
    margin-bottom: var(--sp-2);
    flex-wrap: wrap;
  }
  .filters .u-chips { flex: 1; min-width: 0; }
  .event-skeleton { min-height: calc(var(--sp-8) + var(--sp-4)); border-radius: calc(var(--sp-1) + var(--sp-05)); }

  .desc {
    font-size: var(--fs-xs);
    color: var(--ink2);
    margin-top: var(--sp-05);
    line-height: var(--lh-base);
  }

  .u-day-head .hijri { color: var(--ink3); font-weight: var(--fw-regular); margin-inline-start: var(--sp-05); }
  .type-weekly { background: var(--brand); }
  .type-event { background: var(--brand-2); }
  .type-sport { background: var(--gold); }
  .type-cultural { background: var(--brand-3); }
  .type-competition { background: var(--warn); }
  .type-hospitality { background: var(--info); }
  .actions { display: flex; gap: var(--sp-05); flex-shrink: 0; }
  .danger-btn:hover { background: var(--bad-soft); color: var(--bad); border-color: var(--bad-soft); }
</style>
