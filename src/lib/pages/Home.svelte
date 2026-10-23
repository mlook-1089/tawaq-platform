<script lang="ts">
  import { onMount } from 'svelte';
  import { BarChart3, CalendarDays, ChevronLeft, Clock, Contact, House, MapPin, UserCheck, Users } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { profile, roles, route } from '../stores';
  import { fmtDate, fmtTime, hijriDate, EVENT_TYPES } from '../utils';
  import PageHead from '../components/PageHead.svelte';
  import Icon from '../components/Icon.svelte';
  import EmptyIllustrations from '../components/EmptyIllustrations.svelte';

  let nextEvent = $state<any>(null);
  let loading = $state(true);
  let countdown = $state({ d: 0, h: 0, m: 0 });
  let timer: ReturnType<typeof setInterval> | undefined;

  const canSeeReports = $derived(
    $roles.includes('super_admin') ||
    $roles.some(r => r.startsWith('mod_'))
  );

  onMount(() => {
    let cancelled = false;
    void (async () => {
      const { data } = await supabase
        .from('events')
        .select('id,type,title,start_datetime,end_datetime,location_name,color_tag')
        .is('deleted_at', null)
        .gte('start_datetime', new Date().toISOString())
        .order('start_datetime', { ascending: true })
        .limit(1);
      if (cancelled) return;
      nextEvent = data?.[0] || null;
      loading = false;

      if (nextEvent) {
        const target = new Date(nextEvent.start_datetime).getTime();
        const tick = () => {
          const diff = Math.max(0, target - Date.now());
          countdown = {
            d: Math.floor(diff / 86400000),
            h: Math.floor(diff % 86400000 / 3600000),
            m: Math.floor(diff % 3600000 / 60000)
          };
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

  const firstName = $derived(($profile?.full_name || 'عضو').split(' ')[0]);
</script>

<PageHead icon={House} title={`أهلاً، ${firstName}`} subtitle="ملخص نشاط المجموعة وما هو قادم" />

{#if loading}
  <div class="u-skel u-skel-card hero-skeleton"></div>
{:else if nextEvent}
  <article class="u-hero next-event">
    <div class="hero-label">الفعالية القادمة</div>
    <h2>{nextEvent.title}</h2>
    <div class="event-meta">
      <span><Icon icon={Clock} size={15} /> {fmtDate(nextEvent.start_datetime)} · {fmtTime(nextEvent.start_datetime)} <span class="hijri">({hijriDate(nextEvent.start_datetime)})</span></span>
      {#if nextEvent.location_name}<span><Icon icon={MapPin} size={15} /> {nextEvent.location_name}</span>{/if}
    </div>
    <div class="countdown num" aria-label="العد التنازلي">خلال {countdown.d} يوم، {countdown.h} ساعة</div>
    <span class="event-type"><span class="type-dot"></span>{EVENT_TYPES[nextEvent.type]?.label || nextEvent.type}</span>
  </article>
{:else}
  <div class="u-empty">
    <EmptyIllustrations kind="calendar" />
    <h3>لا توجد فعالية مجدولة</h3>
    <p>سيظهر هنا كل جديد.</p>
  </div>
{/if}

<section class="u-card quick-card">
  <div class="u-card-h">وصول سريع</div>
  <div class="quick-grid">
    <button class="quick-action" onclick={() => route.set('events')}>
      <span class="quick-icon"><Icon icon={CalendarDays} size={19} /></span>
      <span>الفعاليات</span>
      <Icon icon={ChevronLeft} size={15} />
    </button>
    <button class="quick-action" onclick={() => route.set('hosting')}>
      <span class="quick-icon"><Icon icon={Users} size={19} /></span>
      <span>المعازيب</span>
      <Icon icon={ChevronLeft} size={15} />
    </button>
    <button class="quick-action" onclick={() => route.set('attendance')}>
      <span class="quick-icon"><Icon icon={UserCheck} size={19} /></span>
      <span>الحضور</span>
      <Icon icon={ChevronLeft} size={15} />
    </button>
    <button class="quick-action" onclick={() => route.set('members')}>
      <span class="quick-icon"><Icon icon={Contact} size={19} /></span>
      <span>دليل الأعضاء</span>
      <Icon icon={ChevronLeft} size={15} />
    </button>
  </div>
</section>

{#if canSeeReports}
  <button class="u-card interactive admin-card" onclick={() => route.set('reports')}>
    <span class="quick-icon"><Icon icon={BarChart3} size={19} /></span>
    <div class="admin-text">
      <div class="admin-title">التقارير والإحصائيات</div>
      <div class="admin-sub">نسب الحضور وأداء الفعاليات والاستضافة</div>
    </div>
    <Icon icon={ChevronLeft} size={17} />
  </button>
{/if}

<style>
  .hero-skeleton { min-height: calc(var(--sp-8) * 3); }
  .next-event { position: relative; display: flex; flex-direction: column; gap: var(--sp-2); }
  .hero-label {
    color: var(--ink3);
    font: var(--fw-semi) var(--fs-tiny) var(--font-sans);
    letter-spacing: var(--tracking-wide);
    text-transform: uppercase;
  }
  .next-event h2 { margin: 0; font: var(--fw-bold) var(--fs-2xl)/1.3 var(--font-sans); color: var(--ink); }
  .event-meta { display: flex; flex-wrap: wrap; gap: var(--sp-2); color: var(--ink2); font-size: var(--fs-sm); }
  .event-meta span { display: inline-flex; align-items: center; gap: var(--sp-05); }
  .hijri { color: var(--ink3); font-size: var(--fs-xs); }
  .countdown { color: var(--brand-ink); font: var(--fw-semi) var(--fs-sm) var(--font-num); }
  .event-type { display: inline-flex; align-items: center; gap: var(--sp-1); color: var(--ink3); font-size: var(--fs-xs); }
  .type-dot { width: calc(var(--sp-1) - 2px); height: calc(var(--sp-1) - 2px); border-radius: var(--r-pill); background: var(--brand); }

  .quick-card { display: flex; flex-direction: column; gap: var(--sp-2); }
  .quick-grid { display: grid; gap: var(--sp-1); }
  .quick-action {
    display: grid;
    grid-template-columns: auto 1fr auto;
    align-items: center;
    gap: var(--sp-2);
    min-height: var(--touch);
    padding: var(--sp-1) var(--sp-2);
    border: 1px solid var(--line);
    border-radius: var(--r-xs);
    background: transparent;
    color: var(--ink);
    text-align: start;
    font: var(--fw-semi) var(--fs-sm) var(--font-sans);
  }
  .quick-action:hover { background: var(--muted-bg); border-color: var(--line2); }
  .quick-icon { width: var(--sp-6); height: var(--sp-6); display: grid; place-items: center; color: var(--brand); background: var(--brand-soft); border-radius: var(--r-xs); }

  .admin-card { display: flex; align-items: center; gap: var(--sp-2); text-align: start; width: 100%; color: var(--ink2); }
  .admin-text { flex: 1; min-width: 0; }
  .admin-title { font: var(--fw-bold) var(--fs-base) var(--font-sans); color: var(--ink); }
  .admin-sub { font-size: var(--fs-xs); color: var(--ink3); margin-top: var(--sp-05); }
</style>
