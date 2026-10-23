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

{#if loading}
  <div class="app-boot">
    <span class="u-spinner lg">
      <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/></svg>
    </span>
    <p>جارٍ التحميل…</p>
  </div>
{:else if $session}
  <Shell />
{:else}
  <Login />
{/if}
