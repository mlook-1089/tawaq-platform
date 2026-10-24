<script lang="ts">
  import { onMount } from 'svelte';
  import {
    ChevronDown,
    ChevronUp,
    Plus,
    Shield,
    Trash2
  } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { session, roles, isAdmin } from '../stores';
  import { timeAgo } from '../utils';
  import { confirmDialog, toastErr, toastOk } from '../toast';
  import Icon from '../components/Icon.svelte';
  import Avatar from '../components/Avatar.svelte';
  import EmptyIllustrations from '../components/EmptyIllustrations.svelte';
  import CommentThread from '../components/CommentThread.svelte';
  import SuggestionFormModal from './SuggestionFormModal.svelte';

  const user = $derived($session?.user);
  const canDecide = $derived(
    $isAdmin || $roles.some(r => r.startsWith('mod_'))
  );

  interface Suggestion {
    id: string;
    user_id: string;
    type: 'event' | 'location' | 'feature' | 'general';
    title: string;
    description: string | null;
    status: 'open' | 'under_review' | 'accepted' | 'rejected' | 'implemented';
    decision_note: string | null;
    created_at: string;
    author?: {
      id: string;
      full_name: string;
      avatar_url: string | null;
    };
    score: number;
    myVote: number; // 1, -1, 0
  }

  let suggestions = $state<Suggestion[]>([]);
  let loading = $state(true);
  let error = $state('');
  let filterType = $state('all');
  let showCreateModal = $state(false);

  // Status editing modal / dropdown
  let editingStatusId = $state<string | null>(null);
  let newStatusVal = $state<string>('open');
  let decisionNoteVal = $state('');
  let savingStatus = $state(false);

  const typeConfig: Record<string, { label: string; pill: string }> = {
    event:    { label: 'فعالية',        pill: 'brand' },
    location: { label: 'موقع / استراحة', pill: 'gold' },
    feature:  { label: 'ميزة بالمنصة',   pill: 'info' },
    general:  { label: 'عام',          pill: 'warn' }
  };

  const statusConfig: Record<string, { label: string; pill: string }> = {
    open:         { label: 'مفتوح',       pill: 'brand' },
    under_review: { label: 'قيد الدراسة', pill: 'warn' },
    accepted:     { label: 'مقبول',       pill: 'ok' },
    rejected:     { label: 'مرفوض',       pill: 'bad' },
    implemented:  { label: 'تم التنفيذ',  pill: 'ok' }
  };

  async function loadData() {
    loading = true;
    error = '';
    try {
      const [{ data: sugData, error: sErr }, { data: voteData, error: vErr }] = await Promise.all([
        supabase
          .from('suggestions')
          .select('*, author:users!suggestions_user_id_fkey(id, full_name, avatar_url)')
          .is('deleted_at', null)
          .order('created_at', { ascending: false }),
        supabase
          .from('suggestion_votes')
          .select('suggestion_id, user_id, vote')
      ]);

      if (sErr) {
        // Fallback without FK
        const { data: raw, error: rawErr } = await supabase
          .from('suggestions')
          .select('*')
          .is('deleted_at', null)
          .order('created_at', { ascending: false });
        if (rawErr) throw rawErr;
        compileSuggestions(raw || [], voteData || []);
      } else {
        compileSuggestions(sugData || [], voteData || []);
      }
    } catch (e: any) {
      error = e.message || 'تعذّر تحميل الاقتراحات';
    } finally {
      loading = false;
    }
  }

  function compileSuggestions(sugList: any[], voteList: any[]) {
    const scores = new Map<string, number>();
    const myVotes = new Map<string, number>();

    for (const v of voteList) {
      scores.set(v.suggestion_id, (scores.get(v.suggestion_id) || 0) + Number(v.vote || 0));
      if (user && v.user_id === user.id) {
        myVotes.set(v.suggestion_id, Number(v.vote));
      }
    }

    suggestions = sugList.map((s: any) => ({
      ...s,
      score: scores.get(s.id) || 0,
      myVote: myVotes.get(s.id) || 0
    })).sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
    });
  }

  onMount(loadData);

  // Voting action
  async function vote(suggestion: Suggestion, direction: 1 | -1) {
    if (!user) return;

    const currentVote = suggestion.myVote;
    let newVote = 0;
    if (currentVote === direction) {
      // Toggle off
      newVote = 0;
    } else {
      newVote = direction;
    }

    // Optimistic update
    const diff = newVote - currentVote;
    suggestion.score += diff;
    suggestion.myVote = newVote;

    try {
      if (newVote === 0) {
        await supabase
          .from('suggestion_votes')
          .delete()
          .eq('suggestion_id', suggestion.id)
          .eq('user_id', user.id);
      } else {
        await supabase
          .from('suggestion_votes')
          .upsert({
            suggestion_id: suggestion.id,
            user_id: user.id,
            vote: newVote
          });
      }
    } catch {
      // Revert on error
      suggestion.score -= diff;
      suggestion.myVote = currentVote;
    }
  }

  async function saveStatusChange(suggestionId: string) {
    if (!canDecide) return;
    savingStatus = true;
    try {
      const updates: any = {
        status: newStatusVal,
        decided_by: user?.id,
        decided_at: new Date().toISOString()
      };
      if (decisionNoteVal.trim()) {
        updates.decision_note = decisionNoteVal.trim();
      }

      const { error: err } = await supabase
        .from('suggestions')
        .update(updates)
        .eq('id', suggestionId);

      if (err) throw err;

      editingStatusId = null;
      decisionNoteVal = '';
      await loadData();
    } catch (e: any) {
      toastErr(e.message || 'تعذّر تحديث حالة الاقتراح');
    } finally {
      savingStatus = false;
    }
  }

  async function deleteSuggestion(id: string) {
    const ok = await confirmDialog({
      title: 'حذف الاقتراح',
      message: 'لن يمكن استرجاع هذا الاقتراح بعد الحذف.',
      confirmLabel: 'حذف',
      danger: true
    });
    if (!ok) return;
    try {
      const { error: err } = await supabase
        .from('suggestions')
        .update({ deleted_at: new Date().toISOString() })
        .eq('id', id);
      if (err) throw err;
      toastOk('تم حذف الاقتراح');
      await loadData();
    } catch (e: any) {
      toastErr(e.message || 'تعذّر حذف الاقتراح');
    }
  }

  const filteredSuggestions = $derived.by(() => {
    if (filterType === 'all') return suggestions;
    return suggestions.filter(s => s.type === filterType);
  });

  const typeCounts = $derived.by(() => {
    const c: Record<string, number> = {};
    for (const s of suggestions) {
      c[s.type] = (c[s.type] || 0) + 1;
    }
    return c;
  });
</script>

<div class="u-page">
  <div class="u-top">
    <div>
      <div class="u-sub">{suggestions.length} اقتراح</div>
      <h1>اقتراحاتنا</h1>
    </div>
    <div class="u-actions">
      <button class="u-btn u-btn-primary sm" onclick={() => (showCreateModal = true)}>
        <Icon icon={Plus} size={15} /> اقتراح
      </button>
    </div>
  </div>

  <div class="u-chips">
    <button
      class="u-chip"
      class:on={filterType === 'all'}
      onclick={() => (filterType = 'all')}
    >
      الكل <span class="chip-count">{suggestions.length}</span>
    </button>
    {#each Object.entries(typeConfig) as [k, v] (k)}
      <button
        class="u-chip"
        class:on={filterType === k}
        onclick={() => (filterType = k)}
      >
        {v.label} <span class="chip-count">{typeCounts[k] || 0}</span>
      </button>
    {/each}
  </div>

  {#if loading}
    <div class="suggestions-list">
      <div class="u-skel sug-skel"></div>
      <div class="u-skel sug-skel"></div>
      <div class="u-skel sug-skel"></div>
    </div>
  {:else if error}
    <div class="u-alert err">{error}</div>
  {:else if filteredSuggestions.length === 0}
    <div class="u-empty">
      <EmptyIllustrations kind="generic" />
      <h3>لا توجد اقتراحات بعد</h3>
      <p>شارك فكرتك الأولى واجعل الأعضاء يصوتون عليها!</p>
    </div>
  {:else}
    <div class="suggestions-list">
    {#each filteredSuggestions as s (s.id)}
      {@const typeCfg = typeConfig[s.type] || { label: s.type, pill: '' }}
      {@const statCfg = statusConfig[s.status] || { label: s.status, pill: '' }}
      {@const isAuthor = user && s.user_id === user.id}

      <article class="u-card suggestion-card">
        <div class="sug-layout">
          <!-- Voting Arrows Column -->
          <div class="vote-col">
            <button
              type="button"
              class="vote-btn"
              class:up-voted={s.myVote === 1}
              onclick={() => vote(s, 1)}
              title="تصويت إيجابي"
              aria-label="تصويت إيجابي"
            >
              <Icon icon={ChevronUp} size={20} />
            </button>
            <span class="vote-count tab-num" class:positive={s.score > 0} class:negative={s.score < 0}>
              {s.score}
            </span>
            <button
              type="button"
              class="vote-btn"
              class:down-voted={s.myVote === -1}
              onclick={() => vote(s, -1)}
              title="تصويت سلبي"
              aria-label="تصويت سلبي"
            >
              <Icon icon={ChevronDown} size={20} />
            </button>
          </div>

          <!-- Main Content Column -->
          <div class="sug-main">
            <div class="sug-header">
              <span class="u-pill {typeCfg.pill}">{typeCfg.label}</span>
              <span class="u-pill {statCfg.pill}">{statCfg.label}</span>

              {#if isAuthor && s.status === 'open'}
                <button
                  type="button"
                  class="u-btn-icon sm rm-sug-btn"
                  onclick={() => deleteSuggestion(s.id)}
                  title="حذف"
                >
                  <Icon icon={Trash2} size={13} />
                </button>
              {/if}
            </div>

            <h2 class="sug-title">{s.title}</h2>

            {#if s.description}
              <p class="sug-desc">{s.description}</p>
            {/if}

            {#if s.decision_note}
              <div class="decision-note-box">
                <span class="decision-lbl">رد الإدارة:</span>
                <span>"{s.decision_note}"</span>
              </div>
            {/if}

            <div class="sug-meta-row">
              <div class="author-cell">
                <Avatar url={s.author?.avatar_url} name={s.author?.full_name || 'ع'} size="sm" circle={true} />
                <span class="author-name">{s.author?.full_name || 'عضو'}</span>
              </div>
              <span class="meta-date">{timeAgo(s.created_at)}</span>

              {#if canDecide}
                <button
                  type="button"
                  class="admin-edit-status-btn"
                  onclick={() => {
                    editingStatusId = editingStatusId === s.id ? null : s.id;
                    newStatusVal = s.status;
                    decisionNoteVal = s.decision_note || '';
                  }}
                >
                  <Icon icon={Shield} size={13} />
                  <span>تغيير الحالة</span>
                </button>
              {/if}
            </div>

            <!-- Admin Status Change Subform -->
            {#if editingStatusId === s.id}
              <div class="status-change-box">
                <div class="status-box-head">تحديث حالة الاقتراح:</div>
                <div class="status-inputs-grid">
                  <div class="u-field">
                    <label for={`stat-sel-${s.id}`} class="u-field-label">الحالة</label>
                    <select id={`stat-sel-${s.id}`} class="u-input u-select" bind:value={newStatusVal}>
                      {#each Object.entries(statusConfig) as [k, v]}
                        <option value={k}>{v.label}</option>
                      {/each}
                    </select>
                  </div>
                  <div class="u-field">
                    <label for={`stat-note-${s.id}`} class="u-field-label">ملاحظات / تعليق القرار</label>
                    <input
                      id={`stat-note-${s.id}`}
                      class="u-input"
                      bind:value={decisionNoteVal}
                      placeholder="سبب القبول أو الرفض…"
                    />
                  </div>
                </div>
                <div class="status-actions">
                  <button type="button" class="u-btn u-btn-ghost sm" onclick={() => (editingStatusId = null)}>إلغاء</button>
                  <button
                    type="button"
                    class="u-btn u-btn-primary sm"
                    disabled={savingStatus}
                    onclick={() => saveStatusChange(s.id)}
                  >
                    {savingStatus ? 'جارٍ الحفظ…' : 'حفظ القرار'}
                  </button>
                </div>
              </div>
            {/if}

            <!-- Comment Thread on each suggestion -->
            <CommentThread entity_type="suggestion" entity_id={s.id} initialExpanded={false} />
          </div>
        </div>
      </article>
    {/each}
    </div>
  {/if}
</div>

{#if showCreateModal}
  <SuggestionFormModal
    onclose={() => (showCreateModal = false)}
    onsaved={() => {
      showCreateModal = false;
      loadData();
    }}
  />
{/if}

<style>
  .chip-count {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 20px;
    padding: 0 6px;
    height: 18px;
    background: var(--muted-bg);
    color: var(--ink2);
    border-radius: var(--r-pill);
    font: var(--fw-bold) 10.5px var(--font-sans);
    font-variant-numeric: tabular-nums;
    margin-inline-start: 4px;
  }
  :global(.u-chip.on) .chip-count {
    background: color-mix(in oklab, var(--bg) 25%, transparent);
    color: var(--bg);
  }

  .suggestions-list {
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
  }
  .suggestion-card {
    padding: var(--sp-3);
  }
  .sug-layout {
    display: flex;
    gap: var(--sp-2);
    align-items: flex-start;
  }

  /* Vote Column */
  .vote-col {
    display: flex;
    flex-direction: column;
    align-items: center;
    background: var(--muted-bg);
    border: 1px solid var(--line);
    border-radius: var(--r-md);
    padding: 4px;
    min-width: 44px;
    flex-shrink: 0;
  }
  .vote-btn {
    width: 36px;
    height: 36px;
    display: grid;
    place-items: center;
    background: transparent;
    border: none;
    border-radius: var(--r-xs);
    color: var(--ink3);
    cursor: pointer;
    transition: all var(--t-fast);
  }
  .vote-btn:hover {
    background: var(--card);
    color: var(--ink);
  }
  .vote-btn.up-voted {
    background: var(--brand-soft);
    color: var(--brand);
  }
  .vote-btn.down-voted {
    background: var(--bad-soft);
    color: var(--bad);
  }
  .vote-count {
    font: var(--fw-bold) var(--fs-base) var(--font-num);
    color: var(--ink);
    margin: 2px 0;
  }
  .vote-count.positive {
    color: var(--brand);
  }
  .vote-count.negative {
    color: var(--bad);
  }

  /* Main Column */
  .sug-main {
    flex: 1;
    min-width: 0;
  }
  .sug-header {
    display: flex;
    gap: var(--sp-05);
    align-items: center;
    margin-bottom: var(--sp-1);
    flex-wrap: wrap;
  }
  .rm-sug-btn {
    margin-inline-start: auto;
    color: var(--ink3);
  }
  .rm-sug-btn:hover {
    color: var(--bad);
    background: var(--bad-soft);
  }
  .sug-title {
    margin: 0 0 var(--sp-1);
    font: var(--fw-bold) var(--fs-md)/1.3 var(--font-sans);
    color: var(--ink);
  }
  .sug-desc {
    margin: 0 0 var(--sp-2);
    font-size: var(--fs-sm);
    color: var(--ink2);
    line-height: var(--lh-base);
  }
  .decision-note-box {
    background: var(--gold-soft);
    border: 1px solid var(--gold);
    color: var(--gold-dark);
    padding: var(--sp-1) var(--sp-2);
    border-radius: var(--r-sm);
    font-size: var(--fs-xs);
    margin-bottom: var(--sp-2);
    display: flex;
    gap: var(--sp-05);
  }
  .decision-lbl {
    font-weight: var(--fw-bold);
  }
  .sug-meta-row {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    flex-wrap: wrap;
    color: var(--ink3);
    font-size: var(--fs-xs);
    padding-bottom: var(--sp-1);
  }
  .author-cell {
    display: inline-flex;
    align-items: center;
    gap: var(--sp-05);
  }
  .author-name {
    color: var(--ink);
    font-weight: var(--fw-medium);
  }
  .meta-date {
    color: var(--ink3);
  }
  .admin-edit-status-btn {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    background: transparent;
    border: none;
    color: var(--brand);
    font: var(--fw-semi) var(--fs-tiny) var(--font-sans);
    cursor: pointer;
    margin-inline-start: auto;
  }
  .admin-edit-status-btn:hover {
    text-decoration: underline;
  }

  .status-change-box {
    background: var(--muted-bg);
    border: 1px dashed var(--brand);
    border-radius: var(--r-md);
    padding: var(--sp-2);
    margin-top: var(--sp-2);
  }
  .status-box-head {
    font: var(--fw-bold) var(--fs-xs) var(--font-sans);
    color: var(--brand-ink);
    margin-bottom: var(--sp-1);
  }
  .status-inputs-grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--sp-1);
  }
  @media (min-width: 600px) {
    .status-inputs-grid {
      grid-template-columns: 160px 1fr;
    }
  }
  .status-actions {
    display: flex;
    justify-content: flex-end;
    gap: var(--sp-05);
    margin-top: var(--sp-1);
  }
  .tab-num {
    font-variant-numeric: tabular-nums;
  }
  .sug-skel {
    height: 140px;
    border-radius: var(--r-xl);
  }
</style>
