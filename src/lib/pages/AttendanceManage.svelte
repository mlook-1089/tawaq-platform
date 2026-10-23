<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../supabase';
  import { session } from '../stores';

  let { eventId, onclose }: { eventId: string; onclose: () => void } = $props();

  let event = $state<any>(null);
  let users = $state<any[]>([]);
  let attendance = $state<Record<string, any>>({});
  let loading = $state(true);
  let saving = $state(false);
  let error = $state('');

  async function load() {
    loading = true;
    const [{ data: ev }, { data: us }, { data: att }] = await Promise.all([
      supabase.from('events').select('*').eq('id', eventId).single(),
      supabase.from('users').select('id,full_name,username').is('deleted_at', null).order('full_name'),
      supabase.from('attendance').select('*').eq('event_id', eventId)
    ]);
    event = ev;
    users = us || [];
    attendance = {};
    (att || []).forEach((a: any) => { attendance[a.user_id] = a; });
    loading = false;
  }

  onMount(load);

  function setStatus(userId: string, status: string) {
    const existing = attendance[userId] || {};
    attendance = { ...attendance, [userId]: { ...existing, user_id: userId, event_id: eventId, status, method: 'manual' } };
  }

  async function save() {
    saving = true; error = '';
    const changes = Object.values(attendance).filter((a: any) => a.status);
    const payload = changes.map((a: any) => ({
      event_id: eventId,
      user_id: a.user_id,
      status: a.status,
      method: a.method || 'manual',
      marked_by_user_id: $session!.user!.id,
      marked_at: new Date().toISOString()
    }));
    const { error: err } = await supabase.from('attendance').upsert(payload, { onConflict: 'event_id,user_id' });
    if (err) { error = err.message; } else { onclose(); }
    saving = false;
  }

  const statuses: Array<{ k: string; label: string; emoji: string }> = [
    { k: 'present', label: 'ح', emoji: '✓' },
    { k: 'late', label: 'م', emoji: '⏰' },
    { k: 'excused', label: 'ع', emoji: '✎' },
    { k: 'absent', label: 'غ', emoji: '✗' }
  ];
</script>

<div class="overlay" onclick={onclose} role="button" tabindex="-1">
  <div class="modal" onclick={(e) => e.stopPropagation()} role="dialog" tabindex="-1">
    <div class="mh">
      <span>📋 التحضير · {event?.title || '…'}</span>
      <button class="x" onclick={onclose}>✕</button>
    </div>

    <div class="mb">
      {#if loading}
        <div class="loader">جارٍ التحميل…</div>
      {:else}
        <p class="hint">اختر حالة لكل عضو · (ح=حاضر · م=متأخر · ع=معذور · غ=غائب)</p>
        {#if error}<div class="alert err">{error}</div>{/if}

        {#each users as u (u.id)}
          {@const current = attendance[u.id]?.status}
          <div class="row">
            <div class="name">{u.full_name}</div>
            <div class="btns">
              {#each statuses as s (s.k)}
                <button
                  class="st-btn s-{s.k}"
                  class:on={current === s.k}
                  onclick={() => setStatus(u.id, current === s.k ? '' : s.k)}
                >{s.label}</button>
              {/each}
            </div>
          </div>
        {/each}
      {/if}
    </div>

    <div class="mf">
      <button class="btn ghost" onclick={onclose}>إلغاء</button>
      <button class="btn" disabled={saving || loading} onclick={save}>{saving ? 'جارٍ…' : 'حفظ'}</button>
    </div>
  </div>
</div>

<style>
  .overlay {
    position: fixed; inset: 0;
    background: rgba(14, 43, 34, .55);
    backdrop-filter: blur(2px);
    z-index: 100;
    display: flex;
    align-items: flex-end;
    justify-content: center;
    animation: fade .2s;
  }
  @keyframes fade { from { opacity: 0; } to { opacity: 1; } }
  @media (min-width: 768px) { .overlay { align-items: center; } .modal { border-radius: 22px !important; max-height: 85vh !important; } }

  .modal {
    background: var(--card);
    border-radius: 24px 24px 0 0;
    width: 100%;
    max-width: 620px;
    max-height: 92vh;
    display: flex;
    flex-direction: column;
    animation: slide .25s cubic-bezier(.16, 1, .3, 1);
    overflow: hidden;
  }
  @keyframes slide { from { transform: translateY(60px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }

  .mh {
    padding: 16px 20px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    color: #fff;
    background: var(--brand);
    font-weight: 600;
    font-size: 14px;
  }
  .x { background: rgba(255,255,255,.18); border: none; color: #fff; width: 30px; height: 30px; border-radius: 50%; font-size: 13px; cursor: pointer; }

  .mb { padding: 16px 20px; overflow-y: auto; flex: 1; }
  .hint { font-size: 11.5px; color: var(--ink3); margin-bottom: 12px; text-align: center; }
  .alert.err { background: var(--bad-soft); color: var(--bad); padding: 10px; border-radius: 10px; margin-bottom: 12px; font-size: 12px; }
  .loader { text-align: center; padding: 30px; color: var(--ink3); }

  .row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 8px;
    padding: 10px 0;
    border-bottom: 1px solid var(--line);
  }
  .row:last-child { border-bottom: none; }
  .name { font-weight: 600; font-size: 13px; flex: 1; min-width: 0; }
  .btns { display: flex; gap: 4px; flex-shrink: 0; }
  .st-btn {
    width: 34px; height: 32px;
    border-radius: 9px;
    border: 1.5px solid var(--line);
    background: var(--card);
    font-family: inherit;
    font-size: 12px;
    font-weight: 700;
    cursor: pointer;
    color: var(--ink3);
    transition: all .12s;
  }
  .st-btn.on.s-present { background: var(--ok); border-color: var(--ok); color: #fff; }
  .st-btn.on.s-late { background: var(--gold); border-color: var(--gold); color: var(--brand); }
  .st-btn.on.s-excused { background: var(--info); border-color: var(--info); color: #fff; }
  .st-btn.on.s-absent { background: var(--bad); border-color: var(--bad); color: #fff; }

  .mf {
    padding: 13px 20px;
    border-top: 1px solid var(--line);
    display: flex;
    gap: 8px;
    justify-content: flex-end;
    background: var(--card);
  }
  .btn {
    padding: 11px 20px;
    background: var(--brand);
    color: #fff;
    border: none;
    border-radius: 11px;
    font-family: inherit;
    font-size: 13.5px;
    font-weight: 600;
    cursor: pointer;
  }
  .btn:disabled { opacity: .5; }
  .btn.ghost { background: transparent; color: var(--brand); border: 1.5px solid var(--line); }
</style>
