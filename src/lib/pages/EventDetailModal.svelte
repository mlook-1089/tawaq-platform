<script lang="ts">
  import { Calendar, Clock, ExternalLink, MapPin, X } from 'lucide-svelte';
  import { fmtDate, fmtTime, hijriDate, EVENT_TYPES } from '../utils';
  import Icon from '../components/Icon.svelte';
  import CommentThread from '../components/CommentThread.svelte';

  let {
    event,
    onclose
  }: {
    event: any;
    onclose: () => void;
  } = $props();

  const typeConfig = $derived(EVENT_TYPES[event.type] || { label: event.type, color: 'var(--brand)' });
</script>

<div class="u-modal" onclick={onclose} onkeydown={(e) => e.key === 'Escape' && onclose()} role="presentation">
  <div class="u-modal-scrim"></div>
  <div class="u-modal-box wide" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
    <div class="u-sheet-handle"></div>
    <div class="u-modal-header">
      <div class="header-type-line">
        <span class="type-dot" style={`background: ${typeConfig.color};`}></span>
        <span>{typeConfig.label}</span>
      </div>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق"><Icon icon={X} /></button>
    </div>

    <div class="u-modal-body">
      <h1 class="event-modal-title">{event.title}</h1>

      <div class="event-meta-box">
        <div class="meta-row">
          <Icon icon={Calendar} size={16} />
          <span>{fmtDate(event.start_datetime)}</span>
          <span class="hijri">({hijriDate(event.start_datetime)})</span>
        </div>
        <div class="meta-row">
          <Icon icon={Clock} size={16} />
          <span>من {fmtTime(event.start_datetime)} {event.end_datetime ? `إلى ${fmtTime(event.end_datetime)}` : ''}</span>
        </div>
        {#if event.location_name}
          <div class="meta-row">
            <Icon icon={MapPin} size={16} />
            <span>{event.location_name}</span>
            {#if event.maps_url}
              <a href={event.maps_url} target="_blank" rel="noopener noreferrer" class="maps-link">
                <Icon icon={ExternalLink} size={13} />
                <span>الخرائط</span>
              </a>
            {/if}
          </div>
        {/if}
      </div>

      {#if event.description}
        <div class="desc-box">
          <p>{event.description}</p>
        </div>
      {/if}

      <!-- Comments Thread for Event -->
      <CommentThread entity_type="event" entity_id={event.id} />
    </div>

    <div class="u-modal-footer">
      <button type="button" class="u-btn u-btn-ghost" onclick={onclose}>إغلاق</button>
    </div>
  </div>
</div>

<style>
  .header-type-line {
    display: inline-flex;
    align-items: center;
    gap: var(--sp-1);
    font-size: var(--fs-sm);
  }
  .type-dot {
    width: 10px;
    height: 10px;
    border-radius: var(--r-pill);
  }
  .event-modal-title {
    margin: 0 0 var(--sp-2);
    font: var(--fw-bold) var(--fs-xl)/1.3 var(--font-sans);
    color: var(--ink);
  }
  .event-meta-box {
    display: flex;
    flex-direction: column;
    gap: var(--sp-1);
    background: var(--muted-bg);
    border-radius: var(--r-md);
    padding: var(--sp-2) var(--sp-3);
    margin-bottom: var(--sp-2);
    font-size: var(--fs-sm);
  }
  .meta-row {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    color: var(--ink2);
    flex-wrap: wrap;
  }
  .hijri {
    color: var(--ink3);
    font-size: var(--fs-xs);
  }
  .maps-link {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    color: var(--brand);
    font-weight: var(--fw-semi);
    text-decoration: none;
    margin-inline-start: var(--sp-1);
  }
  .maps-link:hover {
    text-decoration: underline;
  }
  .desc-box {
    margin-bottom: var(--sp-2);
    font-size: var(--fs-sm);
    color: var(--ink);
    line-height: var(--lh-base);
  }
  .desc-box p {
    margin: 0;
  }
</style>
