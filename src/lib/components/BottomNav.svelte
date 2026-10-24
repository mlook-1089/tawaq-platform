<script lang="ts">
  import {
    CalendarDays,
    CircleUserRound,
    Contact,
    House,
    UserCheck,
    Users
  } from 'lucide-svelte';
  import { route } from '../stores';
  import Icon from './Icon.svelte';

  const items = [
    { k: 'home',       t: 'الرئيسية', icon: House },
    { k: 'events',     t: 'الفعاليات', icon: CalendarDays },
    { k: 'hosting',    t: 'المعازيب', icon: Users },
    { k: 'attendance', t: 'الحضور',   icon: UserCheck },
    { k: 'members',    t: 'الأعضاء',  icon: Contact },
    { k: 'account',    t: 'حسابي',    icon: CircleUserRound }
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
      <span class="nav-icon"><Icon icon={it.icon} size={20} strokeWidth={1.75} /></span>
      <span class="nav-dot" aria-hidden="true"></span>
      <span class="t">{it.t}</span>
    </button>
  {/each}
</nav>

<style>
  :global(.u-nav) {
    overflow-x: auto;
    scrollbar-width: none;
    -webkit-overflow-scrolling: touch;
  }
  :global(.u-nav::-webkit-scrollbar) {
    display: none;
  }
  :global(.u-nav-item) {
    min-width: 58px;
    flex: 1 0 auto;
    position: relative;
    color: color-mix(in oklab, var(--on-brand) 58%, transparent);
  }
  /* Active gold indicator dot */
  :global(.u-nav-item.on)::after {
    content: '';
    position: absolute;
    bottom: 2px;
    left: 50%;
    transform: translateX(-50%);
    width: 20px;
    height: 3px;
    background: var(--gold);
    border-radius: var(--r-pill);
  }
  /* Active icon highlight */
  :global(.u-nav-item.on .nav-icon) {
    background: color-mix(in oklab, var(--on-brand) 12%, transparent);
    color: var(--on-brand);
  }
  :global(.u-nav-item.on) {
    color: var(--on-brand);
    font-weight: var(--fw-bold);
  }
  :global(.u-nav-item.on .nav-dot) {
    display: none; /* replaced by ::after gold indicator */
  }
  /* Tactile scale on press */
  :global(.u-nav-item:active) {
    transform: scale(0.92);
  }
</style>
