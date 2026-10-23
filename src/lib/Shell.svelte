<script lang="ts">
  import { route, profile } from './stores';
  import Home from './pages/Home.svelte';
  import Events from './pages/Events.svelte';
  import Hosting from './pages/Hosting.svelte';
  import Attendance from './pages/Attendance.svelte';
  import Account from './pages/Account.svelte';
  import TopBar from './components/TopBar.svelte';
  import BottomNav from './components/BottomNav.svelte';
</script>

<div class="shell">
  <TopBar />
  <main class="content">
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

<style>
  .shell {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    background: var(--bg);
    max-width: 760px;
    margin: 0 auto;
    width: 100%;
    position: relative;
  }
  .content {
    flex: 1;
    padding: 14px 18px calc(80px + env(safe-area-inset-bottom));
  }
</style>
