<script lang="ts">
  import { onMount } from 'svelte';
  import {
    Calendar,
    ChevronLeft,
    Clock,
    Megaphone,
    Pin,
    Plus
  } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { canWriteNews } from '../stores';
  import { fmtDate } from '../utils';
  import PageHead from '../components/PageHead.svelte';
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
</script>

<PageHead icon={Megaphone} title="الأخبار والإعلانات" subtitle="مستجدات وإعلانات مجموعة تواق">
  {#snippet action()}
    {#if $canWriteNews}
      <button
        class="u-btn u-btn-primary sm"
        onclick={() => { editingItem = null; showForm = true; }}
      >
        <Icon icon={Plus} size={15} />
        <span>إضافة خبر</span>
      </button>
    {/if}
  {/snippet}
</PageHead>

<!-- Category Filter Chips -->
<div class="filters">
  <div class="u-chips">
    <button
      class="u-chip"
      class:on={selectedCategory === 'all'}
      onclick={() => (selectedCategory = 'all')}
    >
      الكل ({newsList.length})
    </button>
    {#each Object.entries(categories) as [k, v] (k)}
      <button
        class="u-chip"
        class:on={selectedCategory === k}
        onclick={() => (selectedCategory = k)}
      >
        {v.label}
      </button>
    {/each}
  </div>
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
    <p>سيتم نشر الأخبار والإعلانات هنا عند توفرها.</p>
  </div>
{:else}
  <div class="news-list">
    {#each filteredNews as n (n.id)}
      {@const cat = categories[n.category] || { label: n.category, pill: '' }}
      <div
        class="u-card interactive news-card"
        class:is-pinned={n.pinned}
        onclick={() => (selectedDetail = n)}
        onkeydown={(e) => e.key === 'Enter' && (selectedDetail = n)}
        tabindex="0"
        role="button"
      >
        {#if n.image_url || n.attachment_url}
          <div class="news-card-thumb">
            <img src={n.image_url || n.attachment_url} alt={n.title} loading="lazy" />
          </div>
        {/if}

        <div class="news-card-content">
          <div class="card-meta-top">
            <span class="u-pill {cat.pill}">{cat.label}</span>
            {#if n.pinned}
              <span class="u-pill gold"><Icon icon={Pin} size={11} /> مثبت</span>
            {/if}
            <span class="meta-date">
              <Icon icon={Calendar} size={12} />
              {fmtDate(n.published_at || n.created_at)}
            </span>
          </div>

          <h2 class="news-title">{n.title}</h2>

          <p class="news-excerpt">
            {n.body.length > 110 ? n.body.slice(0, 110) + '…' : n.body}
          </p>

          <div class="card-bottom">
            {#if n.author}
              <div class="author-cell">
                <Avatar url={n.author.avatar_url} name={n.author.full_name} size="sm" circle={true} />
                <span class="author-name">{n.author.full_name}</span>
              </div>
            {/if}
            <span class="read-more-link">
              <span>اقرأ المزيد</span>
              <Icon icon={ChevronLeft} size={15} />
            </span>
          </div>
        </div>
      </div>
    {/each}
  </div>
{/if}

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
  .filters {
    margin-bottom: var(--sp-3);
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
    transition: transform var(--t-fast), box-shadow var(--t-fast), border-color var(--t-fast);
  }
  .news-card.is-pinned {
    border-inline-start: 4px solid var(--gold);
  }
  .news-card-thumb {
    width: 100%;
    height: 160px;
    overflow: hidden;
    background: var(--muted-bg);
  }
  .news-card-thumb img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
  .news-card-content {
    padding: var(--sp-3);
    display: flex;
    flex-direction: column;
    gap: var(--sp-1);
    flex: 1;
  }
  .card-meta-top {
    display: flex;
    gap: var(--sp-1);
    align-items: center;
    flex-wrap: wrap;
  }
  .meta-date {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: var(--fs-tiny);
    color: var(--ink3);
    margin-inline-start: auto;
  }
  .news-title {
    margin: var(--sp-05) 0 0;
    font: var(--fw-bold) var(--fs-md)/1.3 var(--font-sans);
    color: var(--ink);
  }
  .news-excerpt {
    margin: 0;
    font-size: var(--fs-sm);
    color: var(--ink2);
    line-height: var(--lh-base);
  }
  .card-bottom {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: var(--sp-1);
    padding-top: var(--sp-1);
    border-top: 1px solid var(--line);
  }
  .author-cell {
    display: flex;
    align-items: center;
    gap: var(--sp-05);
  }
  .author-name {
    font-size: var(--fs-xs);
    color: var(--ink2);
    font-weight: var(--fw-medium);
  }
  .read-more-link {
    display: inline-flex;
    align-items: center;
    gap: 2px;
    font: var(--fw-bold) var(--fs-xs) var(--font-sans);
    color: var(--brand);
    margin-inline-start: auto;
  }
  .news-skel {
    height: 140px;
    border-radius: var(--r-xl);
  }
</style>
