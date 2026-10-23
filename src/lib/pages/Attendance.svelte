<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../supabase';
  import { session, roles, isAdmin } from '../stores';
  import { fmtDate, fmtTime, EVENT_TYPES } from '../utils';
  import PageHead from '../components/PageHead.svelte';
  import AttendanceManage from './AttendanceManage.svelte';

  let events = $state<any[]>([]);
  let myAttendance = $state<Record<string, any>>({});
  let loading = $state(true);
  let busyEvent = $state<string | null>(null);
  let msg = $state<{ eventId: string; text: string; ok: boolean } | null>(null);
  let manageEventId = $state<string | null>(null);

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

        // Insert attendance
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
          msg = { eventId: e.id, text: `✅ تم تسجيل حضورك (على بعد ${Math.round(dist)}م من المركز)`, ok: true };
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
  const methodLabels: Record<string, string> = {
    manual: 'يدوي', self_qr: 'QR', self_geo: 'موقع', self_pin: 'رمز'
  };

  function isCurrent(e: any): boolean {
    const now = Date.now();
    const start = new Date(e.start_datetime).getTime();
    const end = e.end_datetime ? new Date(e.end_datetime).getTime() : start + 3 * 3600 * 1000;
    const windowStart = start - 15 * 60 * 1000;  // 15 min before
    const windowEnd = end + 30 * 60 * 1000;      // 30 min after
    return now >= windowStart && now <= windowEnd;
  }
</script>

<PageHead icon="✓" title="التحضير الذكي" />

{#if loading}
  <div class="skel"></div>
  <div class="skel"></div>
{:else if events.length === 0}
  <div class="empty">
    <div class="ic">📅</div>
    <h3>لا توجد فعاليات هذا الأسبوع</h3>
    <p>سيظهر التحضير هنا عند اقتراب موعد أي فعالية.</p>
  </div>
{:else}
  <div class="info-strip">
    💡 اضغط <b>"تحضير بالموقع"</b> عند الوصول للفعالية — النظام يتحقق من موقعك ويُسجّلك تلقائياً.
  </div>

  {#each events as e (e.id)}
    {@const att = myAttendance[e.id]}
    {@const current = isCurrent(e)}
    {@const hasGeo = !!(e.geofence_lat && e.geofence_lng)}
    <div class="card" class:current>
      <div class="head" style="--acc: {e.color_tag || EVENT_TYPES[e.type]?.color}">
        <div class="date-badge">
          <span class="day">{fmtDate(e.start_datetime).split(' ')[0]}</span>
          <span class="time">{fmtTime(e.start_datetime)}</span>
        </div>
        <div class="t">
          <div class="title">{e.title}</div>
          <div class="sub">
            <span class="type-badge" style="background: {e.color_tag || EVENT_TYPES[e.type]?.color}">{EVENT_TYPES[e.type]?.label || e.type}</span>
            {#if e.location_name}<span class="loc">📍 {e.location_name}</span>{/if}
          </div>
        </div>
        {#if current}<div class="live-badge"><span class="dot"></span>الآن</div>{/if}
      </div>

      {#if att}
        <div class="status-row">
          <div class="status-badge status-{att.status}">
            {att.status === 'present' ? '✓' : att.status === 'late' ? '⏰' : att.status === 'excused' ? '✎' : '✗'}
            {statusLabels[att.status]}
          </div>
          <div class="method">
            عبر {methodLabels[att.method] || att.method}
            {#if att.distance_from_event_m != null} · {Math.round(att.distance_from_event_m)}م{/if}
          </div>
        </div>
      {:else if current && hasGeo}
        <button class="check-btn" disabled={busyEvent === e.id} onclick={() => selfCheckIn(e)}>
          {busyEvent === e.id ? 'جارٍ تحديد موقعك…' : '📍 تحضير بالموقع'}
        </button>
      {:else if current && !hasGeo}
        <div class="warn">⚠️ لم يُحدِّد المسؤول موقعاً للتحضير الذاتي بعد.</div>
      {:else}
        <div class="muted-row">
          {hasGeo ? '📍 موقع التحضير جاهز — سيُفعَّل عند بدء الفعالية' : '⏳ لم يحن وقت التحضير'}
        </div>
      {/if}

      {#if msg && msg.eventId === e.id}
        <div class="msg {msg.ok ? 'ok' : 'err'}">{msg.text}</div>
      {/if}

      {#if $isAdmin}
        <button class="admin-btn" onclick={() => manageEventId = e.id}>
          إدارة الحضور (مسؤول)
        </button>
      {/if}
    </div>
  {/each}
{/if}

{#if manageEventId}
  <AttendanceManage eventId={manageEventId} onclose={() => { manageEventId = null; load(); }} />
{/if}

<style>
  .info-strip {
    background: var(--brand-soft);
    border: 1px solid var(--brand);
    border-right-width: 4px;
    border-radius: 12px;
    padding: 12px 14px;
    font-size: 12.5px;
    color: var(--brand);
    margin-bottom: 14px;
    line-height: 1.6;
  }

  .card {
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: 16px;
    padding: 14px;
    margin-bottom: 12px;
    box-shadow: var(--shadow);
    position: relative;
    overflow: hidden;
  }
  .card.current {
    border-color: var(--ok);
    box-shadow: 0 0 0 3px var(--ok-soft);
  }

  .head { display: flex; gap: 12px; align-items: center; margin-bottom: 10px; }

  .date-badge {
    background: var(--acc, var(--brand));
    color: #fff;
    border-radius: 11px;
    padding: 8px 10px;
    text-align: center;
    min-width: 70px;
    flex-shrink: 0;
  }
  .date-badge .day { display: block; font-size: 10.5px; font-weight: 600; opacity: .9; }
  .date-badge .time { display: block; font-size: 15px; font-weight: 700; font-variant-numeric: tabular-nums; margin-top: 2px; }

  .t { flex: 1; min-width: 0; }
  .title { font-weight: 700; font-size: 14.5px; color: var(--ink); margin-bottom: 5px; }
  .sub { display: flex; gap: 7px; align-items: center; flex-wrap: wrap; font-size: 11px; color: var(--ink3); }
  .type-badge {
    display: inline-block;
    padding: 3px 9px;
    border-radius: 99px;
    color: #fff;
    font-size: 10px;
    font-weight: 600;
  }
  .loc { color: var(--ink3); }

  .live-badge {
    background: var(--ok);
    color: #fff;
    padding: 4px 10px;
    border-radius: 99px;
    font-size: 10.5px;
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: 5px;
    flex-shrink: 0;
  }
  .dot {
    width: 7px; height: 7px; border-radius: 50%;
    background: #fff;
    animation: pulse 1.5s ease-in-out infinite;
  }
  @keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: .4; } }

  .status-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 12px;
    background: var(--bg);
    border-radius: 11px;
    margin-top: 6px;
  }
  .status-badge {
    font-weight: 700;
    font-size: 12.5px;
    padding: 5px 12px;
    border-radius: 99px;
  }
  .status-present { background: var(--ok-soft); color: var(--ok); }
  .status-late { background: var(--warn-soft); color: var(--warn); }
  .status-excused { background: var(--info-soft); color: var(--info); }
  .status-absent { background: var(--bad-soft); color: var(--bad); }
  .method { font-size: 11px; color: var(--ink3); }

  .check-btn {
    display: block;
    width: 100%;
    padding: 14px;
    background: var(--brand);
    color: var(--on-brand);
    border: none;
    border-radius: 12px;
    font-family: inherit;
    font-size: 14px;
    font-weight: 700;
    cursor: pointer;
    margin-top: 6px;
    transition: filter .15s, transform .1s;
  }
  .check-btn:hover:not(:disabled) { filter: brightness(1.1); }
  .check-btn:active:not(:disabled) { transform: scale(.98); }
  .check-btn:disabled { opacity: .6; cursor: wait; }

  .warn {
    padding: 10px 12px;
    background: var(--warn-soft);
    color: var(--warn);
    border-radius: 11px;
    font-size: 12px;
    text-align: center;
    font-weight: 600;
  }
  .muted-row {
    padding: 10px 12px;
    background: var(--bg);
    color: var(--ink3);
    border-radius: 11px;
    font-size: 11.5px;
    text-align: center;
  }

  .msg {
    margin-top: 8px;
    padding: 10px 12px;
    border-radius: 11px;
    font-size: 12.5px;
    font-weight: 500;
    text-align: center;
  }
  .msg.ok { background: var(--ok-soft); color: var(--ok); }
  .msg.err { background: var(--bad-soft); color: var(--bad); }

  .admin-btn {
    margin-top: 8px;
    display: block;
    width: 100%;
    padding: 9px;
    background: var(--gold-soft);
    color: var(--brand);
    border: 1px solid var(--gold);
    border-radius: 10px;
    font-size: 11.5px;
    font-weight: 600;
    cursor: pointer;
  }

  .empty { text-align: center; padding: 40px 16px; color: var(--ink3); background: var(--card); border-radius: 18px; border: 1px solid var(--line); }
  .empty .ic { font-size: 42px; opacity: .4; margin-bottom: 10px; }
  .empty h3 { color: var(--ink2); margin-bottom: 5px; font-size: 15px; }

  .skel { height: 130px; background: var(--muted-bg); border-radius: 16px; margin-bottom: 12px; animation: skelpulse 1.4s ease-in-out infinite; }
  @keyframes skelpulse { 0%,100% { opacity: 1; } 50% { opacity: .5; } }
</style>
