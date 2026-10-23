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

<nav class="u-nav" aria-label="التنقل الرئيسي">
  {#each items as it (it.k)}
    <button
      class="u-nav-item"
      class:on={$route === it.k}
      onclick={() => route.set(it.k)}
      aria-current={$route === it.k ? 'page' : undefined}
    >
      <span class="ic" aria-hidden="true">{it.i}</span>
      <span class="t">{it.t}</span>
    </button>
  {/each}
</nav>
