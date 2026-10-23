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

<div class="chips">
  {#each [{ k: 'all', t: 'الكل' }, ...Object.entries(EVENT_TYPES).map(([k, v]) => ({ k, t: v.label }))] as c (c.k)}
    <button class="chip" class:on={filter === c.k} onclick={() => filter = c.k}>{c.t}</button>
  {/each}
  {#if allowedTypes.length}
    <button class="add" onclick={openCreate}>+ إضافة</button>
  {/if}
</div>

{#if loading}
  <div class="skel"></div>
  <div class="skel"></div>
  <div class="skel"></div>
{:else if error}
  <div class="alert err">{error}</div>
{:else if filtered.length === 0}
  <div class="empty">
    <div class="ic">📅</div>
    <p>لا توجد فعاليات في هذا التصنيف</p>
  </div>
{:else}
  {#each groupedByDay as [day, dayEvents] (day)}
    <div class="day-h">{fmtDate(day)}</div>
    {#each dayEvents as e (e.id)}
      <div class="ev" style="border-right: 4px solid {e.color_tag || EVENT_TYPES[e.type]?.color}">
        <div class="tm">{fmtTime(e.start_datetime)}</div>
        <div class="bd">
          <div class="tt">{e.title}</div>
          <div class="mt">
            <span class="badge" style="background: {e.color_tag || EVENT_TYPES[e.type]?.color}; color: #fff">
              {EVENT_TYPES[e.type]?.label || e.type}
            </span>
            {#if e.location_name}<span>📍 {e.location_name}</span>{/if}
          </div>
          {#if e.notes}<div class="notes">{e.notes}</div>{/if}
        </div>
        {#if canCreateType($roles, e.type)}
          <div class="actions">
            <button class="btn-sm" onclick={() => openEdit(e)}>✎</button>
            <button class="btn-sm danger" onclick={() => deleteEvent(e)}>🗑</button>
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
  .chips { display: flex; gap: 7px; flex-wrap: wrap; margin-bottom: 14px; align-items: center; }
  .chip {
    padding: 7px 14px;
    border-radius: 999px;
    font-size: 11.5px;
    font-weight: 500;
    background: var(--card);
    color: var(--ink3);
    border: 1px solid var(--line);
    cursor: pointer;
    font-family: inherit;
    transition: all .15s;
  }
  .chip.on { background: var(--brand); color: #fff; border-color: var(--brand); font-weight: 700; }
  .add {
    background: var(--gold);
    color: var(--brand);
    border: none;
    border-radius: 10px;
    padding: 8px 14px;
    font-size: 12px;
    font-weight: 700;
    margin-inline-start: auto;
    cursor: pointer;
  }

  .day-h {
    font-size: 11.5px;
    font-weight: 700;
    color: var(--brand);
    text-transform: uppercase;
    letter-spacing: .4px;
    margin: 16px 2px 9px;
  }

  .ev {
    background: var(--card);
    border-radius: 13px;
    padding: 13px 15px;
    display: flex;
    gap: 13px;
    align-items: center;
    box-shadow: var(--shadow);
    border: 1px solid var(--line);
    margin-bottom: 9px;
  }
  .tm {
    font-size: 14px;
    font-weight: 700;
    color: var(--brand);
    font-variant-numeric: tabular-nums;
    min-width: 48px;
    text-align: center;
    background: var(--gold-soft);
    border-radius: 10px;
    padding: 9px 4px;
  }
  .bd { flex: 1; min-width: 0; }
  .tt { font-weight: 600; font-size: 14px; margin-bottom: 4px; }
  .mt { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; font-size: 11px; color: var(--ink3); }
  .notes { font-size: 12px; color: var(--ink2); margin-top: 5px; }

  .badge {
    display: inline-block;
    font-size: 10px;
    font-weight: 600;
    padding: 3px 9px;
    border-radius: 999px;
    white-space: nowrap;
  }

  .actions { display: flex; gap: 4px; flex-shrink: 0; }
  .btn-sm {
    width: 32px; height: 32px;
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: 9px;
    cursor: pointer;
    font-size: 13px;
  }
  .btn-sm:hover { background: var(--gold-soft); border-color: var(--gold); }
  .btn-sm.danger:hover { background: var(--bad-soft); border-color: var(--bad); }

  .empty { text-align: center; padding: 40px 16px; color: var(--ink3); background: var(--card); border-radius: 18px; border: 1px solid var(--line); }
  .empty .ic { font-size: 42px; opacity: .4; margin-bottom: 10px; }

  .alert { padding: 12px 14px; border-radius: 12px; font-size: 12.5px; margin-bottom: 12px; font-weight: 500; }
  .alert.err { background: var(--bad-soft); color: var(--bad); }

  .skel { height: 70px; background: var(--muted-bg); border-radius: 13px; margin-bottom: 9px; animation: pulse 1.4s ease-in-out infinite; }
  @keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: .5; } }
</style>
