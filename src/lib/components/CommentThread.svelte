<script lang="ts">
  import { onMount, untrack } from 'svelte';
  import {
    CornerDownLeft,
    Edit3,
    Flame,
    HandHeart,
    Heart,
    MessageSquare,
    MoreVertical,
    Send,
    ThumbsUp,
    Trash2,
    X
  } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { session, isAdmin } from '../stores';
  import { timeAgo } from '../utils';
  import { confirmDialog, toastErr, toastOk } from '../toast';
  import Icon from './Icon.svelte';
  import Avatar from './Avatar.svelte';

  let {
    entity_type,
    entity_id,
    initialExpanded = true
  }: {
    entity_type: 'event' | 'news' | 'pool' | 'claim' | 'suggestion';
    entity_id: string;
    initialExpanded?: boolean;
  } = $props();

  const user = $derived($session?.user);

  interface CommentItem {
    id: string;
    entity_type: string;
    entity_id: string;
    user_id: string;
    parent_id: string | null;
    body: string;
    mentions: string[];
    created_at: string;
    author?: {
      id: string;
      full_name: string;
      username: string | null;
      avatar_url: string | null;
    };
    reactions?: Record<string, number>;
    myReactions?: string[];
    replies?: CommentItem[];
  }

  interface MemberMention {
    id: string;
    full_name: string;
    username: string | null;
    avatar_url: string | null;
  }

  let comments = $state<CommentItem[]>([]);
  let allMembers = $state<MemberMention[]>([]);
  let loading = $state(true);
  let isExpanded = $state(untrack(() => initialExpanded));
  let newCommentText = $state('');
  let submitting = $state(false);
  let error = $state('');

  // Replying state
  let replyingToId = $state<string | null>(null);
  let replyText = $state('');

  // Editing state
  let editingCommentId = $state<string | null>(null);
  let editText = $state('');

  // Mention autocomplete
  let mentionQuery = $state('');
  let showMentionMenu = $state(false);
  let mentionTarget: 'new' | 'reply' = $state('new');

  const reactionConfig: { key: string; icon: any; label: string }[] = [
    { key: 'thumbs_up', icon: ThumbsUp, label: 'إعجاب' },
    { key: 'pray',      icon: HandHeart, label: 'شكراً' },
    { key: 'heart',     icon: Heart,     label: 'قلب' },
    { key: 'fire',      icon: Flame,     label: 'حماس' }
  ];

  async function loadComments() {
    if (!entity_id) return;
    try {
      const [{ data: cData, error: cErr }, { data: rData, error: rErr }, { data: uData }] = await Promise.all([
        supabase
          .from('comments')
          .select(`
            id,
            entity_type,
            entity_id,
            user_id,
            parent_id,
            body,
            mentions,
            created_at,
            author:users!comments_user_id_fkey(id, full_name, username, avatar_url)
          `)
          .eq('entity_type', entity_type)
          .eq('entity_id', entity_id)
          .is('deleted_at', null)
          .order('created_at', { ascending: true }),
        supabase
          .from('comment_reactions')
          .select('comment_id, user_id, reaction'),
        allMembers.length === 0
          ? supabase.from('users').select('id, full_name, username, avatar_url').is('deleted_at', null)
          : Promise.resolve({ data: allMembers })
      ]);

      if (uData && allMembers.length === 0) {
        allMembers = uData as MemberMention[];
      }

      if (cErr) {
        // Fallback without foreign key
        const { data: rawComments } = await supabase
          .from('comments')
          .select('*')
          .eq('entity_type', entity_type)
          .eq('entity_id', entity_id)
          .is('deleted_at', null)
          .order('created_at', { ascending: true });

        const mapped = (rawComments || []).map(c => ({
          ...c,
          author: allMembers.find(m => m.id === c.user_id) || { id: c.user_id, full_name: 'عضو' }
        }));
        processComments(mapped, rData || []);
      } else {
        processComments(cData || [], rData || []);
      }
    } catch (e: any) {
      error = e.message || 'تعذّر تحميل التعليقات';
    } finally {
      loading = false;
    }
  }

  function processComments(rawComments: any[], rawReactions: any[]) {
    // Map reactions per comment
    const reactionsMap = new Map<string, { counts: Record<string, number>; mine: string[] }>();
    for (const r of rawReactions) {
      const cur = reactionsMap.get(r.comment_id) || { counts: {}, mine: [] };
      cur.counts[r.reaction] = (cur.counts[r.reaction] || 0) + 1;
      if (user && r.user_id === user.id) {
        cur.mine.push(r.reaction);
      }
      reactionsMap.set(r.comment_id, cur);
    }

    // Build hierarchy (parent -> replies)
    const items: CommentItem[] = [];
    const byId = new Map<string, CommentItem>();

    for (const c of rawComments) {
      const rInfo = reactionsMap.get(c.id) || { counts: {}, mine: [] };
      const item: CommentItem = {
        ...c,
        reactions: rInfo.counts,
        myReactions: rInfo.mine,
        replies: []
      };
      byId.set(c.id, item);
    }

    for (const c of byId.values()) {
      if (c.parent_id && byId.has(c.parent_id)) {
        byId.get(c.parent_id)!.replies!.push(c);
      } else {
        items.push(c);
      }
    }

    comments = items;
  }

  onMount(() => {
    void loadComments();

    // Subscribe to realtime updates on comments & comment_reactions
    const channel = supabase
      .channel(`comments:${entity_type}:${entity_id}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'comments',
          filter: `entity_id=eq.${entity_id}`
        },
        () => void loadComments()
      )
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'comment_reactions'
        },
        () => void loadComments()
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  });

  // Extract mentions from text
  function extractMentions(text: string): string[] {
    const matchedUids: string[] = [];
    const mentionRegex = /@([a-zA-Z0-9_\u0600-\u06FF]+)/g;
    let match;
    while ((match = mentionRegex.exec(text)) !== null) {
      const handle = match[1].toLowerCase();
      const member = allMembers.find(
        m => (m.username && m.username.toLowerCase() === handle) ||
             (m.full_name && m.full_name.toLowerCase().replace(/\s+/g, '_') === handle) ||
             (m.full_name && m.full_name.toLowerCase().includes(handle))
      );
      if (member && !matchedUids.includes(member.id)) {
        matchedUids.push(member.id);
      }
    }
    return matchedUids;
  }

  // Handle typing to show mention list
  function handleInput(text: string, target: 'new' | 'reply') {
    mentionTarget = target;
    const lastWord = text.split(/\s/).pop() || '';
    if (lastWord.startsWith('@') && lastWord.length > 1) {
      mentionQuery = lastWord.slice(1).toLowerCase();
      showMentionMenu = true;
    } else {
      showMentionMenu = false;
    }
  }

  function selectMention(member: MemberMention) {
    const handle = member.username || member.full_name.replace(/\s+/g, '_');
    if (mentionTarget === 'new') {
      const words = newCommentText.split(/\s/);
      words.pop();
      words.push(`@${handle} `);
      newCommentText = words.join(' ');
    } else {
      const words = replyText.split(/\s/);
      words.pop();
      words.push(`@${handle} `);
      replyText = words.join(' ');
    }
    showMentionMenu = false;
  }

  const filteredMentionMembers = $derived.by(() => {
    if (!mentionQuery) return allMembers.slice(0, 5);
    return allMembers
      .filter(m =>
        (m.username && m.username.toLowerCase().includes(mentionQuery)) ||
        m.full_name.toLowerCase().includes(mentionQuery)
      )
      .slice(0, 5);
  });

  async function postComment(e: Event) {
    e.preventDefault();
    if (!newCommentText.trim() || submitting || !user) return;

    submitting = true;
    error = '';
    try {
      const mentions = extractMentions(newCommentText);
      const { error: err } = await supabase.from('comments').insert({
        entity_type,
        entity_id,
        user_id: user.id,
        body: newCommentText.trim(),
        mentions
      });

      if (err) throw err;
      newCommentText = '';
      await loadComments();
    } catch (e: any) {
      error = e.message || 'تعذّر إرسال التعليق';
    } finally {
      submitting = false;
    }
  }

  async function postReply(parentId: string) {
    if (!replyText.trim() || submitting || !user) return;

    submitting = true;
    error = '';
    try {
      const mentions = extractMentions(replyText);
      const { error: err } = await supabase.from('comments').insert({
        entity_type,
        entity_id,
        user_id: user.id,
        parent_id: parentId,
        body: replyText.trim(),
        mentions
      });

      if (err) throw err;
      replyingToId = null;
      replyText = '';
      await loadComments();
    } catch (e: any) {
      error = e.message || 'تعذّر إرسال الرد';
    } finally {
      submitting = false;
    }
  }

  async function toggleReaction(commentId: string, reaction: string) {
    if (!user) return;

    try {
      // Check if user already reacted with this
      const { data: existing } = await supabase
        .from('comment_reactions')
        .select('*')
        .eq('comment_id', commentId)
        .eq('user_id', user.id)
        .eq('reaction', reaction)
        .maybeSingle();

      if (existing) {
        await supabase
          .from('comment_reactions')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', user.id);
      } else {
        await supabase
          .from('comment_reactions')
          .upsert({
            comment_id: commentId,
            user_id: user.id,
            reaction
          });
      }
      await loadComments();
    } catch {
      // ignore
    }
  }

  async function deleteComment(commentId: string) {
    const ok = await confirmDialog({
      title: 'حذف التعليق',
      message: 'لن يمكن استرجاع هذا التعليق.',
      confirmLabel: 'حذف',
      danger: true
    });
    if (!ok) return;
    try {
      const { error: err } = await supabase
        .from('comments')
        .update({ deleted_at: new Date().toISOString() })
        .eq('id', commentId);
      if (err) throw err;
      toastOk('تم حذف التعليق');
      await loadComments();
    } catch (e: any) {
      toastErr(e.message || 'تعذّر حذف التعليق');
    }
  }

  async function saveEditComment(commentId: string) {
    if (!editText.trim()) return;
    try {
      const mentions = extractMentions(editText);
      const { error: err } = await supabase
        .from('comments')
        .update({
          body: editText.trim(),
          mentions,
          updated_at: new Date().toISOString()
        })
        .eq('id', commentId);

      if (err) throw err;
      editingCommentId = null;
      editText = '';
      await loadComments();
    } catch (e: any) {
      toastErr(e.message || 'تعذّر تعديل التعليق');
    }
  }

  function renderFormattedBody(body: string) {
    // Escape HTML then highlight @mentions
    const escaped = body
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');

    return escaped.replace(/@([a-zA-Z0-9_\u0600-\u06FF]+)/g, '<span class="mention">@$1</span>');
  }

  const totalCommentCount = $derived.by(() => {
    let count = 0;
    for (const c of comments) {
      count += 1 + (c.replies?.length || 0);
    }
    return count;
  });
</script>

<section class="comment-thread-section">
  <div class="thread-head" onclick={() => (isExpanded = !isExpanded)} role="button" tabindex="0" onkeydown={(e) => e.key === 'Enter' && (isExpanded = !isExpanded)}>
    <div class="thread-title">
      <Icon icon={MessageSquare} size={16} />
      <span>التعليقات</span>
      <span class="thread-count">({totalCommentCount})</span>
    </div>
    <span class="toggle-txt">{isExpanded ? 'إخفاء' : 'عرض'}</span>
  </div>

  {#if isExpanded}
    {#if error}<div class="u-alert err">{error}</div>{/if}

    <div class="comments-container">
      {#if loading}
        <div class="u-skel comment-skel"></div>
      {:else if comments.length === 0}
        <div class="no-comments-msg">لا توجد تعليقات بعد. كن أول من يشارك!</div>
      {:else}
        <div class="comments-list">
          {#each comments as c (c.id)}
            {@const isAuthor = user && c.user_id === user.id}
            {@const canManageComment = isAuthor || $isAdmin}

            <article class="comment-item">
              <div class="comment-main">
                <Avatar url={c.author?.avatar_url} name={c.author?.full_name || 'ع'} size="sm" circle={true} />

                <div class="comment-content-wrap">
                  <div class="comment-header-row">
                    <span class="comment-author-name">{c.author?.full_name || 'عضو'}</span>
                    <span class="comment-time">{timeAgo(c.created_at)}</span>

                    {#if canManageComment}
                      <div class="comment-actions-menu">
                        {#if isAuthor}
                          <button
                            type="button"
                            class="u-btn-icon sm icon-ghost"
                            onclick={() => { editingCommentId = c.id; editText = c.body; }}
                            title="تعديل"
                          >
                            <Icon icon={Edit3} size={13} />
                          </button>
                        {/if}
                        <button
                          type="button"
                          class="u-btn-icon sm icon-ghost danger"
                          onclick={() => deleteComment(c.id)}
                          title="حذف"
                        >
                          <Icon icon={Trash2} size={13} />
                        </button>
                      </div>
                    {/if}
                  </div>

                  {#if editingCommentId === c.id}
                    <div class="edit-box">
                      <textarea class="u-input u-textarea edit-textarea" bind:value={editText}></textarea>
                      <div class="edit-actions">
                        <button class="u-btn u-btn-ghost sm" onclick={() => (editingCommentId = null)}>إلغاء</button>
                        <button class="u-btn u-btn-primary sm" onclick={() => saveEditComment(c.id)}>حفظ</button>
                      </div>
                    </div>
                  {:else}
                    <div class="comment-body">
                      <!-- eslint-disable-next-line svelte/no-at-html-tags -->
                      {@html renderFormattedBody(c.body)}
                    </div>
                  {/if}

                  <!-- Reactions & Reply Row -->
                  <div class="comment-footer-row">
                    <div class="reactions-strip">
                      {#each reactionConfig as r}
                        {@const count = c.reactions?.[r.key] || 0}
                        {@const active = c.myReactions?.includes(r.key)}
                        <button
                          type="button"
                          class="reaction-btn"
                          class:active
                          onclick={() => toggleReaction(c.id, r.key)}
                          title={r.label}
                        >
                          <Icon icon={r.icon} size={13} />
                          {#if count > 0}<span class="rx-num">{count}</span>{/if}
                        </button>
                      {/each}
                    </div>

                    <button
                      type="button"
                      class="reply-trigger-btn"
                      onclick={() => { replyingToId = replyingToId === c.id ? null : c.id; replyText = ''; }}
                    >
                      <Icon icon={CornerDownLeft} size={13} />
                      <span>رد</span>
                    </button>
                  </div>
                </div>
              </div>

              <!-- Inline Reply Input -->
              {#if replyingToId === c.id}
                <div class="inline-reply-box">
                  <div class="reply-input-wrap">
                    <input
                      type="text"
                      class="u-input reply-input"
                      placeholder={`الرد على ${c.author?.full_name}…`}
                      bind:value={replyText}
                      oninput={() => handleInput(replyText, 'reply')}
                      onkeydown={(e) => e.key === 'Enter' && postReply(c.id)}
                    />
                    <button
                      type="button"
                      class="u-btn u-btn-primary sm send-reply-btn"
                      disabled={submitting || !replyText.trim()}
                      onclick={() => postReply(c.id)}
                    >
                      <Icon icon={Send} size={13} />
                    </button>
                  </div>
                </div>
              {/if}

              <!-- Nested Replies -->
              {#if c.replies && c.replies.length > 0}
                <div class="replies-list">
                  {#each c.replies as reply (reply.id)}
                    {@const isReplyAuthor = user && reply.user_id === user.id}
                    <div class="reply-item">
                      <Avatar url={reply.author?.avatar_url} name={reply.author?.full_name || 'ع'} size="sm" circle={true} />
                      <div class="comment-content-wrap">
                        <div class="comment-header-row">
                          <span class="comment-author-name">{reply.author?.full_name || 'عضو'}</span>
                          <span class="comment-time">{timeAgo(reply.created_at)}</span>

                          {#if isReplyAuthor || $isAdmin}
                            <button
                              type="button"
                              class="u-btn-icon sm icon-ghost danger"
                              onclick={() => deleteComment(reply.id)}
                              title="حذف"
                            >
                              <Icon icon={Trash2} size={12} />
                            </button>
                          {/if}
                        </div>

                        <div class="comment-body reply-body">
                          <!-- eslint-disable-next-line svelte/no-at-html-tags -->
                          {@html renderFormattedBody(reply.body)}
                        </div>

                        <div class="reactions-strip reply-rx">
                          {#each reactionConfig as r}
                            {@const rCount = reply.reactions?.[r.key] || 0}
                            {@const rActive = reply.myReactions?.includes(r.key)}
                            <button
                              type="button"
                              class="reaction-btn sm"
                              class:active={rActive}
                              onclick={() => toggleReaction(reply.id, r.key)}
                              title={r.label}
                            >
                              <Icon icon={r.icon} size={12} />
                              {#if rCount > 0}<span class="rx-num">{rCount}</span>{/if}
                            </button>
                          {/each}
                        </div>
                      </div>
                    </div>
                  {/each}
                </div>
              {/if}
            </article>
          {/each}
        </div>
      {/if}

      <!-- Mention Autocomplete Overlay -->
      {#if showMentionMenu && filteredMentionMembers.length > 0}
        <div class="mention-dropdown">
          {#each filteredMentionMembers as m (m.id)}
            <button
              type="button"
              class="mention-item-btn"
              onclick={() => selectMention(m)}
            >
              <Avatar url={m.avatar_url} name={m.full_name} size="sm" circle={true} />
              <div class="mention-item-text">
                <span class="m-name">{m.full_name}</span>
                {#if m.username}<span class="m-handle">@{m.username}</span>{/if}
              </div>
            </button>
          {/each}
        </div>
      {/if}

      <!-- New Comment Form -->
      <form class="new-comment-form" onsubmit={postComment}>
        <div class="new-comment-input-wrap">
          <input
            type="text"
            class="u-input comment-input"
            placeholder="اكتب تعليقاً… (استخدم @ للإشارة)"
            bind:value={newCommentText}
            oninput={() => handleInput(newCommentText, 'new')}
            maxlength="1000"
          />
          <button
            type="submit"
            class="u-btn u-btn-primary send-btn"
            disabled={submitting || !newCommentText.trim()}
            aria-label="إرسال"
          >
            <Icon icon={Send} size={15} />
          </button>
        </div>
      </form>
    </div>
  {/if}
</section>

<style>
  .comment-thread-section {
    margin-top: var(--sp-3);
    border-top: 1px solid var(--line);
    padding-top: var(--sp-2);
  }
  .thread-head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    cursor: pointer;
    padding: var(--sp-1) 0;
    user-select: none;
  }
  .thread-title {
    display: inline-flex;
    align-items: center;
    gap: var(--sp-1);
    font: var(--fw-bold) var(--fs-sm) var(--font-sans);
    color: var(--ink);
  }
  .thread-count {
    color: var(--ink3);
    font-size: var(--fs-xs);
  }
  .toggle-txt {
    font-size: var(--fs-xs);
    color: var(--brand);
  }

  .comments-container {
    position: relative;
    margin-top: var(--sp-2);
  }
  .no-comments-msg {
    text-align: center;
    padding: var(--sp-4) var(--sp-2);
    color: var(--ink3);
    font-size: var(--fs-xs);
  }
  .comments-list {
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
    margin-bottom: var(--sp-3);
  }
  .comment-item {
    display: flex;
    flex-direction: column;
    gap: var(--sp-1);
  }
  .comment-main {
    display: flex;
    align-items: flex-start;
    gap: var(--sp-1);
  }
  .comment-content-wrap {
    flex: 1;
    min-width: 0;
    background: var(--muted-bg);
    border-radius: var(--r-md);
    padding: var(--sp-1) var(--sp-2);
  }
  .comment-header-row {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    margin-bottom: 2px;
  }
  .comment-author-name {
    font: var(--fw-bold) var(--fs-xs) var(--font-sans);
    color: var(--ink);
  }
  .comment-time {
    font-size: var(--fs-tiny);
    color: var(--ink3);
  }
  .comment-actions-menu {
    display: flex;
    gap: 2px;
    margin-inline-start: auto;
  }
  .icon-ghost {
    width: 22px;
    height: 22px;
    border: none;
    background: transparent;
    color: var(--ink3);
    border-radius: var(--r-xs);
  }
  .icon-ghost:hover {
    background: var(--card);
    color: var(--ink);
  }
  .icon-ghost.danger:hover {
    background: var(--bad-soft);
    color: var(--bad);
  }

  .comment-body {
    font-size: var(--fs-sm);
    color: var(--ink);
    line-height: var(--lh-base);
    word-break: break-word;
  }
  .comment-body :global(.mention) {
    color: var(--brand);
    font-weight: var(--fw-bold);
    background: var(--brand-soft);
    padding: 1px 4px;
    border-radius: var(--r-xs);
  }

  .comment-footer-row {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    margin-top: var(--sp-1);
    flex-wrap: wrap;
  }
  .reactions-strip {
    display: flex;
    gap: 3px;
    align-items: center;
  }
  .reaction-btn {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: var(--r-pill);
    padding: 2px 7px;
    font-size: var(--fs-tiny);
    color: var(--ink3);
    cursor: pointer;
    transition: all var(--t-fast);
  }
  .reaction-btn:hover {
    background: var(--muted-bg);
    color: var(--ink);
  }
  .reaction-btn.active {
    background: var(--brand-soft);
    border-color: var(--brand);
    color: var(--brand-ink);
  }
  .reaction-btn.sm {
    padding: 1px 5px;
    font-size: 10px;
  }
  .rx-num {
    font: var(--fw-bold) var(--fs-tiny) var(--font-num);
  }
  .reply-trigger-btn {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    background: transparent;
    border: none;
    color: var(--ink3);
    font: var(--fw-semi) var(--fs-tiny) var(--font-sans);
    cursor: pointer;
    margin-inline-start: auto;
  }
  .reply-trigger-btn:hover {
    color: var(--brand);
  }

  /* Inline reply */
  .inline-reply-box {
    margin-inline-start: calc(var(--sp-4) + var(--sp-1));
    margin-top: var(--sp-1);
  }
  .reply-input-wrap {
    display: flex;
    gap: var(--sp-05);
    align-items: center;
  }
  .reply-input {
    height: 34px;
    font-size: var(--fs-xs);
  }
  .send-reply-btn {
    height: 34px;
    width: 34px;
    padding: 0;
    flex-shrink: 0;
  }

  /* Replies list */
  .replies-list {
    margin-inline-start: calc(var(--sp-4) + var(--sp-1));
    margin-top: var(--sp-1);
    display: flex;
    flex-direction: column;
    gap: var(--sp-1);
    border-inline-start: 2px solid var(--line2);
    padding-inline-start: var(--sp-1);
  }
  .reply-item {
    display: flex;
    align-items: flex-start;
    gap: var(--sp-05);
  }
  .reply-body {
    font-size: var(--fs-xs);
  }
  .reply-rx {
    margin-top: 4px;
  }

  /* Edit box */
  .edit-box {
    margin-top: var(--sp-05);
  }
  .edit-textarea {
    min-height: 60px;
    font-size: var(--fs-sm);
  }
  .edit-actions {
    display: flex;
    justify-content: flex-end;
    gap: var(--sp-05);
    margin-top: var(--sp-05);
  }

  /* Mention dropdown */
  .mention-dropdown {
    position: absolute;
    bottom: 52px;
    right: 0;
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: var(--r-md);
    box-shadow: var(--shadow-lg);
    z-index: var(--z-modal);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    min-width: 200px;
  }
  .mention-item-btn {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    padding: var(--sp-1) var(--sp-2);
    background: transparent;
    border: none;
    cursor: pointer;
    text-align: start;
    width: 100%;
  }
  .mention-item-btn:hover {
    background: var(--muted-bg);
  }
  .mention-item-text {
    display: flex;
    flex-direction: column;
  }
  .m-name {
    font: var(--fw-bold) var(--fs-xs) var(--font-sans);
    color: var(--ink);
  }
  .m-handle {
    font-size: var(--fs-tiny);
    color: var(--ink3);
  }

  /* New comment form */
  .new-comment-form {
    margin-top: var(--sp-2);
  }
  .new-comment-input-wrap {
    display: flex;
    gap: var(--sp-1);
    align-items: center;
  }
  .comment-input {
    height: 40px;
    font-size: var(--fs-sm);
  }
  .send-btn {
    height: 40px;
    width: 44px;
    padding: 0;
    flex-shrink: 0;
  }
  .comment-skel {
    height: 50px;
    border-radius: var(--r-md);
  }
</style>
