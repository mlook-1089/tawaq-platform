<script lang="ts">
  import { CalendarDays, House, UserCheck, Users, CircleUserRound } from 'lucide-svelte';
  import { route } from '../stores';
  import Icon from './Icon.svelte';

  const items = [
    { k: 'home',       t: 'الرئيسية', icon: House },
    { k: 'events',     t: 'الفعاليات', icon: CalendarDays },
    { k: 'hosting',    t: 'المعازيب', icon: Users },
    { k: 'attendance', t: 'الحضور',   icon: UserCheck },
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
      <span class="nav-icon"><Icon icon={it.icon} size={22} strokeWidth={1.75} /></span>
      <span class="nav-dot" aria-hidden="true"></span>
      <span class="t">{it.t}</span>
    </button>
  {/each}
</nav>
