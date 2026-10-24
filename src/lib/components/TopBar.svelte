<script lang="ts">
  import { onMount } from 'svelte';
  import { profile, route } from '../stores';
  import HexLogo from './HexLogo.svelte';
  import Avatar from './Avatar.svelte';

  onMount(() => {
    const onScroll = () => {
      document.body.classList.toggle('scrolled', window.scrollY > 0);
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  });
</script>

<header class="u-topbar">
  <button class="u-brand-chip-btn" onclick={() => route.set('home')} aria-label="الرئيسية">
    <div class="u-brand-chip">
      <HexLogo size={24} />
      <span>تواق</span>
    </div>
  </button>
  <button class="user-btn" onclick={() => route.set('account')} aria-label="فتح حسابي">
    <Avatar
      url={$profile?.avatar_url}
      name={$profile?.full_name || 'ع'}
      size="sm"
      circle={true}
    />
  </button>
</header>

<style>
  :global(.u-topbar) {
    min-height: 56px;
  }
  .u-brand-chip-btn {
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    font: inherit;
    text-align: inherit;
  }
  .u-brand-chip-btn:focus-visible {
    outline: 2px solid var(--brand-ink);
    outline-offset: 2px;
    border-radius: var(--r-pill);
  }
  .user-btn {
    display: flex;
    align-items: center;
    background: transparent;
    border: none;
    cursor: pointer;
    min-height: var(--touch);
  }
  .user-btn:focus-visible {
    outline: 2px solid var(--brand-ink);
    outline-offset: 2px;
    border-radius: var(--r-pill);
  }
</style>
