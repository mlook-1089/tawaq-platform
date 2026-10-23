<script lang="ts">
  import { onMount } from 'svelte';
  import { AlertCircle, CalendarDays, CheckCircle2, Clock, MapPin, QrCode, ScanQrCode, Settings2, UserCheck } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { session, roles, isAdmin } from '../stores';
  import { fmtDate, fmtTime, EVENT_TYPES } from '../utils';
  import PageHead from '../components/PageHead.svelte';
  import AttendanceManage from './AttendanceManage.svelte';
  import AttendanceQR from './AttendanceQR.svelte';
  import AttendanceScan from './AttendanceScan.svelte';
  import Icon from '../components/Icon.svelte';
  import EmptyIllustrations from '../components/EmptyIllustrations.svelte';

  let events = $state<any[]>([]);
  let myAttendance = $state<Record<string, any>>({});
  let loading = $state(true);
  let busyEvent = $state<string | null>(null);
  let msg = $state<{ eventId: string; text: string; ok: boolean } | null>(null);
  let manageEventId = $state<string | null>(null);
  let qrEvent = $state<any>(null);
  let showScanner = $state(false);

  async function load() {
    loading = true;
    const now = new Date();
    const weekLater = new Date(now.getTime() + 7 * 24 * 3600 * 1000);
    const dayAgo = new Date(now.getTime() - 24 * 3600 * 1000);

    const [{ data: evts }, { data: att }] = await Promise.all([
      supabase.from('events')
        .select('id,type,title,start_datetime,end_datetime,location_name,color_tag,geofence_lat,geofence_lng,geofence_radius_m')
        .is('deleted_at', null)
        .gte('start_datetime', dayAgo.toISOString())
        .lte('start_datetime', weekLater.toISOString())
        .order('start_datetime', { ascending: true }),
      supabase.from('attendance')
        .select('event_id,status,method,marked_at,distance_from_event_m')
        .eq('user_id', $session?.user?.id || '')
    ]);

    events = evts || [];
    myAttendance = {};
    (att || []).forEach((a: any) => { myAttendance[a.event_id] = a; });
    loading = false;
  }

  onMount(load);

  function haversine(lat1: number, lng1: number, lat2: number, lng2: number) {
    const R = 6371000;
    const toRad = (x: number) => (x * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a = Math.sin(dLat/2)**2 + Math.cos(toRad(lat1))*Math.cos(toRad(lat2))*Math.sin(dLng/2)**2;
    return 2 * R * Math.asin(Math.sqrt(a));
  }

  async function selfCheckIn(e: any) {
    busyEvent = e.id;
    msg = null;
    if (!e.geofence_lat || !e.geofence_lng) {
      msg = { eventId: e.id, text: 'لم يُحدَّد موقع التحضير لهذه الفعالية بعد', ok: false };
      busyEvent = null;
      return;
    }
    if (!navigator.geolocation) {
      msg = { eventId: e.id, text: 'الموقع غير مدعوم في جهازك', ok: false };
      busyEvent = null;
      return;
    }
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        const dist = haversine(pos.coords.latitude, pos.coords.longitude, e.geofence_lat, e.geofence_lng);
        const radius = e.geofence_radius_m || 150;
        if (dist > radius) {
          msg = { eventId: e.id, text: `أنت على بُعد ${Math.round(dist)}م من الموقع. يجب أن تكون داخل ${radius}م.`, ok: false };
          busyEvent = null;
          return;
        }

        const payload: any = {
          event_id: e.id,
          user_id: $session!.user!.id,
          status: 'present',
          method: 'self_geo',
          self_marked: true,
          check_in_lat: pos.coords.latitude,
          check_in_lng: pos.coords.longitude,
          check_in_accuracy_m: Math.round(pos.coords.accuracy || 0),
          distance_from_event_m: dist,
          marked_at: new Date().toISOString()
        };
        const { error: err } = await supabase.from('attendance').upsert(payload, { onConflict: 'event_id,user_id' });
        if (err) {
          msg = { eventId: e.id, text: 'فشل الحفظ: ' + err.message, ok: false };
        } else {
          msg = { eventId: e.id, text: `تم تسجيل حضورك (على بعد ${Math.round(dist)}م من المركز)`, ok: true };
          await load();
        }
        busyEvent = null;
      },
      (err) => {
        msg = { eventId: e.id, text: 'تعذّر الحصول على الموقع: ' + err.message, ok: false };
        busyEvent = null;
      },
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
    );
  }

  const statusLabels: Record<string, string> = {
    present: 'حاضر', late: 'متأخر', excused: 'معذور', absent: 'غائب'
  };
  const statusPill: Record<string, string> = {
    present: 'ok', late: 'warn', excused: 'info', absent: 'bad'
  };
  const methodLabels: Record<string, string> = {
    manual: 'يدوي', self_qr: 'QR', self_geo: 'موقع', self_pin: 'رمز'
  };

  function isCurrent(e: any): boolean {
    const now = Date.now();
    const start = new Date(e.start_datetime).getTime();
    const end = e.end_datetime ? new Date(e.end_datetime).getTime() : start + 3 * 3600 * 1000;
    const windowStart = start - 15 * 60 * 1000;
    const windowEnd = end + 30 * 60 * 1000;
    return now >= windowStart && now <= windowEnd;
  }
</script>

<PageHead icon={UserCheck} title="التحضير الذكي" subtitle="سجّل وصولك بأمان عبر الموقع أو رمز الحضور" />

{#if loading}
  <div class="u-stack">
    <div class="u-skel u-skel-card"></div>
    <div class="u-skel u-skel-card"></div>
  </div>
{:else if events.length === 0}
  <div class="u-empty">
    <EmptyIllustrations kind="attendance" />
    <h3>لا توجد فعاليات هذا الأسبوع</h3>
    <p>سيظهر التحضير هنا عند اقتراب موعد أي فعالية.</p>
  </div>
{:else}
  <div class="u-alert intro-alert">
    <Icon icon={AlertCircle} size={16} />
    <span>اضغط <b>"تحضير بالموقع"</b> عند الوصول للفعالية؛ سيتحقق النظام من نطاق الموقع.</span>
  </div>

  <button class="u-btn u-btn-secondary block scan-btn" onclick={() => showScanner = true}>
    <Icon icon={ScanQrCode} size={17} /> مسح رمز الحضور
  </button>

  <div class="u-stack">
    {#each events as e (e.id)}
      {@const att = myAttendance[e.id]}
      {@const current = isCurrent(e)}
      {@const hasGeo = !!(e.geofence_lat && e.geofence_lng)}
      <article class="u-card att-card" class:current>
        <header class="att-head">
          <time class="date-badge" datetime={e.start_datetime}>
            <span class="d">{fmtDate(e.start_datetime).split(' ')[0]}</span>
            <span class="n">{new Date(e.start_datetime).getDate()}</span>
          </time>
          <div class="info">
            <div class="title-line"><span class={`type-dot type-${e.type}`}></span><div class="title">{e.title}</div></div>
            <div class="meta">
              <span><Icon icon={Clock} size={14} />{fmtTime(e.start_datetime)}</span>
              {#if e.location_name}<span><Icon icon={MapPin} size={14} />{e.location_name}</span>{/if}
              <span>{EVENT_TYPES[e.type]?.label || e.type}</span>
            </div>
          </div>
          {#if current}
            <span class="u-pill solid live">
              <span class="dot"></span>الآن
            </span>
          {/if}
        </header>

        {#if att}
          <div class="status-row">
            <span class="u-pill {statusPill[att.status]}">
              {statusLabels[att.status]}
            </span>
            <span class="u-muted">
              عبر {methodLabels[att.method] || att.method}
              {#if att.distance_from_event_m != null} · {Math.round(att.distance_from_event_m)}م{/if}
            </span>
          </div>
        {:else if current && hasGeo}
          <button class="u-btn u-btn-primary lg block check-btn" disabled={busyEvent === e.id} onclick={() => selfCheckIn(e)}>
            <Icon icon={MapPin} size={17} />
            {busyEvent === e.id ? 'جارٍ تحديد موقعك…' : 'تحضير بالموقع'}
          </button>
        {:else if current && !hasGeo}
          <div class="u-alert warn inline-alert"><Icon icon={AlertCircle} size={15} /> لم يُحدِّد المسؤول موقعاً للتحضير الذاتي بعد.</div>
        {:else}
          <div class="status-muted">
            {#if hasGeo}
              <Icon icon={MapPin} size={15} /> موقع التحضير جاهز؛ سيُفعَّل عند بدء الفعالية
            {:else}
              <Icon icon={Clock} size={15} /> لم يحن وقت التحضير
            {/if}
          </div>
        {/if}

        {#if msg && msg.eventId === e.id}
          <div class="u-alert {msg.ok ? 'ok' : 'err'} inline-alert">
            <Icon icon={msg.ok ? CheckCircle2 : AlertCircle} size={15} />{msg.text}
          </div>
        {/if}

        {#if $isAdmin}
          <div class="u-grid u-grid-2 admin-actions">
            <button class="u-btn u-btn-secondary sm" onclick={() => qrEvent = e}>
              <Icon icon={QrCode} size={15} /> عرض الرمز
            </button>
            <button class="u-btn u-btn-ghost sm" onclick={() => manageEventId = e.id}>
              <Icon icon={Settings2} size={15} /> إدارة الحضور
            </button>
          </div>
        {/if}
      </article>
    {/each}
  </div>
{/if}

{#if manageEventId}
  <AttendanceManage eventId={manageEventId} onclose={() => { manageEventId = null; load(); }} />
{/if}

{#if qrEvent}
  <AttendanceQR eventId={qrEvent.id} eventTitle={qrEvent.title} onclose={() => qrEvent = null} />
{/if}

{#if showScanner}
  <AttendanceScan
    onclose={() => showScanner = false}
    onsuccess={() => { showScanner = false; void load(); }}
  />
{/if}

<style>
  .att-card { position: relative; }
  .scan-btn { margin: var(--sp-2) 0; }
  .att-card.current {
    border-color: var(--ok);
    box-shadow: 0 0 0 calc(var(--sp-05) / 2) var(--ok-soft);
  }

  .intro-alert, .inline-alert { display: flex; align-items: center; gap: var(--sp-1); }

  .att-head {
    display: flex;
    gap: var(--sp-3);
    align-items: center;
    margin-bottom: var(--sp-2);
  }

  .date-badge {
    color: var(--ink);
    padding-inline-end: var(--sp-3);
    border-inline-end: 1px solid var(--line);
    text-align: center;
    min-width: var(--sp-8);
    flex-shrink: 0;
  }
  .date-badge .d {
    display: block;
    font: var(--fw-semi) var(--fs-tiny) var(--font-sans);
    color: var(--ink3);
  }
  .date-badge .n {
    display: block;
    font: var(--fw-bold) var(--fs-xl) var(--font-num);
    font-variant-numeric: tabular-nums;
    margin-top: var(--sp-05);
  }

  .info { flex: 1; min-width: 0; }
  .title-line { display: flex; align-items: center; gap: var(--sp-1); }
  .title { font: var(--fw-semi) var(--fs-base) var(--font-sans); color: var(--ink); }
  .type-dot { width: calc(var(--sp-1) - 2px); height: calc(var(--sp-1) - 2px); border-radius: var(--r-pill); background: var(--brand); }
  .type-sport { background: var(--gold); }
  .type-cultural { background: var(--brand-3); }
  .type-competition { background: var(--warn); }
  .type-hospitality { background: var(--info); }
  .meta { display: flex; gap: var(--sp-2); align-items: center; flex-wrap: wrap; font-size: var(--fs-tiny); color: var(--ink3); margin-top: var(--sp-05); }
  .meta span { display: inline-flex; align-items: center; gap: var(--sp-05); }

  .live {
    background: var(--ok);
    color: var(--on-brand);
    gap: var(--sp-05);
    flex-shrink: 0;
  }
  .dot {
    width: calc(var(--sp-1) - 1px); height: calc(var(--sp-1) - 1px); border-radius: var(--r-pill);
    background: var(--on-brand);
    animation: live-pulse 1.5s ease-in-out infinite;
  }
  @keyframes live-pulse { 0%,100% { opacity: 1; } 50% { opacity: 0.4; } }

  .status-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: var(--sp-1) var(--sp-2);
    background: var(--bg);
    border-radius: var(--r-sm);
    margin-top: var(--sp-1);
  }

  .check-btn { margin-top: var(--sp-05); }
  .status-muted {
    padding: var(--sp-1) var(--sp-2);
    background: var(--bg);
    color: var(--ink3);
    border-radius: var(--r-sm);
    font-size: var(--fs-xs);
    text-align: center;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: var(--sp-1);
  }

  .admin-actions { margin-top: var(--sp-1); }
  .block { width: 100%; }
</style>
