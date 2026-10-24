<script lang="ts">
  import { onMount } from 'svelte';
  import {
    Pin,
    Plus
  } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { canWriteNews } from '../stores';
  import { timeAgo } from '../utils';
  import Icon from '../components/Icon.svelte';
  import Avatar from '../components/Avatar.svelte';
  import EmptyIllustrations from '../components/EmptyIllustrations.svelte';
  import NewsForm from './NewsForm.svelte';
  import NewsDetail from './NewsDetail.svelte';

  interface NewsItem {
    id: string;
    title: string;
    body: string;
    category: string;
    image_url: string | null;
    attachment_url: string | null;
    pinned: boolean;
    published_at: string;
    created_at: string;
    author?: {
      full_name: string;
      avatar_url: string | null;
    };
  }

  let newsList = $state<NewsItem[]>([]);
  let loading = $state(true);
  let error = $state('');
  let selectedCategory = $state('all');

  // Modals state
  let showForm = $state(false);
  let editingItem = $state<NewsItem | null>(null);
  let selectedDetail = $state<NewsItem | null>(null);

  const categories: Record<string, { label: string; pill: string }> = {
    announcement:    { label: 'إعلان رسمي', pill: 'brand' },
    congratulation:  { label: 'تهنئة وتبريكات', pill: 'gold' },
    alert:           { label: 'تنبيه مهم', pill: 'warn' },
    general:         { label: 'عام', pill: 'info' }
  };

  async function loadNews() {
    loading = true;
    error = '';
    try {
      const { data, error: err } = await supabase
        .from('news')
        .select(`
          id,
          title,
          body,
          category,
          image_url,
          attachment_url,
          pinned,
          published_at,
          created_at,
          author:users!news_author_id_fkey(full_name, avatar_url)
        `)
        .is('deleted_at', null)
        .order('pinned', { ascending: false })
        .order('published_at', { ascending: false });

      if (err) {
        // Fallback without foreign key relation if name differs
        const { data: rawData, error: rawErr } = await supabase
          .from('news')
          .select('*')
          .is('deleted_at', null)
          .order('pinned', { ascending: false })
          .order('published_at', { ascending: false });
        if (rawErr) throw rawErr;
        newsList = (rawData || []) as unknown as NewsItem[];
      } else {
        newsList = (data || []) as unknown as NewsItem[];
      }
    } catch (e: any) {
      error = e.message || 'تعذّر تحميل الأخبار';
    } finally {
      loading = false;
    }
  }

  onMount(loadNews);

  const filteredNews = $derived.by(() => {
    if (selectedCategory === 'all') return newsList;
    return newsList.filter(n => n.category === selectedCategory);
  });

  const categoryCounts = $derived.by(() => {
    const c: Record<string, number> = {};
    for (const n of newsList) {
      c[n.category] = (c[n.category] || 0) + 1;
    }
    return c;
  });
</script>

<div class="u-page">
  <div class="u-top">
    <div>
      <div class="u-sub">{newsList.length} خبر وإعلان</div>
      <h1>الأخبار والإعلانات</h1>
    </div>
    {#if $canWriteNews}
      <div class="u-actions">
        <button
          class="u-btn u-btn-primary sm"
          onclick={() => { editingItem = null; showForm = true; }}
        >
          <Icon icon={Plus} size={15} /> إضافة
        </button>
      </div>
    {/if}
  </div>

  <div class="u-chips">
    <button
      class="u-chip"
      class:on={selectedCategory === 'all'}
      onclick={() => (selectedCategory = 'all')}
    >
      الكل <span class="chip-count">{newsList.length}</span>
    </button>
    {#each Object.entries(categories) as [k, v] (k)}
      <button
        class="u-chip"
        class:on={selectedCategory === k}
        onclick={() => (selectedCategory = k)}
      >
        {v.label} <span class="chip-count">{categoryCounts[k] || 0}</span>
      </button>
    {/each}
  </div>

  {#if loading}
    <div class="news-list">
      {#each Array(3) as _}
        <div class="u-skel news-skel"></div>
      {/each}
    </div>
  {:else if error}
    <div class="u-alert err">{error}</div>
  {:else if filteredNews.length === 0}
    <div class="u-empty">
      <EmptyIllustrations kind="generic" />
      <h3>لا توجد أخبار في هذا التصنيف</h3>
      <p>سيتم نشر الأخبار هنا عند توفرها.</p>
    </div>
  {:else}
    <div class="news-list">
      {#each filteredNews as n (n.id)}
        {@const cat = categories[n.category] || { label: n.category, pill: '' }}
        <div
          class="u-card news-card"
          class:is-pinned={n.pinned}
          onclick={() => (selectedDetail = n)}
          onkeydown={(e) => e.key === 'Enter' && (selectedDetail = n)}
          tabindex="0"
          role="button"
        >
          {#if n.image_url || n.attachment_url}
            <div class="news-thumb">
              <img src={n.image_url || n.attachment_url} alt={n.title} loading="lazy" />
            </div>
          {/if}

          <div class="news-body">
            <div class="news-head-row">
              <span class="u-pill {cat.pill}">{cat.label}</span>
              {#if n.pinned}
                <span class="u-pill gold"><Icon icon={Pin} size={11} /> مثبت</span>
              {/if}
              <span class="u-muted meta-date">{timeAgo(n.published_at || n.created_at)}</span>
            </div>

            <h3 class="news-title">{n.title}</h3>

            <p class="news-excerpt">
              {n.body.length > 110 ? n.body.slice(0, 110) + '…' : n.body}
            </p>

            {#if n.author}
              <div class="news-author">
                <Avatar url={n.author.avatar_url} name={n.author.full_name} size="sm" circle={true} />
                <span>{n.author.full_name}</span>
              </div>
            {/if}
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

{#if showForm}
  <NewsForm
    news={editingItem}
    onclose={() => { showForm = false; editingItem = null; }}
    onsaved={() => { showForm = false; editingItem = null; loadNews(); }}
  />
{/if}

{#if selectedDetail}
  <NewsDetail
    item={selectedDetail}
    onclose={() => (selectedDetail = null)}
    onedit={(item) => {
      selectedDetail = null;
      editingItem = item;
      showForm = true;
    }}
    ondeleted={() => {
      selectedDetail = null;
      loadNews();
    }}
  />
{/if}

<style>
  .chip-count {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 20px;
    padding: 0 6px;
    height: 18px;
    background: var(--muted-bg);
    color: var(--ink2);
    border-radius: var(--r-pill);
    font: var(--fw-bold) 10.5px var(--font-sans);
    font-variant-numeric: tabular-nums;
    margin-inline-start: 4px;
  }
  :global(.u-chip.on) .chip-count {
    background: color-mix(in oklab, var(--bg) 25%, transparent);
    color: var(--bg);
  }

  .news-list {
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
  }
  .news-card {
    display: flex;
    flex-direction: column;
    overflow: hidden;
    padding: 0;
    cursor: pointer;
    transition: box-shadow var(--t-fast), border-color var(--t-fast);
  }
  .news-card:hover {
    box-shadow: var(--shadow-md);
    border-color: var(--line2);
  }
  .news-card.is-pinned {
    border-inline-start: 4px solid var(--gold);
  }
  .news-thumb {
    width: 100%;
    height: 140px;
    overflow: hidden;
    background: var(--muted-bg);
  }
  .news-thumb img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
  .news-body {
    padding: var(--sp-2) var(--sp-3) var(--sp-3);
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .news-head-row {
    display: flex;
    gap: var(--sp-1);
    align-items: center;
    flex-wrap: wrap;
  }
  .meta-date {
    margin-inline-start: auto;
    font-size: var(--fs-tiny);
  }
  .news-title {
    margin: 2px 0 0;
    font: var(--fw-bold) var(--fs-md)/1.3 var(--font-sans);
    color: var(--ink);
  }
  .news-excerpt {
    margin: 0;
    font-size: var(--fs-sm);
    color: var(--ink2);
    line-height: var(--lh-base);
  }
  .news-author {
    display: flex;
    align-items: center;
    gap: 6px;
    margin-top: 4px;
    padding-top: var(--sp-1);
    border-top: 1px solid var(--line);
    font-size: var(--fs-xs);
    color: var(--ink2);
    font-weight: var(--fw-medium);
  }
  .news-skel {
    height: 140px;
    border-radius: var(--r-xl);
  }
</style>
