<script lang="ts">
  import type { Snippet } from 'svelte';
  import Icon from './Icon.svelte';

  let { icon, title, subtitle, action }: { icon?: any; title: string; subtitle?: string; action?: Snippet } = $props();
</script>

<header class="u-page-head">
  {#if icon}<span class="page-head-icon"><Icon {icon} size={20} /></span>{/if}
  <div class="page-head-text">
    <h1>{title}</h1>
    {#if subtitle}<p>{subtitle}</p>{/if}
  </div>
  {#if action}<div class="page-head-action">{@render action()}</div>{/if}
</header>
