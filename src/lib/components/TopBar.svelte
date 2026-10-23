<script lang="ts">
  import { profile, route } from '../stores';
  import HexLogo from './HexLogo.svelte';
  import Avatar from './Avatar.svelte';
</script>

<header class="u-topbar">
  <div class="u-brand-chip">
    <HexLogo size={24} />
    <span>تواق</span>
  </div>
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
