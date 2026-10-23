<script lang="ts">
  let { kind = 'generic' }: { kind?: 'calendar' | 'attendance' | 'hosting' | 'generic' } = $props();
</script>

{#snippet EmptyCalendar()}
  <svg class="empty-art" viewBox="0 0 120 120" aria-hidden="true">
    <rect x="25" y="29" width="70" height="66" rx="10" fill="var(--brand-soft)" stroke="var(--line2)" stroke-width="2" />
    <path d="M25 49h70M43 22v14M77 22v14" fill="none" stroke="var(--brand-ink)" stroke-width="2" stroke-linecap="round" />
    <path d="M43 65h9M67 65h9M43 80h9M67 80h9" fill="none" stroke="var(--line2)" stroke-width="4" stroke-linecap="round" />
  </svg>
{/snippet}

{#snippet EmptyAttendance()}
  <svg class="empty-art" viewBox="0 0 120 120" aria-hidden="true">
    <circle cx="60" cy="58" r="35" fill="var(--brand-soft)" stroke="var(--line2)" stroke-width="2" />
    <circle cx="60" cy="48" r="10" fill="none" stroke="var(--brand-ink)" stroke-width="2" />
    <path d="M41 79c3-11 10-17 19-17s16 6 19 17M77 36l5 5 10-12" fill="none" stroke="var(--brand-ink)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
  </svg>
{/snippet}

{#snippet EmptyHosting()}
  <svg class="empty-art" viewBox="0 0 120 120" aria-hidden="true">
    <path d="M27 61h66v25a9 9 0 0 1-9 9H36a9 9 0 0 1-9-9V61Z" fill="var(--brand-soft)" stroke="var(--line2)" stroke-width="2" />
    <path d="M38 61V45a22 22 0 0 1 44 0v16M47 45a13 13 0 0 1 26 0M60 20v8" fill="none" stroke="var(--brand-ink)" stroke-width="2" stroke-linecap="round" />
    <path d="M42 77h36" fill="none" stroke="var(--line2)" stroke-width="3" stroke-linecap="round" />
  </svg>
{/snippet}

{#snippet EmptyGeneric()}
  <svg class="empty-art" viewBox="0 0 120 120" aria-hidden="true">
    <path d="m60 19 35 20v41L60 101 25 80V39l35-20Z" fill="var(--brand-soft)" stroke="var(--line2)" stroke-width="2" />
    <path d="m60 37 19 11v22L60 81 41 70V48l19-11Z" fill="none" stroke="var(--brand-ink)" stroke-width="2" />
    <path d="M49 59h22" fill="none" stroke="var(--brand-ink)" stroke-width="2" stroke-linecap="round" />
  </svg>
{/snippet}

{#if kind === 'calendar'}
  {@render EmptyCalendar()}
{:else if kind === 'attendance'}
  {@render EmptyAttendance()}
{:else if kind === 'hosting'}
  {@render EmptyHosting()}
{:else}
  {@render EmptyGeneric()}
{/if}

<style>
  .empty-art { width: calc(var(--sp-8) * 2); height: calc(var(--sp-8) * 2); display: block; }
</style>
