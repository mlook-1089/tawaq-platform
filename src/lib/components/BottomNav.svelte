<script lang="ts">
  import { route } from '../stores';

  const items = [
    { k: 'home',       t: 'الرئيسية', i: '🏠' },
    { k: 'events',     t: 'الفعاليات', i: '📅' },
    { k: 'hosting',    t: 'المعازيب', i: '🫖' },
    { k: 'attendance', t: 'الحضور',   i: '✓' },
    { k: 'account',    t: 'حسابي',   i: '👤' }
  ];
</script>

<nav class="nav">
  {#each items as it (it.k)}
    <button
      class="item"
      class:on={$route === it.k}
      onclick={() => route.set(it.k)}
    >
      <span class="ic">{it.i}</span>
      <span class="t">{it.t}</span>
    </button>
  {/each}
</nav>

<style>
  .nav {
    position: fixed;
    bottom: 0; left: 0; right: 0;
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(16px) saturate(1.4);
    border-top: 1px solid var(--line);
    box-shadow: 0 -8px 24px rgba(14, 43, 34, 0.06);
    display: flex;
    padding: 8px 4px calc(8px + env(safe-area-inset-bottom));
    z-index: 20;
    max-width: 760px;
    margin: 0 auto;
  }
  .item {
    flex: 1;
    text-align: center;
    color: var(--ink3);
    font-size: 10px;
    font-weight: 500;
    padding: 6px 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 3px;
    cursor: pointer;
    border-radius: 12px;
    transition: all .18s cubic-bezier(.4, 0, .2, 1);
    background: transparent;
    border: none;
  }
  .ic { font-size: 19px; line-height: 1.2; }
  .item.on {
    color: var(--brand);
    background: var(--gold-soft);
    font-weight: 700;
  }
</style>
