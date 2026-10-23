<script lang="ts">
  import { onMount } from 'svelte';
  import { ClipboardCheck, LoaderCircle, Save, X } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { session } from '../stores';
  import Icon from '../components/Icon.svelte';

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

  const statuses: Array<{ k: string; label: string; cls: string }> = [
    { k: 'present', label: 'ح', cls: 'on-ok' },
    { k: 'late',    label: 'م', cls: 'on-warn' },
    { k: 'excused', label: 'ع', cls: 'on-info' },
    { k: 'absent',  label: 'غ', cls: 'on-bad' }
  ];
</script>

<div class="u-modal" onclick={onclose} onkeydown={(e) => e.key === 'Escape' && onclose()} role="presentation">
  <div class="u-modal-scrim"></div>
  <div class="u-modal-box wide" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
    <div class="u-sheet-handle"></div>
    <div class="u-modal-header">
      <span class="modal-title"><Icon icon={ClipboardCheck} size={18} /> التحضير · {event?.title || '…'}</span>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق"><Icon icon={X} /></button>
    </div>

    <div class="u-modal-body">
      {#if loading}
        <div class="loader"><Icon icon={LoaderCircle} size={32} class="u-spin-icon" /></div>
      {:else}
        <p class="u-muted center">اختر حالة لكل عضو · (ح=حاضر · م=متأخر · ع=معذور · غ=غائب)</p>
        {#if error}<div class="u-alert err">{error}</div>{/if}

        <ul class="users-list">
          {#each users as u (u.id)}
            {@const current = attendance[u.id]?.status}
            <li class="user-row">
              <span class="u-avatar circle sm">{String(u.full_name || 'ع').charAt(0)}</span>
              <div class="user-name">{u.full_name}</div>
              <div class="u-seg status-seg">
                {#each statuses as s (s.k)}
                  <button
                    class="seg-btn"
                    class:on={current === s.k && !s.cls}
                    class:on-ok={current === s.k && s.cls === 'on-ok'}
                    class:on-warn={current === s.k && s.cls === 'on-warn'}
                    class:on-info={current === s.k && s.cls === 'on-info'}
                    class:on-bad={current === s.k && s.cls === 'on-bad'}
                    onclick={() => setStatus(u.id, current === s.k ? '' : s.k)}
                    aria-label={s.k}
                  >{s.label}</button>
                {/each}
              </div>
            </li>
          {/each}
        </ul>
      {/if}
    </div>

    <div class="u-modal-footer">
      <button class="u-btn u-btn-ghost" onclick={onclose}>إلغاء</button>
      <button class="u-btn u-btn-primary" disabled={saving || loading} onclick={save}>
        <Icon icon={Save} size={15} />
        {saving ? 'جارٍ…' : 'حفظ'}
      </button>
    </div>
  </div>
</div>

<style>
  .center { text-align: center; margin-bottom: var(--sp-2); }
  .modal-title { display: inline-flex; align-items: center; gap: var(--sp-1); }
  .loader { display: flex; justify-content: center; padding: var(--sp-5); }

  .users-list {
    list-style: none;
    padding: 0;
    margin: 0;
  }
  .user-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: var(--sp-1);
    padding: var(--sp-2) 0;
    border-bottom: 1px solid var(--line);
  }
  .user-row:last-child { border-bottom: none; }
  .user-name {
    font: var(--fw-semi) var(--fs-sm) var(--font-sans);
    flex: 1;
    min-width: 0;
  }
  .status-seg {
    flex-shrink: 0;
  }
  .status-seg .seg-btn {
    min-width: var(--sp-6);
    padding: var(--sp-05) var(--sp-1);
    font: var(--fw-bold) var(--fs-xs) var(--font-sans);
  }
</style>
