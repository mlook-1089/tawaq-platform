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

<dialog bind:this={dialog} class="overlay" aria-label={title}
  oncancel={(event) => { event.preventDefault(); close(); }}
  onclick={(event) => { if (event.target === dialog) close(); }}>
  <div class="modal">
    <div class="mh">
      <span>{title}</span>
      <button type="button" class="x" aria-label="إغلاق" disabled={busy} onclick={close}>✕</button>
    </div>
    {@render children()}
  </div>
</dialog>

<style>
  .overlay { position: fixed; inset: 0; margin: 0; padding: 0; width: 100%; height: 100%; max-width: none; max-height: none; border: none; background: var(--overlay); color: var(--ink); z-index: var(--z-modal); }
  .overlay[open] { display: flex; align-items: flex-end; justify-content: center; }
  .overlay::backdrop { background: var(--overlay); backdrop-filter: blur(2px); }
  .modal { background: var(--card); border-radius: 24px 24px 0 0; width: 100%; max-width: 620px; max-height: 92dvh; display: flex; flex-direction: column; overflow: hidden; box-shadow: var(--shadow-lg); }
  .mh { padding: 12px 20px; display: flex; gap: 12px; justify-content: space-between; align-items: center; color: var(--on-brand); background: var(--brand); font-weight: 600; font-size: 14.5px; }
  .x { background: var(--brand-2); color: var(--on-brand); border: none; min-width: var(--touch); min-height: var(--touch); border-radius: 50%; font: inherit; cursor: pointer; }
  .x:disabled { opacity: .5; cursor: wait; }
  .x:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; }
  @media (min-width: 768px) { .overlay[open] { align-items: center; padding: 20px; } .modal { border-radius: 22px; max-height: 85dvh; } }
</style>
