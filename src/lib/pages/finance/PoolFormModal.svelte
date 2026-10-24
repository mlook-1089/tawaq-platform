<script lang="ts">
  import { untrack } from 'svelte';
  import { Plus, Save, X } from 'lucide-svelte';
  import { supabase } from '../../supabase';
  import { session } from '../../stores';
  import Icon from '../../components/Icon.svelte';

  let {
    members,
    events,
    onclose,
    onsaved
  }: {
    members: any[];
    events: any[];
    onclose: () => void;
    onsaved: () => void;
  } = $props();

  const user = $derived($session?.user);

  let type = $state('rest_stop');
  let title = $state('');
  let description = $state('');
  let targetAmount = $state('');
  let managerUserId = $state(untrack(() => user?.id || ''));
  let eventId = $state('');
  let saving = $state(false);
  let error = $state('');

  const poolTypes = [
    { id: 'rest_stop', label: 'قطة استراحة' },
    { id: 'trip', label: 'قطة رحلة' },
    { id: 'event', label: 'قطة فعالية' },
    { id: 'custom', label: 'مخصصة' }
  ];

  async function handleSave(e: Event) {
    e.preventDefault();
    if (!title.trim() || !targetAmount) return;

    saving = true;
    error = '';

    try {
      const payload = {
        type,
        title: title.trim(),
        description: description.trim() || null,
        target_amount: Number(targetAmount),
        manager_user_id: managerUserId || user?.id,
        event_id: eventId || null,
        status: 'open'
      };

      const { error: err } = await supabase.from('pools').insert(payload);
      if (err) throw err;

      onsaved();
    } catch (err: any) {
      error = err.message || 'تعذّر إنشاء القطة';
    } finally {
      saving = false;
    }
  }
</script>

<div class="u-modal" onclick={onclose} onkeydown={(e) => e.key === 'Escape' && onclose()} role="presentation">
  <div class="u-modal-scrim"></div>
  <div class="u-modal-box" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
    <div class="u-sheet-handle"></div>
    <div class="u-modal-header">
      <span>إنشاء قطة جديدة</span>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق"><Icon icon={X} /></button>
    </div>

    <form class="u-modal-body" onsubmit={handleSave}>
      {#if error}<div class="u-alert err">{error}</div>{/if}

      <div class="u-field">
        <label for="pf-type" class="u-field-label">نوع القطة *</label>
        <select id="pf-type" class="u-input u-select" bind:value={type}>
          {#each poolTypes as t}
            <option value={t.id}>{t.label}</option>
          {/each}
        </select>
      </div>

      <div class="u-field">
        <label for="pf-title" class="u-field-label">عنوان القطة *</label>
        <input
          id="pf-title"
          class="u-input"
          bind:value={title}
          required
          placeholder="مثال: قطة استراحة الأربعاء"
        />
      </div>

      <div class="u-field">
        <label for="pf-amount" class="u-field-label">المبلغ المستهدف (ر.س) *</label>
        <input
          id="pf-amount"
          type="number"
          step="0.01"
          min="1"
          class="u-input"
          bind:value={targetAmount}
          required
          placeholder="500.00"
        />
      </div>

      <div class="u-field">
        <label for="pf-manager" class="u-field-label">المشرف على القطة *</label>
        <select id="pf-manager" class="u-input u-select" bind:value={managerUserId}>
          {#each members as m}
            <option value={m.id}>{m.full_name}</option>
          {/each}
        </select>
      </div>

      {#if events.length > 0}
        <div class="u-field">
          <label for="pf-event" class="u-field-label">ربط بفعالية (اختياري)</label>
          <select id="pf-event" class="u-input u-select" bind:value={eventId}>
            <option value="">بدون ربط</option>
            {#each events as ev}
              <option value={ev.id}>{ev.title}</option>
            {/each}
          </select>
        </div>
      {/if}

      <div class="u-field">
        <label for="pf-desc" class="u-field-label">ملاحظات وتفاصيل</label>
        <textarea
          id="pf-desc"
          class="u-input u-textarea"
          bind:value={description}
          rows="3"
          placeholder="شروط القطة أو تفاصيل التحويل والتوزيع…"
        ></textarea>
      </div>
    </form>

    <div class="u-modal-footer">
      <button type="button" class="u-btn u-btn-ghost" onclick={onclose}>إلغاء</button>
      <button
        type="submit"
        class="u-btn u-btn-primary"
        disabled={saving || !title.trim() || !targetAmount}
        onclick={handleSave}
      >
        <Icon icon={Plus} size={15} />
        <span>{saving ? 'جارٍ الإنشاء…' : 'إنشاء القطة'}</span>
      </button>
    </div>
  </div>
</div>
