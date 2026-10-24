<script lang="ts">
  import {
    CalendarDays,
    CircleUserRound,
    Contact,
    House,
    UserCheck
  } from 'lucide-svelte';
  import { route } from '../stores';
  import Icon from './Icon.svelte';

  const items = [
    { k: 'home',       t: 'الرئيسية', icon: House },
    { k: 'events',     t: 'الفعاليات', icon: CalendarDays },
    { k: 'attendance', t: 'الحضور',   icon: UserCheck },
    { k: 'members',    t: 'الأعضاء',  icon: Contact },
    { k: 'account',    t: 'حسابي',    icon: CircleUserRound }
  ];
</script>

<nav class="u-nav" aria-label="التنقل الرئيسي">
  {#each items as it (it.k)}
    <button
      class:on={$route === it.k}
      onclick={() => route.set(it.k)}
      aria-current={$route === it.k ? 'page' : undefined}
    >
      <span class="ic"><Icon icon={it.icon} size={22} strokeWidth={1.8} /></span>
      <span>{it.t}</span>
    </button>
  {/each}
</nav>
