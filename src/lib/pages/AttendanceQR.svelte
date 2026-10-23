<script lang="ts">
  import { onMount } from 'svelte';
  import { LoaderCircle, QrCode, X } from 'lucide-svelte';
  import QRCode from 'qrcode';
  import { supabase } from '../supabase';
  import Icon from '../components/Icon.svelte';

  let {
    eventId,
    eventTitle,
    onclose
  }: {
    eventId: string;
    eventTitle: string;
    onclose: () => void;
  } = $props();

  let qrUrl = $state('');
  let error = $state('');
  let loading = $state(true);
  let secondsLeft = $state(60);
  let activeMinute = '';
  let timer: ReturnType<typeof setInterval> | undefined;

  function utcMinuteKey() {
    return new Date().toISOString().slice(0, 16);
  }

  async function refreshQr() {
    loading = true;
    error = '';
    const { data, error: rpcError } = await supabase.rpc('get_event_qr_payload', {
      p_event_id: eventId
    });

    if (rpcError || !data) {
      error = rpcError?.message || 'تعذّر إنشاء رمز الحضور.';
      qrUrl = '';
    } else {
      qrUrl = await QRCode.toDataURL(String(data), {
        errorCorrectionLevel: 'M',
        margin: 2,
        width: 320
      });
      activeMinute = utcMinuteKey();
    }
    loading = false;
  }

  function tick() {
    const now = new Date();
    secondsLeft = 60 - now.getUTCSeconds();
    if (utcMinuteKey() !== activeMinute) void refreshQr();
  }

  onMount(() => {
    void refreshQr();
    tick();
    timer = setInterval(tick, 1000);
    return () => timer && clearInterval(timer);
  });
</script>

<div class="u-modal" role="dialog" aria-modal="true" aria-labelledby="attendance-qr-title">
  <button class="u-modal-scrim" aria-label="إغلاق" onclick={onclose}></button>
  <section class="u-modal-box">
    <div class="u-sheet-handle" aria-hidden="true"></div>
    <header class="u-modal-header">
      <h2 id="attendance-qr-title"><Icon icon={QrCode} size={18} /> رمز حضور الفعالية</h2>
      <button class="u-modal-close" aria-label="إغلاق" onclick={onclose}><Icon icon={X} /></button>
    </header>

    <div class="u-modal-body u-stack qr-body">
      <div>
        <div class="event-title">{eventTitle}</div>
        <div class="u-muted">يتغيّر الرمز تلقائياً كل دقيقة.</div>
      </div>

      {#if loading && !qrUrl}
        <Icon icon={LoaderCircle} size={32} class="u-spin-icon" label="جارٍ إنشاء الرمز" />
      {:else if error}
        <div class="u-alert err">{error}</div>
      {:else}
        <div class="qr-progress">
          <svg class="countdown-ring" viewBox="0 0 100 100" aria-hidden="true">
            <circle class="ring-track" cx="50" cy="50" r="48" pathLength="100" />
            <circle class="ring-value" cx="50" cy="50" r="48" pathLength="100" stroke-dasharray={`${secondsLeft} 100`} />
          </svg>
          <div class="qr-frame">
            <img src={qrUrl} alt={`رمز حضور ${eventTitle}`} />
          </div>
        </div>
        <span class="refresh-time num">يتجدّد خلال {secondsLeft} ثانية</span>
        <p class="u-muted qr-hint">اطلب من الأعضاء مسح الرمز من صفحة الحضور.</p>
      {/if}
    </div>

    <footer class="u-modal-footer">
      <button class="u-btn u-btn-ghost" onclick={onclose}>إغلاق</button>
    </footer>
  </section>
</div>

<style>
  .u-modal-scrim { border: 0; padding: 0; }
  .u-modal-header h2 { margin: 0; font: var(--fw-bold) var(--fs-lg) var(--font-sans); display: inline-flex; align-items: center; gap: var(--sp-1); }
  .qr-body { align-items: center; text-align: center; }
  .event-title { font: var(--fw-bold) var(--fs-lg) var(--font-sans); color: var(--ink); }
  .qr-progress { width: min(100%, calc(var(--sp-8) * 5)); aspect-ratio: 1; position: relative; display: grid; place-items: center; }
  .countdown-ring { position: absolute; inset: 0; width: 100%; height: 100%; transform: rotate(-90deg); }
  .countdown-ring circle { fill: none; stroke-width: 1; }
  .ring-track { stroke: var(--line); }
  .ring-value { stroke: var(--brand); stroke-linecap: round; transition: stroke-dasharray var(--t-fast); }
  .qr-frame {
    width: calc(100% - var(--sp-4));
    padding: var(--sp-2);
    background: var(--on-brand);
    border: var(--border-w) solid var(--line);
    border-radius: calc(var(--sp-1) + var(--sp-05));
  }
  .qr-frame img { display: block; width: 100%; height: auto; }
  .refresh-time { color: var(--brand-ink); font-size: var(--fs-xs); }
  .qr-hint { margin: 0; }
</style>
