<script lang="ts">
  let { icon, title }: { icon: string; title: string } = $props();
</script>

<div class="page-head">
  <div class="icbox">{icon}</div>
  <h1>{title}</h1>
</div>

<style>
  .page-head {
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: 18px;
    padding: 16px 18px;
    display: flex;
    align-items: center;
    gap: 13px;
    margin-bottom: 16px;
    box-shadow: var(--shadow);
  }
  .icbox {
    width: 42px; height: 42px;
    border-radius: 13px;
    background: var(--brand);
    color: var(--on-brand);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 19px;
  }
  h1 {
    font-size: 16.5px;
    font-weight: 700;
    color: var(--brand);
    letter-spacing: .1px;
    margin: 0;
  }
</style>
