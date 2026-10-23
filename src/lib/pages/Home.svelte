<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../supabase';
  import { profile } from '../stores';
  import { fmtDT, EVENT_TYPES } from '../utils';
  import PageHead from '../components/PageHead.svelte';

  let nextEvent = $state<any>(null);
  let loading = $state(true);
  let countdown = $state({ d: 0, h: 0, m: 0 });
  let timer: any;

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

<PageHead icon="🏠" title="أهلاً، {firstName}" />

{#if loading}
  <div class="skel"></div>
{:else if nextEvent}
  <div class="hero" style="background: linear-gradient(155deg, {nextEvent.color_tag || '#0E2B22'} 0%, #1A4536 100%)">
    <div class="big-hex"></div>
    <div class="sec-t">الفعالية القادمة</div>
    <h2>{nextEvent.title}</h2>
    <p class="sub">
      {fmtDT(nextEvent.start_datetime)}
      {#if nextEvent.location_name} · 📍 {nextEvent.location_name}{/if}
    </p>
    <div class="cd">
      <div class="u"><span class="n">{countdown.d}</span><span class="l">يوم</span></div>
      <div class="u"><span class="n">{countdown.h}</span><span class="l">ساعة</span></div>
      <div class="u"><span class="n">{countdown.m}</span><span class="l">دقيقة</span></div>
    </div>
    <span class="type-tag">{EVENT_TYPES[nextEvent.type]?.label || nextEvent.type}</span>
  </div>
{:else}
  <div class="card empty">
    <div class="ic">📅</div>
    <h3>لا توجد فعالية مجدولة</h3>
    <p>سيظهر هنا كل جديد.</p>
  </div>
{/if}

<div class="card welcome">
  <h3>🎉 أهلاً بك في منصة تواق</h3>
  <p>الإصدار الجديد قيد البناء التدريجي. ابدأ باستكشاف:</p>
  <ul>
    <li>📅 <b>الفعاليات</b> — تصفّح الجدول الكامل وأنشئ فعاليات جديدة (إذا كانت لديك صلاحية)</li>
    <li>🫖 <b>المعازيب</b> — جدول الاستضافة الأسبوعي (قريباً)</li>
    <li>✓ <b>الحضور</b> — QR + تحضير ذاتي بالموقع (قريباً)</li>
    <li>👤 <b>حسابي</b> — بياناتك وصلاحياتك</li>
  </ul>
</div>

<style>
  .skel { height: 180px; background: var(--muted-bg); border-radius: 20px; animation: pulse 1.4s ease-in-out infinite; }
  @keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: .5; } }

  .hero {
    color: var(--on-brand);
    border-radius: 20px;
    padding: 24px 20px;
    position: relative;
    overflow: hidden;
    box-shadow: var(--shadow-lg);
    margin-bottom: 16px;
  }
  .big-hex {
    position: absolute; top: -50px; left: -50px;
    width: 170px; height: 170px;
    background: var(--gold);
    opacity: .10;
    clip-path: polygon(25% 5%, 75% 5%, 100% 50%, 75% 95%, 25% 95%, 0 50%);
  }
  .sec-t { font-size: 12.5px; font-weight: 600; opacity: .78; margin-bottom: 6px; position: relative; }
  h2 { font-size: 20px; font-weight: 700; margin: 0 0 6px; position: relative; }
  .sub { color: var(--gold-bright); font-size: 12.5px; margin-bottom: 14px; position: relative; }

  .cd { display: flex; gap: 10px; justify-content: center; margin: 14px 0 10px; position: relative; }
  .u {
    background: rgba(255,255,255,.08);
    border: 1px solid rgba(217,199,154,.3);
    border-radius: 13px;
    padding: 10px 7px;
    min-width: 68px; text-align: center;
  }
  .n { display: block; font-size: 24px; font-weight: 700; line-height: 1; font-variant-numeric: tabular-nums; color: var(--gold-bright); }
  .l { font-size: 10.5px; opacity: .75; margin-top: 6px; display: block; }
  .type-tag {
    display: inline-block;
    background: rgba(255,255,255,.14);
    color: #fff;
    padding: 4px 11px;
    border-radius: 99px;
    font-size: 10.5px;
    font-weight: 600;
    margin-top: 4px;
    position: relative;
  }

  .card {
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: 18px;
    padding: 18px;
    box-shadow: var(--shadow);
    margin-bottom: 13px;
  }
  .empty { text-align: center; padding: 32px 18px; color: var(--ink3); }
  .empty .ic { font-size: 42px; opacity: .4; margin-bottom: 10px; }
  .empty h3 { color: var(--ink2); margin-bottom: 5px; }

  .welcome h3 { color: var(--brand); font-size: 15px; margin-bottom: 8px; }
  .welcome p { color: var(--ink2); font-size: 13px; margin-bottom: 10px; }
  .welcome ul { list-style: none; padding: 0; }
  .welcome li {
    padding: 8px 0;
    font-size: 13px;
    color: var(--ink2);
    border-bottom: 1px dashed var(--line);
  }
  .welcome li:last-child { border-bottom: none; }
</style>
