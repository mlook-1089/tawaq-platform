<script lang="ts">
  import Icon from './Icon.svelte';

  let { icon, title, subtitle }: { icon?: any; title: string; subtitle?: string } = $props();
</script>

<header class="u-page-head">
  {#if icon}<span class="page-head-icon"><Icon {icon} size={20} /></span>{/if}
  <div>
    <h1>{title}</h1>
    {#if subtitle}<p>{subtitle}</p>{/if}
  </div>
</header>
