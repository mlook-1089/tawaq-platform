<script lang="ts">
  import { onMount } from 'svelte';
  import {
    Check,
    CheckCircle2,
    DollarSign,
    ExternalLink,
    FileText,
    User,
    X,
    XCircle
  } from 'lucide-svelte';
  import { supabase } from '../../supabase';
  import { session, canManageFinance } from '../../stores';
  import { fmtCurrency, fmtDate } from '../../utils';
  import { confirmDialog, toastErr, toastOk } from '../../toast';
  import Icon from '../../components/Icon.svelte';
  import Avatar from '../../components/Avatar.svelte';
  import CommentThread from '../../components/CommentThread.svelte';

  let {
    claim,
    onclose,
    onupdated
  }: {
    claim: any;
    onclose: () => void;
    onupdated: () => void;
  } = $props();

  const user = $derived($session?.user);
  let receiptSignedUrl = $state('');
  let loadingReceipt = $state(false);
  let decisionNote = $state('');
  let busy = $state(false);
  let error = $state('');

  const statusConfig: Record<string, { label: string; pill: string }> = {
    pending:  { label: 'قيد المراجعة', pill: 'warn' },
    approved: { label: 'معتمدة',      pill: 'brand' },
    rejected: { label: 'مرفوضة',      pill: 'bad' },
    paid:     { label: 'تم الصرف',     pill: 'ok' }
  };

  const isImgReceipt = $derived.by(() => {
    if (!claim.receipt_url) return false;
    const l = claim.receipt_url.toLowerCase();
    return l.endsWith('.jpg') || l.endsWith('.jpeg') || l.endsWith('.png') || l.endsWith('.webp');
  });

  onMount(() => {
    if (claim.receipt_url) {
      loadingReceipt = true;
      void (async () => {
        try {
          const { data, error: err } = await supabase.storage
            .from('receipts')
            .createSignedUrl(claim.receipt_url, 3600);
          if (err) throw err;
          receiptSignedUrl = data?.signedUrl || '';
        } catch {
          // ignore
        } finally {
          loadingReceipt = false;
        }
      })();
    }
  });

  async function resolveClaim(newStatus: 'approved' | 'rejected' | 'paid') {
    const actionLabel = newStatus === 'approved' ? 'اعتماد' : newStatus === 'rejected' ? 'رفض' : 'تسجيل الصرف';
    const ok = await confirmDialog({
      title: `${actionLabel} المطالبة`,
      message: `هل أنت متأكد من ${actionLabel} هذه المطالبة؟`,
      confirmLabel: actionLabel,
      danger: newStatus === 'rejected'
    });
    if (!ok) return;

    busy = true;
    error = '';
    try {
      const updates: any = {
        status: newStatus,
        decided_by: user?.id,
        decided_at: new Date().toISOString()
      };
      if (decisionNote.trim()) {
        updates.decision_note = decisionNote.trim();
      }
      if (newStatus === 'paid') {
        updates.paid_at = new Date().toISOString();
      }

      const { error: err } = await supabase
        .from('expense_claims')
        .update(updates)
        .eq('id', claim.id);

      if (err) throw err;

      claim.status = newStatus;
      onupdated();
    } catch (e: any) {
      error = e.message || 'تعذّر تحديث المطالبة';
    } finally {
      busy = false;
    }
  }
</script>

<div class="u-modal" onclick={onclose} onkeydown={(e) => e.key === 'Escape' && onclose()} role="presentation">
  <div class="u-modal-scrim"></div>
  <div class="u-modal-box wide" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
    <div class="u-sheet-handle"></div>
    <div class="u-modal-header">
      <div class="header-status-row">
        <span>تفاصيل مطالبة الصرف</span>
        <span class="u-pill {statusConfig[claim.status]?.pill || ''}">
          {statusConfig[claim.status]?.label || claim.status}
        </span>
      </div>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق"><Icon icon={X} /></button>
    </div>

    <div class="u-modal-body">
      {#if error}<div class="u-alert err">{error}</div>{/if}

      <div class="claim-head-card">
        <div class="claim-amount-box">
          <span class="lbl">المبلغ المطالب به</span>
          <span class="num tab-num">{fmtCurrency(claim.amount)}</span>
        </div>
        <h2 class="claim-title">{claim.title}</h2>
      </div>

      <div class="claimant-row">
        <div class="user-info-cell">
          <Avatar url={claim.claimant?.avatar_url} name={claim.claimant?.full_name || 'ع'} size="sm" circle={true} />
          <span>المطالب: <b>{claim.claimant?.full_name || 'عضو'}</b></span>
        </div>
        <span class="date-lbl">{fmtDate(claim.created_at)}</span>
      </div>

      {#if claim.description}
        <div class="section-block">
          <div class="section-lbl">التفاصيل والوصف</div>
          <p class="desc-text">{claim.description}</p>
        </div>
      {/if}

      <!-- Receipt Viewer -->
      {#if claim.receipt_url}
        <div class="section-block">
          <div class="section-lbl">الإيصال المرفق</div>
          {#if loadingReceipt}
            <div class="u-skel receipt-skel"></div>
          {:else if receiptSignedUrl}
            {#if isImgReceipt}
              <div class="receipt-img-wrap">
                <img src={receiptSignedUrl} alt="إيصال الشراء" class="receipt-img" />
              </div>
            {/if}
            <a
              href={receiptSignedUrl}
              target="_blank"
              rel="noopener noreferrer"
              class="u-btn u-btn-ghost sm receipt-link-btn"
            >
              <Icon icon={ExternalLink} size={15} />
              <span>فتح الإيصال بالحجم الكامل</span>
            </a>
          {:else}
            <div class="u-alert warn">تعذّر تحميل رابط الإيصال.</div>
          {/if}
        </div>
      {/if}

      <!-- Decision History -->
      {#if claim.decided_at}
        <div class="decision-history-box">
          <div class="decision-title">قرار الإدارة:</div>
          <div class="decision-body">
            <span>الحالة: <b>{statusConfig[claim.status]?.label}</b></span>
            {#if claim.decision_note}
              <p class="decision-note-p">"{claim.decision_note}"</p>
            {/if}
          </div>
        </div>
      {/if}

      <!-- Admin Decision Actions -->
      {#if $canManageFinance && (claim.status === 'pending' || claim.status === 'approved')}
        <div class="admin-decision-panel">
          <div class="decision-panel-head">إجراءات المراجعة والاعتماد:</div>

          <div class="u-field">
            <label for="cd-note" class="u-field-label">ملاحظات القرار (اختياري)</label>
            <input
              id="cd-note"
              class="u-input"
              bind:value={decisionNote}
              placeholder="سبب الاعتماد أو سبب الرفض…"
            />
          </div>

          <div class="decision-btns-row">
            {#if claim.status === 'pending'}
              <button
                class="u-btn u-btn-primary sm"
                disabled={busy}
                onclick={() => resolveClaim('approved')}
              >
                <Icon icon={Check} size={15} />
                <span>اعتماد المطالبة</span>
              </button>
              <button
                class="u-btn u-btn-danger sm"
                disabled={busy}
                onclick={() => resolveClaim('rejected')}
              >
                <Icon icon={XCircle} size={15} />
                <span>رفض المطالبة</span>
              </button>
            {/if}

            {#if claim.status === 'approved'}
              <button
                class="u-btn u-btn-success sm"
                disabled={busy}
                onclick={() => resolveClaim('paid')}
              >
                <Icon icon={CheckCircle2} size={15} />
                <span>تسجيل أنه تم الصرف</span>
              </button>
            {/if}
          </div>
        </div>
      {/if}

      <CommentThread entity_type="claim" entity_id={claim.id} />
    </div>

    <div class="u-modal-footer">
      <button type="button" class="u-btn u-btn-ghost" onclick={onclose}>إغلاق</button>
    </div>
  </div>
</div>

<style>
  .header-status-row {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
  }
  .claim-head-card {
    background: var(--muted-bg);
    border: 1px solid var(--line);
    border-radius: var(--r-md);
    padding: var(--sp-3);
    margin-bottom: var(--sp-2);
  }
  .claim-amount-box {
    display: flex;
    flex-direction: column;
    margin-bottom: var(--sp-1);
  }
  .claim-amount-box .lbl {
    font-size: var(--fs-xs);
    color: var(--ink3);
  }
  .claim-amount-box .num {
    font: var(--fw-bold) var(--fs-2xl) var(--font-num);
    color: var(--brand);
  }
  .claim-title {
    margin: 0;
    font: var(--fw-bold) var(--fs-md) var(--font-sans);
    color: var(--ink);
  }
  .claimant-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-bottom: var(--sp-2);
    border-bottom: 1px solid var(--line);
    margin-bottom: var(--sp-2);
  }
  .user-info-cell {
    display: inline-flex;
    align-items: center;
    gap: var(--sp-1);
    font-size: var(--fs-sm);
    color: var(--ink2);
  }
  .date-lbl {
    font-size: var(--fs-xs);
    color: var(--ink3);
  }
  .section-block {
    margin-bottom: var(--sp-3);
  }
  .section-lbl {
    font: var(--fw-bold) var(--fs-xs) var(--font-sans);
    color: var(--ink3);
    text-transform: uppercase;
    letter-spacing: var(--tracking-wide);
    margin-bottom: var(--sp-05);
  }
  .desc-text {
    margin: 0;
    font-size: var(--fs-sm);
    color: var(--ink2);
    line-height: var(--lh-base);
  }
  .receipt-img-wrap {
    max-height: 240px;
    border-radius: var(--r-md);
    overflow: hidden;
    border: 1px solid var(--line);
    margin-bottom: var(--sp-1);
  }
  .receipt-img {
    width: 100%;
    height: 100%;
    object-fit: contain;
    background: var(--muted-bg);
  }
  .receipt-link-btn {
    width: fit-content;
  }
  .receipt-skel {
    height: 100px;
    border-radius: var(--r-md);
  }
  .decision-history-box {
    background: var(--muted-bg);
    border: 1px solid var(--line);
    border-radius: var(--r-md);
    padding: var(--sp-2);
    margin-bottom: var(--sp-2);
    font-size: var(--fs-sm);
  }
  .decision-title {
    font-weight: var(--fw-bold);
    color: var(--ink);
    margin-bottom: 4px;
  }
  .decision-note-p {
    margin: var(--sp-05) 0 0;
    color: var(--ink2);
    font-style: italic;
  }
  .admin-decision-panel {
    border: 1px dashed var(--brand);
    border-radius: var(--r-md);
    padding: var(--sp-3);
    background: var(--brand-soft);
    margin-top: var(--sp-2);
  }
  .decision-panel-head {
    font: var(--fw-bold) var(--fs-sm) var(--font-sans);
    color: var(--brand-ink);
    margin-bottom: var(--sp-2);
  }
  .decision-btns-row {
    display: flex;
    gap: var(--sp-1);
    flex-wrap: wrap;
    margin-top: var(--sp-2);
  }
  .tab-num {
    font-variant-numeric: tabular-nums;
  }
</style>
