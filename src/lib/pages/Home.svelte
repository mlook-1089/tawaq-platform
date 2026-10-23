<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../supabase';
  import { profile, roles, route } from '../stores';
  import { fmtDT, EVENT_TYPES } from '../utils';
  import PageHead from '../components/PageHead.svelte';

  let nextEvent = $state<any>(null);
  let loading = $state(true);
  let countdown = $state({ d: 0, h: 0, m: 0 });
  let timer: any;

  const canSeeReports = $derived(
    $roles.includes('super_admin') ||
    $roles.some(r => r.startsWith('mod_'))
  );

  onMount(async () => {
    const { data } = await supabase
      .from('events')
      .select('id,type,title,start_datetime,end_datetime,location_name,color_tag')
      .is('deleted_at', null)
      .gte('start_datetime', new Date().toISOString())
      .order('start_datetime', { ascending: true })
      .limit(1);
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

    return () => timer && clearInterval(timer);
  });

  const firstName = $derived(($profile?.full_name || 'عضو').split(' ')[0]);
</script>

<PageHead icon="🏠" title={`أهلاً، ${firstName}`} />

{#if loading}
  <div class="u-skel u-skel-card"></div>
{:else if nextEvent}
  <article class="u-hero">
    <div class="hero-head">الفعالية القادمة</div>
    <h2>{nextEvent.title}</h2>
    <p>
      {fmtDT(nextEvent.start_datetime)}
      {#if nextEvent.location_name} · 📍 {nextEvent.location_name}{/if}
    </p>
    <div class="countdown" aria-label="العد التنازلي">
      <div class="unit"><span class="n">{countdown.d}</span><span class="l">يوم</span></div>
      <div class="unit"><span class="n">{countdown.h}</span><span class="l">ساعة</span></div>
      <div class="unit"><span class="n">{countdown.m}</span><span class="l">دقيقة</span></div>
    </div>
    <span class="u-pill solid type-pill">{EVENT_TYPES[nextEvent.type]?.label || nextEvent.type}</span>
  </article>
{:else}
  <div class="u-empty">
    <div class="ic">📅</div>
    <h3>لا توجد فعالية مجدولة</h3>
    <p>سيظهر هنا كل جديد.</p>
  </div>
{/if}

{#if canSeeReports}
  <button class="u-card interactive admin-card" onclick={() => route.set('reports')}>
    <div class="admin-card-row">
      <div class="admin-ic">📊</div>
      <div class="admin-text">
        <div class="admin-title">التقارير والإحصائيات</div>
        <div class="admin-sub">نسب الحضور، أفضل الأعضاء، إحصائيات شهرية</div>
      </div>
      <div class="chevron" aria-hidden="true">←</div>
    </div>
  </button>
{/if}

<div class="u-card">
  <div class="u-card-h">🎉 أهلاً بك في منصة تواق</div>
  <p class="welcome-text">الإصدار الجديد قيد البناء التدريجي. ابدأ باستكشاف:</p>
  <ul class="feature-list">
    <li>📅 <b>الفعاليات</b> — تصفّح الجدول الكامل وأنشئ فعاليات جديدة</li>
    <li>🫖 <b>المعازيب</b> — جدول الاستضافة الأسبوعي مع التأكيد والتبديل</li>
    <li>✓ <b>الحضور</b> — تحضير ذكي بالموقع (Geofence)</li>
    <li>👤 <b>حسابي</b> — بياناتك وصلاحياتك</li>
  </ul>
</div>

<style>
  .hero-head {
    font: var(--fw-semi) var(--fs-xs) var(--font-sans);
    opacity: 0.78;
    margin-bottom: var(--sp-05);
    position: relative;
  }

  .countdown {
    display: flex;
    gap: var(--sp-1);
    justify-content: center;
    margin: var(--sp-2) 0 var(--sp-1);
    position: relative;
  }
  .unit {
    background: rgba(255,255,255,.08);
    border: 1px solid rgba(217,199,154,.3);
    border-radius: var(--r-sm);
    padding: var(--sp-1) var(--sp-05);
    min-width: 68px;
    text-align: center;
  }
  .unit .n {
    display: block;
    font: var(--fw-bold) var(--fs-2xl)/1 var(--font-num);
    font-variant-numeric: tabular-nums;
    color: var(--gold-bright);
  }
  .unit .l {
    display: block;
    font-size: var(--fs-tiny);
    opacity: 0.75;
    margin-top: var(--sp-05);
  }
  .type-pill {
    position: relative;
    background: rgba(255,255,255,.14);
    color: var(--on-brand);
  }

  .admin-card { margin-bottom: var(--sp-2); text-align: start; width: 100%; }
  .admin-card-row {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
  }
  .admin-ic {
    width: 42px; height: 42px;
    background: var(--gold-soft);
    border-radius: var(--r-md);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: var(--fs-xl);
    flex-shrink: 0;
  }
  .admin-text { flex: 1; min-width: 0; }
  .admin-title {
    font: var(--fw-bold) var(--fs-base) var(--font-sans);
    color: var(--brand);
  }
  .admin-sub {
    font: var(--fw-regular) var(--fs-xs) var(--font-sans);
    color: var(--ink3);
    margin-top: 2px;
  }
  .chevron {
    color: var(--brand);
    font: var(--fw-bold) var(--fs-lg) var(--font-sans);
    flex-shrink: 0;
  }

  .welcome-text {
    color: var(--ink2);
    font-size: var(--fs-sm);
    margin: 0 0 var(--sp-2);
  }
  .feature-list {
    list-style: none;
    padding: 0;
    margin: 0;
  }
  .feature-list li {
    padding: var(--sp-1) 0;
    font-size: var(--fs-sm);
    color: var(--ink2);
    border-bottom: 1px dashed var(--line);
    line-height: var(--lh-base);
  }
  .feature-list li:last-child { border-bottom: none; }
</style>
