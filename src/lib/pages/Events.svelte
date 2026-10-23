<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../supabase';
  import { roles } from '../stores';
  import { fmtDate, fmtTime, EVENT_TYPES, myAllowedTypes, canCreateType } from '../utils';
  import PageHead from '../components/PageHead.svelte';
  import EventForm from './EventForm.svelte';

  let events = $state<any[]>([]);
  let loading = $state(true);
  let error = $state('');
  let filter = $state('all');
  let showForm = $state(false);
  let editingEvent = $state<any>(null);

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

<PageHead icon="📅" title="جدول الفعاليات" />

<div class="filters">
  <div class="u-chips">
    <button class="u-chip" class:on={filter === 'all'} onclick={() => filter = 'all'}>الكل</button>
    {#each Object.entries(EVENT_TYPES) as [k, v] (k)}
      <button class="u-chip" class:on={filter === k} onclick={() => filter = k}>{v.label}</button>
    {/each}
  </div>
  {#if allowedTypes.length}
    <button class="u-btn u-btn-gold sm" onclick={openCreate}>+ إضافة</button>
  {/if}
</div>

{#if loading}
  <div class="u-stack">
    <div class="u-skel u-skel-card" style="height: 70px"></div>
    <div class="u-skel u-skel-card" style="height: 70px"></div>
    <div class="u-skel u-skel-card" style="height: 70px"></div>
  </div>
{:else if error}
  <div class="u-alert err">{error}</div>
{:else if filtered.length === 0}
  <div class="u-empty">
    <div class="ic">📅</div>
    <h3>لا توجد فعاليات في هذا التصنيف</h3>
  </div>
{:else}
  {#each groupedByDay as [day, dayEvents] (day)}
    <div class="u-day-head">{fmtDate(day)}</div>
    {#each dayEvents as e (e.id)}
      <div class="tw-event" style="border-right-color: {e.color_tag || EVENT_TYPES[e.type]?.color}">
        <div class="time">{fmtTime(e.start_datetime)}</div>
        <div class="body">
          <div class="title">{e.title}</div>
          <div class="meta">
            <span class="u-pill" style="background: {e.color_tag || EVENT_TYPES[e.type]?.color}; color: var(--on-brand)">
              {EVENT_TYPES[e.type]?.label || e.type}
            </span>
            {#if e.location_name}<span>📍 {e.location_name}</span>{/if}
          </div>
          {#if e.description}<div class="desc">{e.description}</div>{/if}
        </div>
        {#if canCreateType($roles, e.type)}
          <div class="actions">
            <button class="u-btn u-btn-ghost sm icon-only" onclick={() => openEdit(e)} aria-label="تعديل">✎</button>
            <button class="u-btn u-btn-ghost sm icon-only danger-btn" onclick={() => deleteEvent(e)} aria-label="حذف">🗑</button>
          </div>
        {/if}
      </div>
    {/each}
  {/each}
{/if}

{#if showForm}
  <EventForm event={editingEvent} onclose={() => showForm = false} onsaved={onSaved} />
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

  .desc {
    font-size: var(--fs-xs);
    color: var(--ink2);
    margin-top: 4px;
    line-height: var(--lh-base);
  }

  .actions { display: flex; gap: 4px; flex-shrink: 0; }
  .danger-btn:hover { background: var(--bad-soft); color: var(--bad); border-color: var(--bad-soft); }
</style>
