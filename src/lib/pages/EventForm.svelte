<script lang="ts">
  import { LocateFixed, MapPin, Plus, Save, X } from 'lucide-svelte';
  import { untrack } from 'svelte';
  import { supabase } from '../supabase';
  import { roles } from '../stores';
  import { EVENT_TYPES, fmtInput, myAllowedTypes } from '../utils';
  import Icon from '../components/Icon.svelte';

  let { event = null, onclose, onsaved }:
    { event?: any; onclose: () => void; onsaved: () => void } = $props();

  const initial = untrack(() => event);
  const isEdit = !!initial;
  const initialTypes = untrack(() => isEdit ? [initial.type] : myAllowedTypes($roles));
  const allowedTypes = $derived(isEdit ? [initial.type] : myAllowedTypes($roles));

  let type = $state(initial?.type || initialTypes[0] || 'cultural');
  let title = $state(initial?.title || '');
  let start_at = $state(initial ? fmtInput(initial.start_datetime) : '');
  let end_at = $state(initial?.end_datetime ? fmtInput(initial.end_datetime) : '');
  let location_name = $state(initial?.location_name || '');
  let location_url = $state(initial?.maps_url || '');
  let notes = $state(initial?.description || '');
  let geofence_lat = $state<string>(initial?.geofence_lat?.toString() || '');
  let geofence_lng = $state<string>(initial?.geofence_lng?.toString() || '');
  let geofence_radius = $state<string>(initial?.geofence_radius_m?.toString() || '150');
  let gettingLocation = $state(false);
  let locMsg = $state('');
  let saving = $state(false);
  let error = $state('');

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
        locMsg = 'تم تحديد الموقع';
        gettingLocation = false;
      },
      (err) => {
        locMsg = 'تعذّر الحصول على الموقع: ' + err.message;
        gettingLocation = false;
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  }

  async function save(e: Event) {
    e.preventDefault();
    error = ''; saving = true;
    try {
      const colorValue = EVENT_TYPES[type]?.color || 'var(--brand)';
      const colorToken = colorValue.match(/^var\((--[^)]+)\)$/)?.[1];
      const colorTag = colorToken
        ? getComputedStyle(document.documentElement).getPropertyValue(colorToken).trim()
        : colorValue;
      const payload: any = {
        type, title: title.trim(),
        start_datetime: new Date(start_at).toISOString(),
        end_datetime: end_at ? new Date(end_at).toISOString() : null,
        location_name: location_name.trim() || null,
        maps_url: location_url.trim() || null,
        description: notes.trim() || null,
        color_tag: colorTag,
        geofence_lat: geofence_lat ? Number(geofence_lat) : null,
        geofence_lng: geofence_lng ? Number(geofence_lng) : null,
        geofence_radius_m: (geofence_lat && geofence_lng) ? Number(geofence_radius) : null
      };
      let res;
      if (isEdit) {
        res = await supabase.from('events').update(payload).eq('id', initial.id);
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

<div class="u-modal" onclick={onclose} onkeydown={(e) => e.key === 'Escape' && onclose()} role="presentation">
  <div class="u-modal-scrim"></div>
  <div class="u-modal-box wide" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
    <div class="u-sheet-handle"></div>
    <div class="u-modal-header">
      <span>{isEdit ? 'تعديل فعالية' : 'فعالية جديدة'}</span>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق"><Icon icon={X} /></button>
    </div>

    <form class="u-modal-body" onsubmit={save}>
      {#if error}<div class="u-alert err">{error}</div>{/if}

      <div class="u-field">
        <label for="ef-type" class="u-field-label">النوع *</label>
        <select id="ef-type" class="u-input u-select" bind:value={type} disabled={isEdit}>
          {#each allowedTypes as t}
            <option value={t}>{EVENT_TYPES[t]?.label || t}</option>
          {/each}
        </select>
      </div>

      <div class="u-field">
        <label for="ef-title" class="u-field-label">العنوان *</label>
        <input id="ef-title" class="u-input" bind:value={title} required maxlength="200" placeholder="مثال: طلعة الأربعاء" />
      </div>

      <div class="u-field">
        <label for="ef-start" class="u-field-label">التاريخ والوقت *</label>
        <input id="ef-start" class="u-input" type="datetime-local" bind:value={start_at} required />
      </div>

      <div class="u-field">
        <label for="ef-end" class="u-field-label">وقت الانتهاء (اختياري)</label>
        <input id="ef-end" class="u-input" type="datetime-local" bind:value={end_at} />
      </div>

      <div class="u-field">
        <label for="ef-loc" class="u-field-label">الموقع</label>
        <input id="ef-loc" class="u-input" bind:value={location_name} placeholder="مثال: استراحة الفيصلية" />
      </div>

      <div class="u-field">
        <label for="ef-maps" class="u-field-label">رابط الخرائط (اختياري)</label>
        <input id="ef-maps" class="u-input" bind:value={location_url} placeholder="https://maps.google.com/..." type="url" />
      </div>

      <div class="u-field">
        <label for="ef-notes" class="u-field-label">ملاحظات</label>
        <textarea id="ef-notes" class="u-input u-textarea" bind:value={notes} rows="3" placeholder="تفاصيل إضافية…"></textarea>
      </div>

      <fieldset class="geofence-box">
        <legend><Icon icon={MapPin} size={15} /> موقع التحضير الذكي</legend>
        <div class="gf-actions">
          <button type="button" class="u-btn u-btn-primary sm" onclick={useMyLocation} disabled={gettingLocation}>
            <Icon icon={LocateFixed} size={15} />
            {gettingLocation ? 'جارٍ…' : 'استخدم موقعي الحالي'}
          </button>
          {#if locMsg}<span class="gf-msg">{locMsg}</span>{/if}
        </div>

        <div class="gf-grid">
          <div class="u-field">
            <label for="ef-lat" class="u-field-label">خط العرض</label>
            <input id="ef-lat" class="u-input" type="number" step="any" bind:value={geofence_lat} placeholder="24.7136" />
          </div>
          <div class="u-field">
            <label for="ef-lng" class="u-field-label">خط الطول</label>
            <input id="ef-lng" class="u-input" type="number" step="any" bind:value={geofence_lng} placeholder="46.6753" />
          </div>
          <div class="u-field">
            <label for="ef-rad" class="u-field-label">نصف القطر (م)</label>
            <input id="ef-rad" class="u-input" type="number" min="20" max="2000" bind:value={geofence_radius} />
          </div>
        </div>
        <p class="u-field-hint">عند حفظ الموقع، الأعضاء يستطيعون تحضير أنفسهم تلقائياً عند الوصول للنطاق.</p>
      </fieldset>
    </form>

    <div class="u-modal-footer">
      <button type="button" class="u-btn u-btn-ghost" onclick={onclose}>إلغاء</button>
      <button type="submit" class="u-btn u-btn-primary" disabled={saving} onclick={save}>
        <Icon icon={isEdit ? Save : Plus} size={15} />
        {saving ? 'جارٍ…' : (isEdit ? 'حفظ' : 'إضافة')}
      </button>
    </div>
  </div>
</div>

<style>
  .geofence-box {
    background: var(--muted-bg);
    border: 1px solid var(--line);
    border-radius: var(--r-xs);
    padding: var(--sp-2);
    margin-top: var(--sp-2);
  }
  .geofence-box > legend {
    padding: 0 var(--sp-1);
    font: var(--fw-bold) var(--fs-sm) var(--font-sans);
    color: var(--brand-ink);
    display: inline-flex;
    align-items: center;
    gap: var(--sp-05);
  }
  .gf-actions {
    display: flex;
    gap: var(--sp-1);
    align-items: center;
    flex-wrap: wrap;
    margin-bottom: var(--sp-2);
  }
  .gf-msg {
    padding: var(--sp-05) var(--sp-1);
    background: var(--card);
    border-radius: var(--r-sm);
    font-size: var(--fs-tiny);
    color: var(--brand);
  }
  .gf-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--sp-1);
  }
  @media (min-width: 480px) {
    .gf-grid { grid-template-columns: 1fr 1fr 1fr; }
  }
  .gf-grid .u-field { margin-bottom: 0; }
</style>
