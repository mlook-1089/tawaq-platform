<script lang="ts">
  import { onMount } from 'svelte';
  import { AlertCircle, CheckCircle2, Clock, MapPin, QrCode, ScanQrCode, Settings2 } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { session, isAdmin } from '../stores';
  import { fmtDate, fmtTime, EVENT_TYPES } from '../utils';
  import AttendanceManage from './AttendanceManage.svelte';
  import AttendanceQR from './AttendanceQR.svelte';
  import AttendanceScan from './AttendanceScan.svelte';
  import Icon from '../components/Icon.svelte';
  import EmptyIllustrations from '../components/EmptyIllustrations.svelte';

  const eventPill: Record<string, string> = {
    weekly: 'brand', sport: 'gold', cultural: 'info',
    competition: 'warn', event: 'brand', hospitality: 'gold'
  };

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

<div class="u-page">
  <div class="u-top">
    <div>
      <div class="u-sub">تحضير بالموقع أو برمز الحضور</div>
      <h1>التحضير الذكي</h1>
    </div>
    <div class="u-actions">
      <button class="u-btn u-btn-secondary sm" onclick={() => showScanner = true}>
        <Icon icon={ScanQrCode} size={15} /> مسح
      </button>
    </div>
  </div>

  {#if loading}
    <div class="u-stack">
      <div class="u-skel att-skel"></div>
      <div class="u-skel att-skel"></div>
    </div>
  {:else if events.length === 0}
    <div class="u-empty">
      <EmptyIllustrations kind="attendance" />
      <h3>لا توجد فعاليات هذا الأسبوع</h3>
      <p>سيظهر التحضير هنا عند اقتراب موعد أي فعالية.</p>
    </div>
  {:else}
    <div class="u-stack">
      {#each events as e (e.id)}
        {@const att = myAttendance[e.id]}
        {@const current = isCurrent(e)}
        {@const hasGeo = !!(e.geofence_lat && e.geofence_lng)}
        <article class="u-card att-card" class:current>
          <div class="att-head">
            <div class="date-chip">
              <div class="d-num">{new Date(e.start_datetime).getDate()}</div>
              <div class="d-mo">{new Intl.DateTimeFormat('ar', { month: 'short' }).format(new Date(e.start_datetime))}</div>
            </div>
            <div class="u-grow">
              <div class="title-line">
                <div class="title">{e.title}</div>
                {#if current}
                  <span class="u-pill live"><span class="dot"></span>الآن</span>
                {/if}
              </div>
              <div class="meta u-muted">
                <span><Icon icon={Clock} size={12} /> {fmtTime(e.start_datetime)}</span>
                {#if e.location_name}<span><Icon icon={MapPin} size={12} /> {e.location_name}</span>{/if}
                <span class="u-pill {eventPill[e.type] || 'brand'} sm-pill">{EVENT_TYPES[e.type]?.label || e.type}</span>
              </div>
            </div>
          </div>

          {#if att}
            <div class="status-row">
              <span class="u-pill {statusPill[att.status]}">{statusLabels[att.status]}</span>
              <span class="u-muted">
                {methodLabels[att.method] || att.method}
                {#if att.distance_from_event_m != null} · {Math.round(att.distance_from_event_m)}م{/if}
              </span>
            </div>
          {:else if current && hasGeo}
            <button class="u-btn u-btn-primary lg w" disabled={busyEvent === e.id} onclick={() => selfCheckIn(e)}>
              <Icon icon={MapPin} size={17} />
              {busyEvent === e.id ? 'جارٍ تحديد موقعك…' : 'تحضير بالموقع'}
            </button>
          {:else if current && !hasGeo}
            <div class="u-alert warn inline-alert"><Icon icon={AlertCircle} size={15} /> لم يُحدِّد المسؤول موقعاً للتحضير بعد.</div>
          {:else}
            <div class="status-muted">
              {#if hasGeo}
                <Icon icon={MapPin} size={14} /> سيُفعَّل عند بدء الفعالية
              {:else}
                <Icon icon={Clock} size={14} /> لم يحن وقت التحضير
              {/if}
            </div>
          {/if}

          {#if msg && msg.eventId === e.id}
            <div class="u-alert {msg.ok ? 'ok' : 'err'} inline-alert">
              <Icon icon={msg.ok ? CheckCircle2 : AlertCircle} size={15} />{msg.text}
            </div>
          {/if}

          {#if $isAdmin}
            <div class="u-grid2 admin-actions">
              <button class="u-btn u-btn-secondary sm" onclick={() => qrEvent = e}>
                <Icon icon={QrCode} size={15} /> عرض الرمز
              </button>
              <button class="u-btn u-btn-ghost sm" onclick={() => manageEventId = e.id}>
                <Icon icon={Settings2} size={15} /> إدارة
              </button>
            </div>
          {/if}
        </article>
      {/each}
    </div>
  {/if}
</div>

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
  .att-skel { height: 110px; border-radius: var(--r-xl); }

  .att-card {
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
    position: relative;
  }
  .att-card.current {
    border-color: var(--ok);
    box-shadow: 0 0 0 2px var(--ok-soft);
  }

  .att-head {
    display: flex;
    gap: var(--sp-2);
    align-items: center;
  }

  .date-chip {
    width: 48px;
    text-align: center;
    padding: 6px 0;
    background: var(--brand-soft);
    border-radius: var(--r-sm);
    flex-shrink: 0;
  }
  .date-chip .d-num {
    font: var(--fw-bold) 20px/1 var(--font-sans);
    color: var(--brand-ink);
    font-variant-numeric: tabular-nums;
  }
  .date-chip .d-mo {
    font-size: 11px;
    color: var(--ink3);
    font-weight: var(--fw-medium);
    margin-top: 1px;
  }

  .title-line {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
  }
  .title {
    font: var(--fw-bold) var(--fs-base) var(--font-sans);
    color: var(--ink);
    flex: 1;
    min-width: 0;
  }
  .meta {
    display: flex;
    gap: var(--sp-1);
    align-items: center;
    flex-wrap: wrap;
    margin-top: 4px;
    font-size: var(--fs-tiny);
  }
  .meta span { display: inline-flex; align-items: center; gap: 3px; }
  .sm-pill { font-size: 10px; padding: 2px 8px; }

  .live {
    background: var(--ok);
    color: var(--on-brand);
    gap: 4px;
    flex-shrink: 0;
  }
  .dot {
    width: 6px;
    height: 6px;
    border-radius: var(--r-pill);
    background: var(--on-brand);
    animation: live-pulse 1.5s ease-in-out infinite;
  }
  @keyframes live-pulse { 0%,100% { opacity: 1; } 50% { opacity: 0.4; } }

  .status-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px var(--sp-2);
    background: var(--bg);
    border-radius: var(--r-sm);
  }

  .status-muted {
    padding: 8px var(--sp-2);
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

  .inline-alert {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    padding: 8px var(--sp-2);
  }

  .u-grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-1); }
  .u-grid2 .u-btn { width: 100%; }
  .u-btn.w { width: 100%; }
</style>
