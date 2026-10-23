<script lang="ts">
  import { onMount } from 'svelte';
  import PageHead from '../components/PageHead.svelte';
  import { supabase } from '../supabase';
  import { roles, route } from '../stores';

  type Period = 'month' | 'quarter' | 'year' | 'all';

  const periodOptions: { key: Period; label: string }[] = [
    { key: 'month', label: 'هذا الشهر' },
    { key: 'quarter', label: 'آخر 3 أشهر' },
    { key: 'year', label: 'هذا العام' },
    { key: 'all', label: 'كل الوقت' }
  ];

  const statusLabels: Record<string, string> = {
    present: 'حاضر',
    late: 'متأخر',
    excused: 'معذور',
    absent: 'غائب'
  };

  let period = $state<Period>('month');
  let events = $state<any[]>([]);
  let trendEvents = $state<any[]>([]);
  let attendance = $state<any[]>([]);
  let hosting = $state<any[]>([]);
  let people = $state<Record<string, string>>({});
  let loading = $state(true);
  let error = $state('');
  let requestVersion = 0;

  const canView = $derived(
    $roles.includes('super_admin') || $roles.some((roleName) => roleName.startsWith('mod_'))
  );

  function periodStart(selected: Period) {
    const now = new Date();
    if (selected === 'all') return null;
    if (selected === 'month') return new Date(now.getFullYear(), now.getMonth(), 1);
    if (selected === 'quarter') return new Date(now.getFullYear(), now.getMonth() - 2, 1);
    return new Date(now.getFullYear(), 0, 1);
  }

  function startOfWeek(value: Date) {
    const result = new Date(value);
    const daysSinceMonday = (result.getDay() + 6) % 7;
    result.setDate(result.getDate() - daysSinceMonday);
    result.setHours(0, 0, 0, 0);
    return result;
  }

  function twelveWeekStart() {
    const start = startOfWeek(new Date());
    start.setDate(start.getDate() - 11 * 7);
    return start;
  }

  async function load() {
    const version = ++requestVersion;
    loading = true;
    error = '';

    try {
      const selectedStart = periodStart(period);
      const trendStart = twelveWeekStart();
      const queryStart = !selectedStart || selectedStart < trendStart ? selectedStart : trendStart;

      let eventsQuery = supabase
        .from('events')
        .select('id,type,title,start_datetime,end_datetime,status')
        .is('deleted_at', null)
        .lte('start_datetime', new Date().toISOString())
        .order('start_datetime', { ascending: true });

      if (queryStart) eventsQuery = eventsQuery.gte('start_datetime', queryStart.toISOString());
      const { data: allEvents, error: eventsError } = await eventsQuery;
      if (eventsError) throw eventsError;

      const fetchedEvents = allEvents || [];
      const filteredEvents = selectedStart
        ? fetchedEvents.filter((event) => new Date(event.start_datetime) >= selectedStart)
        : fetchedEvents;
      const eventIds = filteredEvents.map((event) => event.id);

      let attendanceRows: any[] = [];
      let hostingRows: any[] = [];
      if (eventIds.length) {
        const [attendanceResult, hostingResult] = await Promise.all([
          supabase
            .from('attendance')
            .select('event_id,user_id,status,marked_at')
            .in('event_id', eventIds),
          supabase
            .from('hosting_assignments')
            .select('event_id,host_a_user_id,host_b_user_id,status')
            .is('deleted_at', null)
            .in('event_id', eventIds)
        ]);
        if (attendanceResult.error) throw attendanceResult.error;
        if (hostingResult.error) throw hostingResult.error;
        attendanceRows = attendanceResult.data || [];
        hostingRows = hostingResult.data || [];
      }

      const userIds = Array.from(new Set([
        ...attendanceRows.map((row) => row.user_id),
        ...hostingRows.flatMap((row) => [row.host_a_user_id, row.host_b_user_id])
      ].filter(Boolean)));
      const names: Record<string, string> = {};
      if (userIds.length) {
        const { data: users, error: usersError } = await supabase
          .from('users')
          .select('id,full_name')
          .in('id', userIds);
        if (usersError) throw usersError;
        for (const user of users || []) names[user.id] = user.full_name;
      }

      if (version !== requestVersion) return;
      events = filteredEvents;
      trendEvents = fetchedEvents.filter((event) => new Date(event.start_datetime) >= trendStart);
      attendance = attendanceRows;
      hosting = hostingRows;
      people = names;
    } catch (loadError: any) {
      if (version === requestVersion) error = loadError?.message || 'تعذّر تحميل التقارير.';
    } finally {
      if (version === requestVersion) loading = false;
    }
  }

  function selectPeriod(nextPeriod: Period) {
    if (nextPeriod === period) return;
    period = nextPeriod;
    void load();
  }

  const metrics = $derived.by(() => {
    const attended = attendance.filter((row) => row.status === 'present' || row.status === 'late').length;
    const denominator = attendance.length;
    const activeHosts = new Set(
      hosting
        .filter((row) => row.status !== 'cancelled')
        .flatMap((row) => [row.host_a_user_id, row.host_b_user_id])
        .filter(Boolean)
    ).size;
    const completedWeekly = events.filter((event) =>
      event.type === 'weekly' && (event.status === 'completed' || new Date(event.end_datetime) <= new Date())
    ).length;

    return [
      { label: 'عدد الفعاليات', value: events.length.toLocaleString('ar-SA') },
      { label: 'عدد الحضور الكلي', value: attended.toLocaleString('ar-SA') },
      { label: 'نسبة الحضور %', value: `${denominator ? Math.round(attended / denominator * 100) : 0}٪` },
      { label: 'عدد المضيفين الفعّالين', value: activeHosts.toLocaleString('ar-SA') },
      { label: 'طلعات أربعاء منفَّذة', value: completedWeekly.toLocaleString('ar-SA') },
      { label: 'متوسط الحضور/فعالية', value: (events.length ? attended / events.length : 0).toLocaleString('ar-SA', { maximumFractionDigits: 1 }) }
    ];
  });

  const topAttendees = $derived.by(() => {
    const counts = new Map<string, number>();
    for (const row of attendance) {
      if (row.status !== 'present' && row.status !== 'late') continue;
      counts.set(row.user_id, (counts.get(row.user_id) || 0) + 1);
    }
    return [...counts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([id, count]) => ({ id, name: people[id] || 'عضو', count }));
  });

  const topHosts = $derived.by(() => {
    const counts = new Map<string, number>();
    for (const row of hosting) {
      if (row.status === 'cancelled') continue;
      for (const id of [row.host_a_user_id, row.host_b_user_id]) {
        if (id) counts.set(id, (counts.get(id) || 0) + 1);
      }
    }
    return [...counts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([id, count]) => ({ id, name: people[id] || 'مضيف', count }));
  });

  const breakdown = $derived.by(() => {
    const total = attendance.length;
    return ['present', 'late', 'excused', 'absent'].map((status) => {
      const count = attendance.filter((row) => row.status === status).length;
      return { status, label: statusLabels[status], count, percent: total ? Math.round(count / total * 100) : 0 };
    });
  });

  const weeklyTrend = $derived.by(() => {
    const firstWeek = twelveWeekStart();
    return Array.from({ length: 12 }, (_, index) => {
      const start = new Date(firstWeek);
      start.setDate(start.getDate() + index * 7);
      const end = new Date(start);
      end.setDate(end.getDate() + 7);
      const count = trendEvents.filter((event) => {
        const date = new Date(event.start_datetime);
        return date >= start && date < end;
      }).length;
      return {
        label: start.toLocaleDateString('ar-SA', { day: 'numeric', month: 'numeric' }),
        count
      };
    });
  });

  const chart = $derived.by(() => {
    const width = 720;
    const height = 240;
    const sidePadding = 28;
    const topPadding = 20;
    const bottomPadding = 48;
    const slot = (width - sidePadding * 2) / weeklyTrend.length;
    const maxCount = Math.max(1, ...weeklyTrend.map((week) => week.count));
    const plotHeight = height - topPadding - bottomPadding;
    return {
      width,
      height,
      baseline: height - bottomPadding,
      bars: weeklyTrend.map((week, index) => {
        const barHeight = week.count / maxCount * plotHeight;
        return {
          ...week,
          x: sidePadding + index * slot + slot * 0.2,
          y: height - bottomPadding - barHeight,
          width: slot * 0.6,
          height: barHeight,
          labelX: sidePadding + index * slot + slot / 2
        };
      })
    };
  });

  function csvCell(value: unknown) {
    return `"${String(value ?? '').replaceAll('"', '""')}"`;
  }

  function exportCsv() {
    const rows = [['الفعالية', 'التاريخ', 'حاضر', 'متأخر', 'معذور', 'غائب', 'إجمالي السجلات']];
    for (const event of events) {
      const eventAttendance = attendance.filter((row) => row.event_id === event.id);
      rows.push([
        event.title,
        new Date(event.start_datetime).toLocaleDateString('ar-SA'),
        String(eventAttendance.filter((row) => row.status === 'present').length),
        String(eventAttendance.filter((row) => row.status === 'late').length),
        String(eventAttendance.filter((row) => row.status === 'excused').length),
        String(eventAttendance.filter((row) => row.status === 'absent').length),
        String(eventAttendance.length)
      ]);
    }
    const csv = `\uFEFF${rows.map((row) => row.map(csvCell).join(',')).join('\n')}`;
    const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = `tawaq-report-${period}-${new Date().toISOString().slice(0, 10)}.csv`;
    anchor.click();
    URL.revokeObjectURL(url);
  }

  onMount(() => {
    if (!canView) {
      route.set('home');
      return;
    }
    void load();
  });
</script>

{#if canView}
  <div class="reports-page">
    <PageHead icon="📊" title="التقارير والإحصائيات" />

    <div class="u-seg block period-selector" aria-label="الفترة الزمنية">
      {#each periodOptions as option (option.key)}
        <button
          class="seg-btn"
          class:on={period === option.key}
          aria-pressed={period === option.key}
          onclick={() => selectPeriod(option.key)}
        >{option.label}</button>
      {/each}
    </div>

    {#if loading}
      <div class="u-grid u-grid-2">
        {#each Array(6) as _}
          <div class="u-skel u-skel-card"></div>
        {/each}
      </div>
    {:else if error}
      <div class="u-alert err">{error}</div>
      <button class="u-btn u-btn-primary block" onclick={() => void load()}>إعادة المحاولة</button>
    {:else}
      <section class="u-grid u-grid-2 stats-grid" aria-label="المؤشرات الرئيسية">
        {#each metrics as metric (metric.label)}
          <div class="u-stat">
            <span class="lbl">{metric.label}</span>
            <span class="num">{metric.value}</span>
          </div>
        {/each}
      </section>

      <section class="u-card report-card">
        <div class="u-card-h">أفضل 10 حضوراً</div>
        {#if topAttendees.length}
          <ul class="u-list">
            {#each topAttendees as attendee, index (attendee.id)}
              <li class="u-list-item">
                <span class="u-avatar circle sm">{index + 1}</span>
                <div class="u-list-main">
                  <div class="u-list-title">{attendee.name}</div>
                  <div class="u-list-sub">حضور الفعاليات</div>
                </div>
                <span class="u-pill brand">{attendee.count.toLocaleString('ar-SA')}</span>
              </li>
            {/each}
          </ul>
        {:else}
          <div class="u-empty compact-empty"><p>لا توجد سجلات حضور في هذه الفترة.</p></div>
        {/if}
      </section>

      <section class="u-card report-card">
        <div class="u-card-h">أفضل 5 مضيفين</div>
        {#if topHosts.length}
          <ul class="u-list">
            {#each topHosts as host, index (host.id)}
              <li class="u-list-item">
                <span class="u-avatar circle sm">{index + 1}</span>
                <div class="u-list-main">
                  <div class="u-list-title">{host.name}</div>
                  <div class="u-list-sub">تكليفات الاستضافة</div>
                </div>
                <span class="u-pill gold">{host.count.toLocaleString('ar-SA')}</span>
              </li>
            {/each}
          </ul>
        {:else}
          <div class="u-empty compact-empty"><p>لا توجد تكليفات استضافة في هذه الفترة.</p></div>
        {/if}
      </section>

      <section class="u-card report-card">
        <div class="u-card-h">توزيع الحضور</div>
        <div class="u-stack">
          {#each breakdown as item (item.status)}
            <div class="progress-row">
              <div class="progress-head">
                <span>{item.label}</span>
                <span class="u-muted">{item.count.toLocaleString('ar-SA')} · {item.percent}٪</span>
              </div>
              <div class="u-progress-bar" aria-label={`${item.label}: ${item.percent}٪`}>
                <div class="pb-fill" style:width={`${item.percent}%`}></div>
              </div>
            </div>
          {/each}
        </div>
      </section>

      <section class="u-card report-card">
        <div class="u-card-h">اتجاه الفعاليات الأسبوعي</div>
        <div class="chart-wrap">
          <svg viewBox={`0 0 ${chart.width} ${chart.height}`} role="img" aria-label="عدد الفعاليات خلال آخر 12 أسبوعاً">
            <line x1="0" y1={chart.baseline} x2={chart.width} y2={chart.baseline} class="chart-axis" />
            {#each chart.bars as bar (bar.label)}
              <rect x={bar.x} y={bar.y} width={bar.width} height={bar.height} class="chart-bar" />
              <text x={bar.labelX} y={bar.y - 7} class="chart-value">{bar.count}</text>
              <text x={bar.labelX} y={chart.baseline + 24} class="chart-label">{bar.label}</text>
            {/each}
          </svg>
        </div>
      </section>

      <div class="u-grid u-grid-2 export-actions">
        <button class="u-btn u-btn-primary" onclick={exportCsv}>تصدير CSV</button>
        <button class="u-btn u-btn-ghost" onclick={() => window.print()}>طباعة</button>
      </div>
    {/if}
  </div>
{/if}

<style>
  .reports-page { display: flex; flex-direction: column; gap: var(--sp-3); }
  .period-selector { overflow-x: auto; }
  .period-selector .seg-btn { padding-inline: var(--sp-1); }
  .stats-grid .u-stat { min-height: calc(var(--sp-8) + var(--sp-4)); }
  .report-card { display: flex; flex-direction: column; gap: var(--sp-2); }
  .report-card .u-card-h { margin-bottom: 0; }
  .compact-empty { padding: var(--sp-3); }
  .progress-row { display: flex; flex-direction: column; gap: var(--sp-1); }
  .progress-head { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-2); }
  .chart-wrap { direction: ltr; overflow-x: auto; }
  .chart-wrap svg { display: block; width: 100%; min-width: calc(var(--sp-8) * 8); height: auto; }
  .chart-axis { stroke: var(--line2); stroke-width: var(--border-w); }
  .chart-bar { fill: var(--brand); rx: var(--r-xs); }
  .chart-value,
  .chart-label {
    fill: var(--ink2);
    font: var(--fw-semi) var(--fs-tiny) var(--font-sans);
    text-anchor: middle;
  }
  .export-actions { padding-bottom: var(--sp-2); }

  @media print {
    :global(.u-topbar),
    :global(.u-nav),
    .period-selector,
    .export-actions { display: none; }
    :global(.u-page) { padding: 0; }
    .reports-page { gap: var(--sp-2); }
    .report-card { break-inside: avoid; box-shadow: none; }
  }
</style>
