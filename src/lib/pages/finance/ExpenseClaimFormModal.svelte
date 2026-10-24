<script lang="ts">
  import { FileText, Plus, Upload, X } from 'lucide-svelte';
  import { supabase } from '../../supabase';
  import { session } from '../../stores';
  import Icon from '../../components/Icon.svelte';

  let {
    pools,
    events,
    onclose,
    onsaved
  }: {
    pools: any[];
    events: any[];
    onclose: () => void;
    onsaved: () => void;
  } = $props();

  const user = $derived($session?.user);

  let title = $state('');
  let amount = $state('');
  let description = $state('');
  let poolId = $state('');
  let eventId = $state('');
  let receiptPath = $state('');
  let receiptName = $state('');

  let fileInput: HTMLInputElement | undefined;
  let uploading = $state(false);
  let saving = $state(false);
  let error = $state('');

  async function handleFileSelect(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    if (file.size > 10 * 1024 * 1024) {
      error = 'الحد الأقصى لحجم الإيصال هو 10 ميغابايت';
      return;
    }

    const userId = user?.id;
    if (!userId) return;

    uploading = true;
    error = '';
    try {
      const ext = file.name.split('.').pop() || 'jpg';
      const cleanExt = ext.toLowerCase();
      const path = `${userId}/${Date.now()}-${Math.random().toString(36).substring(2, 6)}.${cleanExt}`;

      const { error: upErr } = await supabase.storage
        .from('receipts')
        .upload(path, file, { contentType: file.type, upsert: true });

      if (upErr) throw upErr;

      receiptPath = path;
      receiptName = file.name;
    } catch (err: any) {
      error = err.message || 'تعذّر رفع الإيصال';
    } finally {
      uploading = false;
    }
  }

  async function handleSubmit(e: Event) {
    e.preventDefault();
    if (!title.trim() || !amount) return;

    saving = true;
    error = '';

    try {
      const userId = user?.id;
      if (!userId) throw new Error('يرجى تسجيل الدخول');

      const payload = {
        claimant_user_id: userId,
        title: title.trim(),
        amount: Number(amount),
        description: description.trim() || null,
        pool_id: poolId || null,
        event_id: eventId || null,
        receipt_url: receiptPath || null,
        status: 'pending'
      };

      const { error: err } = await supabase.from('expense_claims').insert(payload);
      if (err) throw err;

      onsaved();
    } catch (err: any) {
      error = err.message || 'تعذّر إرسال المطالبة';
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
      <span>رفع مطالبة مصاريف</span>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق"><Icon icon={X} /></button>
    </div>

    <form class="u-modal-body" onsubmit={handleSubmit}>
      {#if error}<div class="u-alert err">{error}</div>{/if}

      <div class="u-field">
        <label for="ec-title" class="u-field-label">عنوان المصروف *</label>
        <input
          id="ec-title"
          class="u-input"
          bind:value={title}
          required
          placeholder="مثال: ذبيحة عشاء الأربعاء"
        />
      </div>

      <div class="u-field">
        <label for="ec-amt" class="u-field-label">المبلغ المطلوب (ر.س) *</label>
        <input
          id="ec-amt"
          type="number"
          step="0.01"
          min="1"
          class="u-input"
          bind:value={amount}
          required
          placeholder="350.00"
        />
      </div>

      <div class="form-grid-2">
        <div class="u-field">
          <label for="ec-pool" class="u-field-label">ربط بقطة (اختياري)</label>
          <select id="ec-pool" class="u-input u-select" bind:value={poolId}>
            <option value="">بدون ربط بقطة</option>
            {#each pools as p}
              <option value={p.id}>{p.title}</option>
            {/each}
          </select>
        </div>

        <div class="u-field">
          <label for="ec-event" class="u-field-label">ربط بفعالية (اختياري)</label>
          <select id="ec-event" class="u-input u-select" bind:value={eventId}>
            <option value="">بدون ربط بفعالية</option>
            {#each events as ev}
              <option value={ev.id}>{ev.title}</option>
            {/each}
          </select>
        </div>
      </div>

      <div class="u-field">
        <label for="ec-desc" class="u-field-label">الوصف والتفاصيل</label>
        <textarea
          id="ec-desc"
          class="u-input u-textarea"
          bind:value={description}
          rows="3"
          placeholder="تفاصيل المشتريات ومكان الشراء…"
        ></textarea>
      </div>

      <!-- Receipt Upload -->
      <div class="u-field">
        <span class="u-field-label">إيصال أو فاتورة الشراء</span>
        <input
          type="file"
          accept="image/*,application/pdf"
          bind:this={fileInput}
          onchange={handleFileSelect}
          class="u-sr-only"
        />

        {#if receiptPath}
          <div class="receipt-file-badge">
            <Icon icon={FileText} size={16} />
            <span class="receipt-fname">{receiptName || receiptPath}</span>
            <button
              type="button"
              class="chip-rm"
              onclick={() => { receiptPath = ''; receiptName = ''; }}
              aria-label="إزالة الإيصال"
            >
              <Icon icon={X} size={14} />
            </button>
          </div>
        {:else}
          <button
            type="button"
            class="u-btn u-btn-ghost sm upload-btn"
            disabled={uploading}
            onclick={() => fileInput?.click()}
          >
            <Icon icon={Upload} size={15} />
            <span>{uploading ? 'جارٍ الرفع…' : 'رفع ملف الفاتورة أو الإيصال'}</span>
          </button>
          <span class="u-field-hint">صورة أو ملف PDF بحد أقصى 10 ميغابايت</span>
        {/if}
      </div>
    </form>

    <div class="u-modal-footer">
      <button type="button" class="u-btn u-btn-ghost" onclick={onclose}>إلغاء</button>
      <button
        type="submit"
        class="u-btn u-btn-primary"
        disabled={saving || uploading || !title.trim() || !amount}
        onclick={handleSubmit}
      >
        <Icon icon={Plus} size={15} />
        <span>{saving ? 'جارٍ الإرسال…' : 'رفع المطالبة'}</span>
      </button>
    </div>
  </div>
</div>

<style>
  .form-grid-2 {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--sp-1);
  }
  @media (min-width: 480px) {
    .form-grid-2 {
      grid-template-columns: 1fr 1fr;
    }
  }
  .upload-btn {
    width: fit-content;
  }
  .receipt-file-badge {
    display: inline-flex;
    align-items: center;
    gap: var(--sp-1);
    padding: var(--sp-1) var(--sp-2);
    background: var(--brand-soft);
    color: var(--brand-ink);
    border-radius: var(--r-md);
    font-size: var(--fs-xs);
    width: fit-content;
  }
  .receipt-fname {
    max-width: 200px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .chip-rm {
    background: transparent;
    border: none;
    color: var(--brand-ink);
    cursor: pointer;
    display: grid;
    place-items: center;
    padding: 0;
  }
</style>
