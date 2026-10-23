<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../supabase';

  let {
    onclose,
    onsuccess
  }: {
    onclose: () => void;
    onsuccess: () => void;
  } = $props();

  const readerId = `attendance-qr-reader-${Math.random().toString(36).slice(2)}`;
  let scanner: any;
  let processing = $state(false);
  let cameraReady = $state(false);
  let message = $state('وجّه الكاميرا نحو رمز الحضور.');
  let messageOk = $state(false);

  const reasonLabels: Record<string, string> = {
    invalid_payload: 'هذا الرمز غير صالح.',
    invalid_timestamp: 'وقت الرمز غير صالح.',
    expired: 'انتهت صلاحية الرمز. امسح الرمز الجديد.',
    event_not_found: 'الفعالية غير موجودة أو ملغاة.',
    too_early: 'لم يبدأ وقت تسجيل الحضور بعد.',
    too_late: 'انتهى وقت تسجيل الحضور.',
    invalid_signature: 'تعذّر التحقق من توقيع الرمز.',
    not_authenticated: 'يجب تسجيل الدخول أولاً.',
    not_allowed: 'لا تملك صلاحية تسجيل الحضور.'
  };

  async function stopScanner() {
    if (!scanner) return;
    try {
      if (scanner.isScanning) await scanner.stop();
      scanner.clear();
    } catch {
      // The camera may already be stopped after a successful scan.
    }
  }

  async function close() {
    await stopScanner();
    onclose();
  }

  async function verifyPayload(payload: string) {
    if (processing) return;
    const match = /^tawaq-qr:([0-9a-f-]{36}):(\d{12}):([0-9a-f]{8})$/i.exec(payload.trim());
    if (!match) {
      message = 'هذا ليس رمز حضور صالحاً لمنصة تواق.';
      messageOk = false;
      return;
    }

    processing = true;
    message = 'جارٍ التحقق من الرمز…';
    try {
      const { data, error } = await supabase.rpc('verify_qr', {
        p_event_id: match[1],
        p_timestamp: match[2],
        p_sig: match[3]
      });

      if (error) throw error;
      if (!data?.ok) {
        message = reasonLabels[data?.reason] || 'تعذّر تسجيل الحضور.';
        messageOk = false;
        processing = false;
        return;
      }

      message = data.status === 'late' ? '✅ تم تسجيل حضورك كمتأخر.' : '✅ تم تسجيل حضورك بنجاح.';
      messageOk = true;
      await stopScanner();
      onsuccess();
    } catch (error: any) {
      message = `فشل تسجيل الحضور: ${error?.message || 'خطأ غير متوقع'}`;
      messageOk = false;
      processing = false;
    }
  }

  onMount(() => {
    let cancelled = false;

    void (async () => {
      try {
        const { Html5Qrcode } = await import('html5-qrcode');
        if (cancelled) return;
        scanner = new Html5Qrcode(readerId);
        await scanner.start(
          { facingMode: 'environment' },
          {
            fps: 10,
            qrbox: (viewfinderWidth: number, viewfinderHeight: number) => {
              const side = Math.floor(Math.min(viewfinderWidth, viewfinderHeight) * 0.72);
              return { width: side, height: side };
            }
          },
          (decodedText: string) => void verifyPayload(decodedText),
          () => undefined
        );
        cameraReady = true;
      } catch (error: any) {
        message = `تعذّر تشغيل الكاميرا: ${error?.message || 'تحقق من إذن الكاميرا'}`;
        messageOk = false;
      }
    })();

    return () => {
      cancelled = true;
      void stopScanner();
    };
  });
</script>

<div class="u-modal" role="dialog" aria-modal="true" aria-labelledby="attendance-scan-title">
  <button class="u-modal-scrim" aria-label="إغلاق" onclick={close}></button>
  <section class="u-modal-box">
    <div class="u-sheet-handle" aria-hidden="true"></div>
    <header class="u-modal-header">
      <h2 id="attendance-scan-title">مسح رمز الحضور</h2>
      <button class="u-modal-close" aria-label="إغلاق" onclick={close}>✕</button>
    </header>

    <div class="u-modal-body u-stack">
      <div class="reader-shell" class:ready={cameraReady}>
        <div id={readerId}></div>
      </div>
      <div class="u-alert" class:ok={messageOk} class:err={!messageOk && !cameraReady}>{message}</div>
    </div>

    <footer class="u-modal-footer">
      <button class="u-btn u-btn-ghost block" onclick={close}>إغلاق</button>
    </footer>
  </section>
</div>

<style>
  .u-modal-scrim { border: 0; padding: 0; }
  .u-modal-header h2 { margin: 0; font: var(--fw-bold) var(--fs-xl) var(--font-sans); }
  .reader-shell {
    min-height: calc(var(--sp-8) * 4);
    overflow: hidden;
    border: var(--border-w) solid var(--line);
    border-radius: var(--r-xl);
    background: var(--muted-bg);
  }
  .reader-shell.ready { border-color: var(--brand); }
  .reader-shell :global(video) { border-radius: var(--r-lg); }
</style>
