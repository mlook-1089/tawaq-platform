<script lang="ts">
  import { ChevronLeft } from 'lucide-svelte';
  import { profile, route } from '../stores';
  import HexLogo from './HexLogo.svelte';
  import Icon from './Icon.svelte';

  function initials(name: string) {
    const parts = String(name || '').trim().split(/\s+/);
    return (parts[0] || '').charAt(0) + ((parts[1] || '').charAt(0) || '');
  }
</script>

<header class="u-topbar">
  <div class="u-brand-chip">
    <HexLogo size={24} />
    <span>تواق</span>
  </div>
  <button class="user-btn" onclick={() => route.set('account')} aria-label="فتح حسابي">
    <span class="u-avatar circle sm">{initials($profile?.full_name || 'ع')}</span>
    <Icon icon={ChevronLeft} size={15} />
  </button>
</header>

<style>
  .user-btn {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    background: transparent;
    border: none;
    padding: var(--sp-05);
    cursor: pointer;
    min-height: var(--touch);
  }
  .user-btn:focus-visible {
    outline: 2px solid var(--brand-ink);
    outline-offset: 2px;
    border-radius: var(--r-pill);
  }
</style>
