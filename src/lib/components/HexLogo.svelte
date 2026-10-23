<script lang="ts">
  let { size = 28, label = 'تواق' }: { size?: number | string; label?: string } = $props();
</script>

<svg class="hex-logo" width={size} height={size} viewBox="0 0 32 32" role="img" aria-label={label}>
  <path d="M16 2.75 27.5 9.3v13.4L16 29.25 4.5 22.7V9.3L16 2.75Z" fill="var(--brand-soft)" stroke="var(--brand)" stroke-width="1.5" />
  <text x="16" y="20.1" text-anchor="middle" fill="var(--brand)" font-family="var(--font-sans)" font-size="13" font-weight="700">ت</text>
</svg>

<style>
  .hex-logo { display: block; flex: none; }
</style>
