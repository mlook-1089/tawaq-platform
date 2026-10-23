<script lang="ts">
  let {
    icon: Glyph,
    size = 18,
    strokeWidth = 1.75,
    label,
    class: className = ''
  }: {
    icon: any;
    size?: number | string;
    strokeWidth?: number | string;
    label?: string;
    class?: string;
  } = $props();
</script>

<Glyph
  {size}
  {strokeWidth}
  class={className}
  aria-hidden={label ? undefined : 'true'}
  aria-label={label}
/>
