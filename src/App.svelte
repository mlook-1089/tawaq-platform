<script lang="ts">
  import { onMount } from 'svelte';
  import { LoaderCircle } from 'lucide-svelte';
  import { supabase } from './lib/supabase';
  import { session, profile, roles, loadProfile } from './lib/stores';
  import Login from './lib/Login.svelte';
  import Shell from './lib/Shell.svelte';
  import Icon from './lib/components/Icon.svelte';
  import PasswordResetModal from './lib/components/PasswordResetModal.svelte';
  import ToastHost from './lib/components/ToastHost.svelte';

  let loading = $state(true);
  let showPasswordReset = $state(false);

  onMount(async () => {
    // Check if URL indicates a password recovery callback
    if (typeof window !== 'undefined' && window.location.hash.includes('type=recovery')) {
      showPasswordReset = true;
    }

    const { data } = await supabase.auth.getSession();
    session.set(data.session);
    if (data.session?.user?.id) await loadProfile(data.session.user.id);
    loading = false;

    supabase.auth.onAuthStateChange(async (event, s) => {
      session.set(s);
      if (s?.user?.id) {
        await loadProfile(s.user.id);
      } else {
        profile.set(null);
        roles.set([]);
      }

      if (event === 'PASSWORD_RECOVERY') {
        showPasswordReset = true;
      }
    });
  });
</script>

{#if loading}
  <div class="app-boot">
    <Icon icon={LoaderCircle} size={32} class="u-spin-icon" />
    <p>جارٍ التحميل…</p>
  </div>
{:else if $session}
  <Shell />
  {#if showPasswordReset}
    <PasswordResetModal onclose={() => (showPasswordReset = false)} />
  {/if}
{:else}
  <Login />
  {#if showPasswordReset}
    <PasswordResetModal onclose={() => (showPasswordReset = false)} />
  {/if}
{/if}

<ToastHost />
