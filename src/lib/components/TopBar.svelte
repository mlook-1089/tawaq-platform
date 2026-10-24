<script lang="ts">
  import { profile, route } from '../stores';
  import HexLogo from './HexLogo.svelte';
  import Avatar from './Avatar.svelte';

  const firstName = $derived(($profile?.full_name || 'عضو').split(' ')[0]);
</script>

<header class="u-header">
  <button class="u-brand" onclick={() => route.set('home')} aria-label="الرئيسية">
    <HexLogo size={24} />
  </button>
  <div class="u-hinfo">
    <div class="u-hname">مجموعة تواق</div>
    <div class="u-hsub">أهلاً، {firstName}</div>
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
  :global(.u-header .u-brand) {
    background: transparent;
    border: 0;
    padding: 0;
    cursor: pointer;
  }
  .user-btn {
    background: transparent;
    border: 0;
    padding: 0;
    cursor: pointer;
    display: flex;
    align-items: center;
    flex-shrink: 0;
  }
</style>
