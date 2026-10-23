<script lang="ts">
  let { icon, title }: { icon: string; title: string } = $props();
</script>

<header class="u-page-head">
  <div class="ic" aria-hidden="true">{icon}</div>
  <h1>{title}</h1>
</header>
