<script lang="ts">
  import { toasts, confirmState } from '../toast';
  import { AlertTriangle, Check, Info, XCircle } from 'lucide-svelte';
  import Icon from './Icon.svelte';

  function iconFor(kind: string) {
    switch (kind) {
      case 'ok':   return Check;
      case 'warn': return AlertTriangle;
      case 'err':  return XCircle;
      default:     return Info;
    }
  }

  function resolveConfirm(ok: boolean) {
    const c = $confirmState;
    if (!c) return;
    confirmState.set(null);
    c.resolve(ok);
  }
</script>

<div class="toast-stack" aria-live="polite" aria-atomic="false">
  {#each $toasts as t (t.id)}
    <div class="toast {t.kind}" role="status">
      <Icon icon={iconFor(t.kind)} size={16} />
      <span>{t.text}</span>
    </div>
  {/each}
</div>

{#if $confirmState}
  <div
    class="confirm-wrap"
    role="presentation"
    onclick={() => resolveConfirm(false)}
    onkeydown={(e) => e.key === 'Escape' && resolveConfirm(false)}
  >
    <div class="confirm-scrim"></div>
    <div
      class="confirm-box"
      role="dialog"
      aria-modal="true"
      aria-labelledby="confirm-title"
      tabindex="-1"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
    >
      <div class="confirm-h" id="confirm-title">{$confirmState.title}</div>
      {#if $confirmState.message}
        <p class="confirm-msg">{$confirmState.message}</p>
      {/if}
      <div class="confirm-actions">
        <button class="u-btn u-btn-ghost" onclick={() => resolveConfirm(false)}>
          {$confirmState.cancelLabel || 'إلغاء'}
        </button>
        <button
          class="u-btn {$confirmState.danger ? 'u-btn-danger' : 'u-btn-primary'}"
          onclick={() => resolveConfirm(true)}
        >
          {$confirmState.confirmLabel || 'تأكيد'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .toast-stack {
    position: fixed;
    bottom: calc(var(--nav-h, 64px) + var(--sp-3) + env(safe-area-inset-bottom, 0));
    left: 50%;
    transform: translateX(-50%);
    z-index: var(--z-toast, 9999);
    display: flex;
    flex-direction: column;
    gap: var(--sp-1);
    pointer-events: none;
    width: calc(100% - var(--sp-4) * 2);
    max-width: 420px;
  }
  .toast {
    pointer-events: auto;
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    padding: 10px var(--sp-2);
    background: var(--brand);
    color: var(--on-brand);
    border-radius: var(--r-md);
    box-shadow: var(--shadow-lg);
    font: var(--fw-semi) var(--fs-sm) var(--font-sans);
    animation: toast-in var(--t-base, 220ms) ease-out;
  }
  .toast.ok   { background: var(--ok); }
  .toast.warn { background: var(--warn); }
  .toast.err  { background: var(--bad); }
  @keyframes toast-in {
    from { opacity: 0; transform: translateY(8px); }
    to   { opacity: 1; transform: translateY(0); }
  }

  .confirm-wrap {
    position: fixed;
    inset: 0;
    z-index: var(--z-modal, 9000);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--sp-3);
    animation: fade-in var(--t-base, 220ms);
  }
  .confirm-scrim {
    position: absolute;
    inset: 0;
    background: var(--overlay);
  }
  .confirm-box {
    position: relative;
    background: var(--card);
    border-radius: var(--r-2xl);
    max-width: 400px;
    width: 100%;
    padding: var(--sp-3);
    box-shadow: var(--shadow-lg);
    animation: scale-in var(--t-base, 220ms);
  }
  .confirm-h {
    font: var(--fw-bold) var(--fs-md) var(--font-sans);
    color: var(--ink);
    margin-bottom: var(--sp-1);
  }
  .confirm-msg {
    color: var(--ink2);
    font-size: var(--fs-sm);
    margin: 0 0 var(--sp-3);
    line-height: 1.5;
  }
  .confirm-actions {
    display: flex;
    gap: var(--sp-2);
    justify-content: flex-end;
  }
  @keyframes fade-in {
    from { opacity: 0 } to { opacity: 1 }
  }
  @keyframes scale-in {
    from { opacity: 0; transform: scale(.96) }
    to   { opacity: 1; transform: scale(1) }
  }
</style>
