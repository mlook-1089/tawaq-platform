<script lang="ts">
  import { onMount } from 'svelte';
  import {
    BarChart3,
    CalendarDays,
    Lightbulb,
    Megaphone,
    UserCheck,
    Users,
    Wallet,
    X
  } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { profile, roles, route } from '../stores';
  import { fmtDate, fmtTime, hijriDate, EVENT_TYPES, timeAgo } from '../utils';
  import Icon from '../components/Icon.svelte';
  import EmptyIllustrations from '../components/EmptyIllustrations.svelte';

  let nextEvent = $state<any>(null);
  let upcomingEvents = $state<any[]>([]);
  let latestNews = $state<any[]>([]);
  let latestPinnedNews = $state<any>(null);
  let dismissedPinned = $state(false);
  let loading = $state(true);
  let countdown = $state({ d: 0, h: 0, m: 0, pct: 0 });
  let timer: ReturnType<typeof setInterval> | undefined;

  const canSeeReports = $derived(
    $roles.includes('super_admin') ||
    $roles.some(r => r.startsWith('mod_'))
  );

  const greg = $derived(
    new Intl.DateTimeFormat('ar', { weekday: 'long', day: 'numeric', month: 'long' })
      .format(new Date())
  );
  const hijri = $derived(hijriDate(new Date().toISOString()));
  const firstName = $derived(($profile?.full_name || 'عضو').split(' ')[0]);

  onMount(() => {
    let cancelled = false;
    void (async () => {
      const [{ data: evData }, { data: newsData }, { data: pinnedData }] = await Promise.all([
        supabase
          .from('events')
          .select('id,type,title,start_datetime,end_datetime,location_name,color_tag')
          .is('deleted_at', null)
          .gte('start_datetime', new Date().toISOString())
          .order('start_datetime', { ascending: true })
          .limit(5),
        supabase
          .from('news')
          .select('id,title,category,published_at')
          .is('deleted_at', null)
          .order('published_at', { ascending: false })
          .limit(3),
        supabase
          .from('news')
          .select('id,title,category')
          .eq('pinned', true)
          .is('deleted_at', null)
          .order('published_at', { ascending: false })
          .limit(1)
      ]);

      if (cancelled) return;
      upcomingEvents = evData || [];
      nextEvent = upcomingEvents[0] || null;
      latestNews = newsData || [];
      latestPinnedNews = pinnedData?.[0] || null;
      loading = false;

      if (nextEvent) {
        const target = new Date(nextEvent.start_datetime).getTime();
        const createdAt = Date.now();
        const total = target - createdAt;
        const tick = () => {
          const diff = Math.max(0, target - Date.now());
          const d = Math.floor(diff / 86400000);
          const h = Math.floor((diff % 86400000) / 3600000);
          const m = Math.floor((diff % 3600000) / 60000);
          const pct = total > 0 ? Math.max(0, Math.min(100, 100 - (diff / total) * 100)) : 100;
          countdown = { d, h, m, pct };
        };
        tick();
        timer = setInterval(tick, 30000);
      }
    })();

    return () => {
      cancelled = true;
      if (timer) clearInterval(timer);
    };
  });

  const newsCatLabels: Record<string, { label: string; pill: string }> = {
    announcement: { label: 'إعلان', pill: 'brand' },
    congratulation: { label: 'تهنئة', pill: 'gold' },
    alert: { label: 'تنبيه', pill: 'warn' },
    general: { label: 'عام', pill: 'info' }
  };

  const eventPill: Record<string, string> = {
    weekly: 'brand', sport: 'gold', cultural: 'info',
    competition: 'warn', event: 'brand', hospitality: 'gold'
  };

  function countdownText() {
    if (countdown.d > 0) return `خلال ${countdown.d} يوم و${countdown.h} ساعة`;
    if (countdown.h > 0) return `خلال ${countdown.h} ساعة و${countdown.m} دقيقة`;
    return `خلال ${countdown.m} دقيقة`;
  }
</script>

<div class="u-page">
  <div class="u-top">
    <div>
      <div class="u-sub">{greg}{hijri ? ' · ' + hijri : ''}</div>
      <h1>أهلاً، {firstName}</h1>
    </div>
  </div>

  {#if latestPinnedNews && !dismissedPinned}
    <div class="u-note gold pinned-strip">
      <button class="pinned-main" onclick={() => route.set('news')}>
        <Icon icon={Megaphone} size={15} />
        <span>{latestPinnedNews.title}</span>
      </button>
      <button class="pinned-close" onclick={() => (dismissedPinned = true)} aria-label="إغلاق">
        <Icon icon={X} size={14} />
      </button>
    </div>
  {/if}

  {#if loading}
    <div class="u-skel hero-skel"></div>
  {:else if nextEvent}
    <article class="u-hero">
      <div class="l">الفعالية القادمة · {EVENT_TYPES[nextEvent.type]?.label || nextEvent.type}</div>
      <div class="big">{nextEvent.title}</div>
      <div class="u-bar"><i style="width: {countdown.pct}%"></i></div>
      <div class="meta">
        <span>{fmtDate(nextEvent.start_datetime)} · {fmtTime(nextEvent.start_datetime)}{nextEvent.location_name ? ' · ' + nextEvent.location_name : ''}</span>
        <span>{countdownText()}</span>
      </div>
    </article>
  {:else}
    <div class="u-empty">
      <EmptyIllustrations kind="calendar" />
      <h3>لا توجد فعاليات مجدولة</h3>
    </div>
  {/if}

  <div class="u-grid2">
    <button class="u-btn u-btn-p" style="height:52px" onclick={() => route.set('events')}>
      <Icon icon={CalendarDays} size={18} /> جدول الفعاليات
    </button>
    <button class="u-btn u-btn-s" style="height:52px" onclick={() => route.set('attendance')}>
      <Icon icon={UserCheck} size={18} /> رصد الحضور
    </button>
  </div>

  {#if upcomingEvents.length > 1}
    <div class="u-card">
      <div class="u-card-h">
        <h2>قادمة قريباً</h2>
        <button class="u-link" onclick={() => route.set('events')}>الكل</button>
      </div>
      <div class="u-list">
        {#each upcomingEvents.slice(1, 4) as e (e.id)}
          <div class="u-item tap" onclick={() => route.set('events')}
            onkeydown={(ev) => ev.key === 'Enter' && route.set('events')}
            tabindex="0" role="button">
            <div class="u-rank">{new Date(e.start_datetime).getDate()}</div>
            <div class="u-grow">
              <div class="u-name">{e.title}</div>
              <div class="u-muted">{fmtTime(e.start_datetime)}{e.location_name ? ' · ' + e.location_name : ''}</div>
            </div>
            <span class="u-pill {eventPill[e.type] || 'brand'}">{EVENT_TYPES[e.type]?.label || e.type}</span>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  {#if latestNews.length}
    <div class="u-card">
      <div class="u-card-h">
        <h2>آخر الأخبار</h2>
        <button class="u-link" onclick={() => route.set('news')}>الكل</button>
      </div>
      <div class="u-list">
        {#each latestNews as n (n.id)}
          <div class="u-item tap" onclick={() => route.set('news')}
            onkeydown={(ev) => ev.key === 'Enter' && route.set('news')}
            tabindex="0" role="button">
            <div class="u-grow">
              <div class="u-name">{n.title}</div>
              <div class="u-muted">{timeAgo(n.published_at)}</div>
            </div>
            <span class="u-pill {newsCatLabels[n.category]?.pill || 'info'}">
              {newsCatLabels[n.category]?.label || n.category}
            </span>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  <div class="u-card">
    <div class="u-card-h"><h2>اختصارات</h2></div>
    <div class="u-grid2">
      <button class="u-btn u-btn-g" onclick={() => route.set('hosting')}>
        <Icon icon={Users} size={17} /> المعازيب
      </button>
      <button class="u-btn u-btn-g" onclick={() => route.set('members')}>
        <Icon icon={Users} size={17} /> الأعضاء
      </button>
      <button class="u-btn u-btn-g" onclick={() => route.set('suggestions')}>
        <Icon icon={Lightbulb} size={17} /> اقتراحاتنا
      </button>
      <button class="u-btn u-btn-g" onclick={() => route.set('finance')}>
        <Icon icon={Wallet} size={17} /> المالية
      </button>
      {#if canSeeReports}
        <button class="u-btn u-btn-g" onclick={() => route.set('reports')}>
          <Icon icon={BarChart3} size={17} /> التقارير
        </button>
      {/if}
    </div>
  </div>
</div>

<style>
  .pinned-strip {
    display: flex;
    padding: 0;
    overflow: hidden;
    align-items: stretch;
  }
  .pinned-main {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px 14px;
    background: transparent;
    border: 0;
    color: inherit;
    font: 600 12.5px var(--font-sans);
    cursor: pointer;
    text-align: start;
  }
  .pinned-main span {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .pinned-close {
    width: 40px;
    background: transparent;
    border: 0;
    color: inherit;
    cursor: pointer;
    display: grid;
    place-items: center;
    border-inline-start: 1px solid rgba(185, 154, 94, 0.3);
  }
  .pinned-close:hover { background: rgba(185, 154, 94, 0.15); }

  .hero-skel {
    height: 148px;
    border-radius: 20px;
    margin-bottom: 12px;
  }
</style>
