<script lang="ts">
  import { route } from './stores';
  import Home from './pages/Home.svelte';
  import Events from './pages/Events.svelte';
  import Hosting from './pages/Hosting.svelte';
  import Attendance from './pages/Attendance.svelte';
  import Account from './pages/Account.svelte';
  import TopBar from './components/TopBar.svelte';
  import BottomNav from './components/BottomNav.svelte';
</script>

<div class="u-shell">
  <TopBar />
  <main class="u-page">
    {#if $route === 'home'}
      <Home />
    {:else if $route === 'events'}
      <Events />
    {:else if $route === 'hosting'}
      <Hosting />
    {:else if $route === 'attendance'}
      <Attendance />
    {:else if $route === 'account'}
      <Account />
    {/if}
  </main>
  <BottomNav />
</div>
