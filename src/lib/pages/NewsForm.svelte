<script lang="ts">
  import { untrack } from 'svelte';
  import { Camera, Pin, Plus, Save, Trash2, X } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { session } from '../stores';
  import Icon from '../components/Icon.svelte';

  let {
    news = null,
    onclose,
    onsaved
  }: {
    news?: any;
    onclose: () => void;
    onsaved: () => void;
  } = $props();

  const initial = untrack(() => news);
  const isEdit = !!initial;

  let title = $state(initial?.title || '');
  let category = $state(initial?.category || 'announcement');
  let body = $state(initial?.body || '');
  let imageUrl = $state(initial?.image_url || initial?.attachment_url || '');
  let pinned = $state(!!initial?.pinned);

  let fileInput: HTMLInputElement | undefined;
  let uploading = $state(false);
  let saving = $state(false);
  let error = $state('');

  const bodyRemaining = $derived(2000 - (body?.length || 0));

  const categories = [
    { id: 'announcement', label: 'إعلان رسمي' },
    { id: 'congratulation', label: 'تهنئة وتبريكات' },
    { id: 'alert', label: 'تنبيه مهم' },
    { id: 'general', label: 'عام' }
  ];

  async function handleImageSelect(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      error = 'يرجى اختيار ملف صورة صالح';
      return;
    }

    if (file.size > 2 * 1024 * 1024) {
      error = 'الحد الأقصى لحجم الصورة هو 2 ميغابايت';
      return;
    }

    uploading = true;
    error = '';
    try {
      const ext = file.name.split('.').pop() || 'jpg';
      const path = `${Date.now()}-${Math.random().toString(36).substring(2, 8)}.${ext}`;

      const { error: upErr } = await supabase.storage
        .from('news')
        .upload(path, file, { contentType: file.type, upsert: true });

      if (upErr) throw upErr;

      const { data } = supabase.storage.from('news').getPublicUrl(path);
      imageUrl = data.publicUrl;
    } catch (err: any) {
      error = err.message || 'تعذّر رفع الصورة';
    } finally {
      uploading = false;
    }
  }

  async function handleSubmit(e: Event) {
    e.preventDefault();
    if (!title.trim() || !body.trim()) return;

    saving = true;
    error = '';

    try {
      const user = $session?.user;
      const payload: any = {
        title: title.trim(),
        category,
        body: body.trim(),
        image_url: imageUrl || null,
        attachment_url: imageUrl || null,
        pinned
      };

      if (isEdit) {
        payload.updated_at = new Date().toISOString();
        const { error: err } = await supabase
          .from('news')
          .update(payload)
          .eq('id', initial.id);
        if (err) throw err;
      } else {
        payload.author_id = user?.id;
        payload.created_by = user?.id;
        payload.published_at = new Date().toISOString();
        const { error: err } = await supabase
          .from('news')
          .insert(payload);
        if (err) throw err;
      }

      onsaved();
    } catch (err: any) {
      error = err.message || 'تعذّر حفظ الخبر';
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
      <span>{isEdit ? 'تعديل الخبر' : 'إضافة خبر أو إعلان جديد'}</span>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق"><Icon icon={X} /></button>
    </div>

    <form class="u-modal-body" onsubmit={handleSubmit}>
      {#if error}<div class="u-alert err">{error}</div>{/if}

      <div class="u-field">
        <label for="nf-title" class="u-field-label">عنوان الخبر *</label>
        <input
          id="nf-title"
          class="u-input"
          bind:value={title}
          required
          maxlength="100"
          placeholder="مثال: موعد انطلاق مسابقة تواق السنوية"
        />
      </div>

      <div class="u-field">
        <label for="nf-category" class="u-field-label">التصنيف *</label>
        <select id="nf-category" class="u-input u-select" bind:value={category}>
          {#each categories as c}
            <option value={c.id}>{c.label}</option>
          {/each}
        </select>
      </div>

      <div class="u-field">
        <div class="field-label-row">
          <label for="nf-body" class="u-field-label">نص الخبر *</label>
          <span class="char-counter" class:warn={bodyRemaining < 100}>{bodyRemaining} حرف متبقٍ</span>
        </div>
        <textarea
          id="nf-body"
          class="u-input u-textarea news-textarea"
          bind:value={body}
          required
          maxlength="2000"
          rows="6"
          placeholder="اكتب تفاصيل الخبر هنا…"
        ></textarea>
      </div>

      <!-- Cover Image -->
      <div class="u-field">
        <span class="u-field-label">صورة الغلاف (اختياري)</span>
        <input
          type="file"
          accept="image/*"
          bind:this={fileInput}
          onchange={handleImageSelect}
          class="u-sr-only"
        />

        {#if imageUrl}
          <div class="image-preview-wrap">
            <img src={imageUrl} alt="غلاف الخبر" class="cover-preview" />
            <button
              type="button"
              class="u-btn-icon danger-btn remove-img-btn"
              onclick={() => (imageUrl = '')}
              aria-label="حذف الصورة"
            >
              <Icon icon={Trash2} size={15} />
            </button>
          </div>
        {:else}
          <button
            type="button"
            class="u-btn u-btn-ghost sm upload-btn"
            disabled={uploading}
            onclick={() => fileInput?.click()}
          >
            <Icon icon={Camera} size={15} />
            <span>{uploading ? 'جارٍ الرفع…' : 'رفع صورة غلاف'}</span>
          </button>
          <span class="u-field-hint">بحد أقصى 2 ميغابايت (PNG, JPG, WebP)</span>
        {/if}
      </div>

      <!-- Pinned Toggle -->
      <div class="pinned-row">
        <label class="pinned-label">
          <input type="checkbox" bind:checked={pinned} class="checkbox-input" />
          <span class="pinned-text">
            <Icon icon={Pin} size={15} />
            <span>تثبيت الخبر في أعلى الصفحة الرئيسية</span>
          </span>
        </label>
      </div>
    </form>

    <div class="u-modal-footer">
      <button type="button" class="u-btn u-btn-ghost" onclick={onclose}>إلغاء</button>
      <button
        type="submit"
        class="u-btn u-btn-primary"
        disabled={saving || uploading || !title.trim() || !body.trim()}
        onclick={handleSubmit}
      >
        <Icon icon={isEdit ? Save : Plus} size={15} />
        <span>{saving ? 'جارٍ الحفظ…' : isEdit ? 'حفظ التعديلات' : 'نشر الخبر'}</span>
      </button>
    </div>
  </div>
</div>

<style>
  .field-label-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .char-counter {
    font-size: var(--fs-tiny);
    color: var(--ink3);
    font-family: var(--font-num);
  }
  .char-counter.warn {
    color: var(--warn);
  }
  .news-textarea {
    min-height: 120px;
    line-height: var(--lh-base);
  }
  .image-preview-wrap {
    position: relative;
    border-radius: var(--r-md);
    overflow: hidden;
    max-height: 180px;
    border: 1px solid var(--line);
    margin-top: var(--sp-05);
  }
  .cover-preview {
    width: 100%;
    height: 160px;
    object-fit: cover;
    display: block;
  }
  .remove-img-btn {
    position: absolute;
    top: var(--sp-1);
    left: var(--sp-1);
    background: var(--card);
    box-shadow: var(--shadow);
  }
  .upload-btn {
    width: fit-content;
  }
  .pinned-row {
    margin-top: var(--sp-2);
    padding: var(--sp-2);
    background: var(--muted-bg);
    border-radius: var(--r-md);
    border: 1px solid var(--line);
  }
  .pinned-label {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    cursor: pointer;
  }
  .checkbox-input {
    width: 18px;
    height: 18px;
    accent-color: var(--brand);
    cursor: pointer;
  }
  .pinned-text {
    display: inline-flex;
    align-items: center;
    gap: var(--sp-05);
    font: var(--fw-semi) var(--fs-sm) var(--font-sans);
    color: var(--ink);
  }
  .danger-btn:hover {
    background: var(--bad-soft);
    color: var(--bad);
    border-color: var(--bad-soft);
  }
</style>
