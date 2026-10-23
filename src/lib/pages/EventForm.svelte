<script lang="ts">
  import { supabase } from '../supabase';
  import { roles } from '../stores';
  import { EVENT_TYPES, fmtInput, myAllowedTypes } from '../utils';

  let { event = null, onclose, onsaved }: { event?: any; onclose: () => void; onsaved: () => void } = $props();

  const isEdit = !!event;
  const allowedTypes = $derived(isEdit ? [event.type] : myAllowedTypes($roles));

  let type = $state(event?.type || allowedTypes[0] || 'cultural');
  let title = $state(event?.title || '');
  let start_at = $state(event ? fmtInput(event.start_datetime) : '');
  let end_at = $state(event?.end_datetime ? fmtInput(event.end_datetime) : '');
  let location_name = $state(event?.location_name || '');
  let location_url = $state(event?.maps_url || '');
  let notes = $state(event?.description || '');
  let geofence_lat = $state<string>(event?.geofence_lat?.toString() || '');
  let geofence_lng = $state<string>(event?.geofence_lng?.toString() || '');
  let geofence_radius = $state<string>(event?.geofence_radius_m?.toString() || '150');
  let gettingLocation = $state(false);
  let locMsg = $state('');

  async function useMyLocation() {
    gettingLocation = true;
    locMsg = '';
    if (!navigator.geolocation) {
      locMsg = 'الموقع غير مدعوم في المتصفح';
      gettingLocation = false;
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        geofence_lat = pos.coords.latitude.toFixed(6);
        geofence_lng = pos.coords.longitude.toFixed(6);
        locMsg = 'تم تحديد الموقع ✓';
        gettingLocation = false;
      },
      (err) => {
        locMsg = 'تعذّر الحصول على الموقع: ' + err.message;
        gettingLocation = false;
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  }
  let saving = $state(false);
  let error = $state('');

  async function save(e: Event) {
    e.preventDefault();
    error = ''; saving = true;
    try {
      const payload: any = {
        type, title: title.trim(),
        start_datetime: new Date(start_at).toISOString(),
        end_datetime: end_at ? new Date(end_at).toISOString() : null,
        location_name: location_name.trim() || null,
        maps_url: location_url.trim() || null,
        description: notes.trim() || null,
        color_tag: EVENT_TYPES[type]?.color || '#0E2B22',
        geofence_lat: geofence_lat ? Number(geofence_lat) : null,
        geofence_lng: geofence_lng ? Number(geofence_lng) : null,
        geofence_radius_m: (geofence_lat && geofence_lng) ? Number(geofence_radius) : null
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

      <div class="geofence-box">
        <div class="gf-header">
          <span>📍 موقع التحضير الذكي (Geofence)</span>
          <button type="button" class="use-loc" onclick={useMyLocation} disabled={gettingLocation}>
            {gettingLocation ? 'جارٍ…' : 'استخدم موقعي الحالي'}
          </button>
        </div>
        {#if locMsg}<div class="loc-msg">{locMsg}</div>{/if}
        <div class="gf-row">
          <div class="field compact">
            <label>خط العرض</label>
            <input type="number" step="any" bind:value={geofence_lat} placeholder="24.7136" />
          </div>
          <div class="field compact">
            <label>خط الطول</label>
            <input type="number" step="any" bind:value={geofence_lng} placeholder="46.6753" />
          </div>
          <div class="field compact">
            <label>نصف القطر (م)</label>
            <input type="number" min="20" max="2000" bind:value={geofence_radius} />
          </div>
        </div>
        <p class="hint">عند حفظ الموقع، الأعضاء يستطيعون تحضير أنفسهم تلقائياً عند الوصول للنطاق.</p>
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

  .geofence-box {
    background: var(--gold-soft);
    border: 1px dashed var(--gold);
    border-radius: 13px;
    padding: 14px;
    margin-bottom: 14px;
  }
  .gf-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 10px;
    font-size: 13px;
    font-weight: 700;
    color: var(--brand);
    flex-wrap: wrap;
    gap: 8px;
  }
  .use-loc {
    background: var(--brand);
    color: #fff;
    border: none;
    border-radius: 8px;
    padding: 6px 11px;
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
  }
  .use-loc:disabled { opacity: .5; }
  .loc-msg {
    padding: 6px 10px;
    background: var(--card);
    border-radius: 8px;
    font-size: 11.5px;
    color: var(--brand);
    margin-bottom: 10px;
  }
  .gf-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
  }
  @media (min-width: 480px) { .gf-row { grid-template-columns: 1fr 1fr 1fr; } }
  .gf-row .field { margin-bottom: 0; }
  .field.compact label { font-size: 11px; }
  .field.compact input { padding: 9px 11px; font-size: 14px; }
  .hint { font-size: 11px; color: var(--ink3); margin-top: 8px; }
</style>
