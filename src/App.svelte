<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from './lib/supabase';
  import Login from './lib/Login.svelte';
  import Welcome from './lib/Welcome.svelte';

  let session = $state<any>(null);
  let loading = $state(true);

  onMount(async () => {
    const { data } = await supabase.auth.getSession();
    session = data.session;
    loading = false;

    supabase.auth.onAuthStateChange((_evt, s) => {
      session = s;
    });
  });
</script>

<main>
  {#if loading}
    <div class="loading">
      <div class="spinner"></div>
      <p>جارٍ التحميل…</p>
    </div>
  {:else if session}
    <Welcome {session} />
  {:else}
    <Login />
  {/if}
</main>

<style>
  main { flex: 1; display: flex; flex-direction: column; }
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
