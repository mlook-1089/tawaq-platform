<script lang="ts">
  import { onMount, type Snippet } from 'svelte';
  let { title, busy = false, onclose, children }: {
    title: string; busy?: boolean; onclose: () => void; children: Snippet;
  } = $props();
  let dialog: HTMLDialogElement;
  onMount(() => {
    const previousFocus = document.activeElement as HTMLElement | null;
    const overflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    dialog.showModal();
    return () => {
      dialog.close();
      document.body.style.overflow = overflow;
      previousFocus?.focus();
    };
  });
  function close() { if (!busy) onclose(); }
</script>

<dialog bind:this={dialog} class="dlg" aria-label={title}
  oncancel={(event) => { event.preventDefault(); close(); }}
  onclick={(event) => { if (event.target === dialog) close(); }}>
  <div class="u-modal-box wide">
    <div class="u-sheet-handle"></div>
    <div class="u-modal-header">
      <span>{title}</span>
      <button type="button" class="u-modal-close" aria-label="إغلاق" disabled={busy} onclick={close}>✕</button>
    </div>
    {@render children()}
  </div>
</dialog>

<style>
  .dlg {
    position: fixed;
    inset: 0;
    margin: 0;
    padding: 0;
    width: 100%;
    height: 100%;
    max-width: none;
    max-height: none;
    border: none;
    background: transparent;
    color: var(--ink);
    z-index: var(--z-modal);
  }
  .dlg[open] {
    display: flex;
    align-items: flex-end;
    justify-content: center;
  }
  .dlg::backdrop {
    background: var(--overlay);
    backdrop-filter: blur(2px);
  }
  @media (min-width: 768px) {
    .dlg[open] { align-items: center; padding: var(--sp-3); }
  }
</style>
