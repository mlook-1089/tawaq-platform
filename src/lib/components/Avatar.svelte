<script lang="ts">
  import { initials } from '../utils';

  let {
    url = null,
    name = '',
    size = 'md',
    hex = false,
    circle = true,
    featured = false,
    class: className = ''
  }: {
    url?: string | null;
    name?: string;
    size?: 'sm' | 'md' | 'lg' | 'xl';
    hex?: boolean;
    circle?: boolean;
    featured?: boolean;
    class?: string;
  } = $props();

  let imgFailed = $state(false);

  // Reset imgFailed if url changes
  $effect(() => {
    if (url) imgFailed = false;
  });
</script>

{#if hex}
  <div class="hex-avatar {size === 'lg' ? 'lg' : ''} {featured ? 'featured' : ''} {className}">
    {#if url && !imgFailed}
      <img src={url} alt={name} onerror={() => (imgFailed = true)} />
    {:else}
      <span class="initials">{initials(name)}</span>
    {/if}
  </div>
{:else}
  <div
    class="u-avatar {circle ? 'circle' : 'square'} {size} {url && !imgFailed ? '' : 'u-avatar-brand'} {className}"
  >
    {#if url && !imgFailed}
      <img
        src={url}
        alt={name}
        class="avatar-img"
        onerror={() => (imgFailed = true)}
      />
    {:else}
      <span class="avatar-initials">{initials(name)}</span>
    {/if}
  </div>
{/if}

<style>
  .avatar-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: inherit;
  }
  .avatar-initials {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    line-height: 1;
  }
</style>
