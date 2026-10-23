<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from './lib/supabase';
  import { session, loadProfile } from './lib/stores';
  import Login from './lib/Login.svelte';
  import Shell from './lib/Shell.svelte';

  let loading = $state(true);

  onMount(async () => {
    const { data } = await supabase.auth.getSession();
    session.set(data.session);
    if (data.session?.user?.id) await loadProfile(data.session.user.id);
    loading = false;

    supabase.auth.onAuthStateChange(async (_e, s) => {
      session.set(s);
      if (s?.user?.id) await loadProfile(s.user.id);
    });
  });
</script>

<main>
  {#if loading}
    <div class="loading">
      <div class="spinner"></div>
      <p>جارٍ التحميل…</p>
    </div>
  {:else if $session}
    <Shell />
  {:else}
    <Login />
  {/if}
</main>

<style>
  main { min-height: 100vh; display: flex; flex-direction: column; }
  .loading {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 14px;
    color: var(--ink3);
  }
  .spinner {
    width: 38px; height: 38px;
    border: 3px solid var(--gold-soft);
    border-top-color: var(--brand);
    border-radius: 50%;
    animation: spin .7s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
</style>
