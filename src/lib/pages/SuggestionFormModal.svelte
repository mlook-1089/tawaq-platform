<script lang="ts">
  import { Lightbulb, Plus, X } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { session } from '../stores';
  import Icon from '../components/Icon.svelte';

  let { onclose, onsaved }: { onclose: () => void; onsaved: () => void } = $props();

  const user = $derived($session?.user);

  let type = $state<'event' | 'location' | 'feature' | 'general'>('event');
  let title = $state('');
  let description = $state('');
  let saving = $state(false);
  let error = $state('');

  const types = [
    { id: 'event', label: 'اقتراح فعالية' },
    { id: 'location', label: 'اقتراح موقع / استراحة' },
    { id: 'feature', label: 'اقتراح ميزة بالمنصة' },
    { id: 'general', label: 'اقتراح عام' }
  ];

  async function handleSubmit(e: Event) {
    e.preventDefault();
    if (!title.trim() || title.length < 3) {
      error = 'العنوان يجب أن يتكون من 3 أحرف على الأقل';
      return;
    }

    const userId = user?.id;
    if (!userId) return;

    saving = true;
    error = '';

    try {
      const { error: err } = await supabase.from('suggestions').insert({
        user_id: userId,
        type,
        title: title.trim(),
        description: description.trim() || null,
        status: 'open'
      });

      if (err) throw err;
      onsaved();
    } catch (err: any) {
      error = err.message || 'تعذّر إرسال الاقتراح';
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
      <div class="modal-title-row">
        <Icon icon={Lightbulb} size={18} />
        <span>تقديم اقتراح جديد</span>
      </div>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق"><Icon icon={X} /></button>
    </div>

    <form class="u-modal-body" onsubmit={handleSubmit}>
      {#if error}<div class="u-alert err">{error}</div>{/if}

      <div class="u-field">
        <label for="sg-type" class="u-field-label">نوع الاقتراح *</label>
        <select id="sg-type" class="u-input u-select" bind:value={type}>
          {#each types as t}
            <option value={t.id}>{t.label}</option>
          {/each}
        </select>
      </div>

      <div class="u-field">
        <label for="sg-title" class="u-field-label">عنوان الاقتراح *</label>
        <input
          id="sg-title"
          class="u-input"
          bind:value={title}
          required
          minlength="3"
          maxlength="150"
          placeholder="مثال: بطولة بادل شهرية بين الأعضاء"
        />
      </div>

      <div class="u-field">
        <label for="sg-desc" class="u-field-label">التفاصيل والشرح</label>
        <textarea
          id="sg-desc"
          class="u-input u-textarea"
          bind:value={description}
          rows="4"
          maxlength="2000"
          placeholder="اشرح فكرتك، كيف ستفيد المجموعة، وأي تفاصيل مقترحة للتنفيذ…"
        ></textarea>
      </div>
    </form>

    <div class="u-modal-footer">
      <button type="button" class="u-btn u-btn-ghost" onclick={onclose}>إلغاء</button>
      <button
        type="submit"
        class="u-btn u-btn-primary"
        disabled={saving || title.trim().length < 3}
        onclick={handleSubmit}
      >
        <Icon icon={Plus} size={15} />
        <span>{saving ? 'جارٍ الإرسال…' : 'إرسال الاقتراح'}</span>
      </button>
    </div>
  </div>
</div>

<style>
  .modal-title-row {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    color: var(--brand);
  }
</style>
