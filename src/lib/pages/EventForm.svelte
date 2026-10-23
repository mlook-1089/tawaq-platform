<script lang="ts">
  import { supabase } from '../supabase';
  import { roles } from '../stores';
  import { EVENT_TYPES, fmtInput, myAllowedTypes } from '../utils';

  let { event = null, onclose, onsaved }: { event?: any; onclose: () => void; onsaved: () => void } = $props();

  const isEdit = !!event;
  const allowedTypes = $derived(isEdit ? [event.type] : myAllowedTypes($roles));

  let type = $state(event?.type || allowedTypes[0] || 'cultural');
  let title = $state(event?.title || '');
  let start_at = $state(event ? fmtInput(event.start_at) : '');
  let end_at = $state(event?.end_at ? fmtInput(event.end_at) : '');
  let location_name = $state(event?.location_name || '');
  let location_url = $state(event?.location_url || '');
  let notes = $state(event?.notes || '');
  let saving = $state(false);
  let error = $state('');

  async function save(e: Event) {
    e.preventDefault();
    error = ''; saving = true;
    try {
      const payload: any = {
        type, title: title.trim(),
        start_at: new Date(start_at).toISOString(),
        end_at: end_at ? new Date(end_at).toISOString() : null,
        location_name: location_name.trim() || null,
        location_url: location_url.trim() || null,
        notes: notes.trim() || null,
        color_tag: EVENT_TYPES[type]?.color || '#0E2B22'
      };
      let res;
      if (isEdit) {
        res = await supabase.from('events').update(payload).eq('id', event.id);
      } else {
        const { data: { user } } = await supabase.auth.getUser();
        payload.created_by = user?.id;
        res = await supabase.from('events').insert(payload);
      }
      if (res.error) throw res.error;
      onsaved();
    } catch (e: any) {
      error = e.message || 'حدث خطأ';
    } finally {
      saving = false;
    }
  }
</script>

<div class="overlay" onclick={onclose} role="button" tabindex="-1" onkeydown={(e) => e.key === 'Escape' && onclose()}>
  <div class="modal" onclick={(e) => e.stopPropagation()} role="dialog" tabindex="-1">
    <div class="mh">
      <span>{isEdit ? 'تعديل فعالية' : 'فعالية جديدة'}</span>
      <button class="x" onclick={onclose}>✕</button>
    </div>
    <form class="mb" onsubmit={save}>
      {#if error}<div class="alert err">{error}</div>{/if}

      <div class="field">
        <label>النوع *</label>
        <select bind:value={type} disabled={isEdit}>
          {#each allowedTypes as t}
            <option value={t}>{EVENT_TYPES[t]?.label || t}</option>
          {/each}
        </select>
      </div>

      <div class="field">
        <label>العنوان *</label>
        <input bind:value={title} required maxlength="200" placeholder="مثال: طلعة الأربعاء" />
      </div>

      <div class="field">
        <label>التاريخ والوقت *</label>
        <input type="datetime-local" bind:value={start_at} required />
      </div>

      <div class="field">
        <label>وقت الانتهاء (اختياري)</label>
        <input type="datetime-local" bind:value={end_at} />
      </div>

      <div class="field">
        <label>الموقع</label>
        <input bind:value={location_name} placeholder="مثال: استراحة الفيصلية" />
      </div>

      <div class="field">
        <label>رابط الخرائط (اختياري)</label>
        <input bind:value={location_url} placeholder="https://maps.google.com/..." type="url" />
      </div>

      <div class="field">
        <label>ملاحظات</label>
        <textarea bind:value={notes} rows="3" placeholder="تفاصيل إضافية…"></textarea>
      </div>

      <div class="mf">
        <button type="button" class="btn ghost" onclick={onclose}>إلغاء</button>
        <button type="submit" class="btn" disabled={saving}>{saving ? 'جارٍ…' : (isEdit ? 'حفظ' : 'إضافة')}</button>
      </div>
    </form>
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
  @media (min-width: 768px) {
    .overlay { align-items: center; }
    .modal { border-radius: 22px !important; max-height: 85vh !important; }
  }
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
    font-size: 14.5px;
  }
  .x {
    background: rgba(255, 255, 255, .18);
    border: none;
    color: #fff;
    width: 30px; height: 30px;
    border-radius: 50%;
    font-size: 13px;
    cursor: pointer;
  }

  .mb {
    padding: 20px;
    overflow-y: auto;
    flex: 1;
  }

  .field { margin-bottom: 14px; }
  .field label {
    display: block;
    font-size: 12px;
    font-weight: 600;
    margin-bottom: 6px;
    color: var(--brand);
  }
  .field input, .field select, .field textarea {
    width: 100%;
    padding: 12px 13px;
    border: 1.5px solid var(--line);
    border-radius: 12px;
    font-family: inherit;
    font-size: 16px;
    background: var(--card);
    color: var(--ink);
    transition: border .15s, box-shadow .15s;
  }
  .field input:focus, .field select:focus, .field textarea:focus {
    outline: none;
    border-color: var(--brand);
    box-shadow: 0 0 0 3px var(--brand-soft);
  }
  .field input:disabled, .field select:disabled { opacity: .6; }

  .alert { padding: 10px 14px; border-radius: 10px; font-size: 12.5px; margin-bottom: 12px; font-weight: 500; }
  .alert.err { background: var(--bad-soft); color: var(--bad); }

  .mf {
    padding-top: 10px;
    border-top: 1px solid var(--line);
    display: flex;
    gap: 8px;
    justify-content: flex-end;
    position: sticky;
    bottom: 0;
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
