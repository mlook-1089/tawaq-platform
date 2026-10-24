<script lang="ts">
  import { Calendar, Clock, Edit3, Megaphone, Pin, Trash2, User, X } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { canWriteNews } from '../stores';
  import { fmtDate, hijriDate } from '../utils';
  import { confirmDialog, toastErr, toastOk } from '../toast';
  import Icon from '../components/Icon.svelte';
  import Avatar from '../components/Avatar.svelte';
  import CommentThread from '../components/CommentThread.svelte';

  let {
    item,
    onclose,
    onedit,
    ondeleted
  }: {
    item: any;
    onclose: () => void;
    onedit: (item: any) => void;
    ondeleted: () => void;
  } = $props();

  const categoryConfig: Record<string, { label: string; pill: string }> = {
    announcement:    { label: 'إعلان رسمي', pill: 'brand' },
    congratulation:  { label: 'تهنئة وتبريكات', pill: 'gold' },
    alert:           { label: 'تنبيه مهم', pill: 'warn' },
    general:         { label: 'عام', pill: 'info' }
  };

  const cat = $derived(categoryConfig[item.category] || { label: item.category, pill: '' });

  async function handleDelete() {
    const ok = await confirmDialog({
      title: 'حذف الخبر',
      message: `هل أنت متأكد من حذف "${item.title}"؟`,
      confirmLabel: 'حذف',
      danger: true
    });
    if (!ok) return;
    const { error: err } = await supabase
      .from('news')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', item.id);
    if (err) {
      toastErr(err.message);
    } else {
      toastOk('تم حذف الخبر');
      ondeleted();
    }
  }
</script>

<div class="u-modal" onclick={onclose} onkeydown={(e) => e.key === 'Escape' && onclose()} role="presentation">
  <div class="u-modal-scrim"></div>
  <div class="u-modal-box wide" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
    <div class="u-sheet-handle"></div>
    <div class="u-modal-header">
      <div class="header-badges">
        <span class="u-pill {cat.pill}">{cat.label}</span>
        {#if item.pinned}
          <span class="u-pill gold"><Icon icon={Pin} size={11} /> مثبت</span>
        {/if}
      </div>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق"><Icon icon={X} /></button>
    </div>

    <div class="u-modal-body">
      {#if item.image_url || item.attachment_url}
        <div class="modal-cover-wrap">
          <img src={item.image_url || item.attachment_url} alt={item.title} class="modal-cover-img" />
        </div>
      {/if}

      <h1 class="news-modal-title">{item.title}</h1>

      <div class="news-meta-row">
        {#if item.author}
          <div class="author-inline">
            <Avatar url={item.author.avatar_url} name={item.author.full_name} size="sm" circle={true} />
            <span class="author-name">{item.author.full_name}</span>
          </div>
        {/if}
        <span class="news-date">
          <Icon icon={Calendar} size={14} />
          {fmtDate(item.published_at || item.created_at)}
          {#if item.published_at || item.created_at}
            <span class="hijri-text">({hijriDate(item.published_at || item.created_at)})</span>
          {/if}
        </span>
      </div>

      <div class="news-full-body">
        {item.body}
      </div>

      <CommentThread entity_type="news" entity_id={item.id} />
    </div>

    <div class="u-modal-footer">
      {#if $canWriteNews}
        <button
          type="button"
          class="u-btn u-btn-ghost sm"
          onclick={() => onedit(item)}
        >
          <Icon icon={Edit3} size={14} />
          <span>تعديل</span>
        </button>
        <button
          type="button"
          class="u-btn u-btn-ghost sm danger-btn"
          onclick={handleDelete}
        >
          <Icon icon={Trash2} size={14} />
          <span>حذف</span>
        </button>
      {/if}
      <button type="button" class="u-btn u-btn-ghost" onclick={onclose}>إغلاق</button>
    </div>
  </div>
</div>

<style>
  .header-badges {
    display: flex;
    gap: var(--sp-05);
    align-items: center;
  }
  .modal-cover-wrap {
    border-radius: var(--r-lg);
    overflow: hidden;
    margin-bottom: var(--sp-3);
    max-height: 280px;
    border: 1px solid var(--line);
  }
  .modal-cover-img {
    width: 100%;
    height: 100%;
    max-height: 280px;
    object-fit: cover;
    display: block;
  }
  .news-modal-title {
    margin: 0 0 var(--sp-2);
    font: var(--fw-bold) var(--fs-xl)/1.3 var(--font-sans);
    color: var(--ink);
  }
  .news-meta-row {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    flex-wrap: wrap;
    color: var(--ink3);
    font-size: var(--fs-xs);
    padding-bottom: var(--sp-2);
    border-bottom: 1px solid var(--line);
    margin-bottom: var(--sp-3);
  }
  .author-inline {
    display: inline-flex;
    align-items: center;
    gap: var(--sp-05);
  }
  .author-name {
    color: var(--ink);
    font-weight: var(--fw-semi);
  }
  .news-date {
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }
  .hijri-text {
    color: var(--ink3);
  }
  .news-full-body {
    font-size: var(--fs-base);
    line-height: var(--lh-base);
    color: var(--ink);
    white-space: pre-wrap;
    word-break: break-word;
  }
  .danger-btn:hover {
    background: var(--bad-soft);
    color: var(--bad);
    border-color: var(--bad-soft);
  }
</style>
