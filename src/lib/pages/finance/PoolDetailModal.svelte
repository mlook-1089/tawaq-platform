<script lang="ts">
  import {
    AlertCircle,
    Check,
    CheckCircle2,
    Lock,
    Plus,
    UserCheck,
    Users,
    X
  } from 'lucide-svelte';
  import { supabase } from '../../supabase';
  import { session, canManageFinance } from '../../stores';
  import { fmtCurrency, fmtDate } from '../../utils';
  import Icon from '../../components/Icon.svelte';
  import Avatar from '../../components/Avatar.svelte';

  let {
    pool,
    allMembers,
    onclose,
    onupdated
  }: {
    pool: any;
    allMembers: any[];
    onclose: () => void;
    onupdated: () => void;
  } = $props();

  const user = $derived($session?.user);
  const isManager = $derived(pool.manager_user_id === user?.id || $canManageFinance);

  let contributions = $state<any[]>([]);
  let loadingContribs = $state(true);
  let error = $state('');
  let successMsg = $state('');
  let activeTab = $state<'paid' | 'unpaid'>('paid');

  // New contribution form
  let showAddContrib = $state(false);
  let contribUserId = $state('');
  let contribAmount = $state('');
  let contribMethod = $state('transfer');
  let contribNote = $state('');
  let savingContrib = $state(false);

  const paymentMethods: Record<string, string> = {
    transfer: 'تحويل بنكي',
    stc_pay: 'STC Pay',
    apple_pay: 'Apple Pay',
    cash: 'نقداً',
    other: 'أخرى'
  };

  const poolStatusLabels: Record<string, { label: string; pill: string }> = {
    open: { label: 'مفتوحة', pill: 'ok' },
    closed: { label: 'مغلقة', pill: 'warn' },
    settled: { label: 'تمت التسوية', pill: 'info' }
  };

  async function loadContributions() {
    loadingContribs = true;
    error = '';
    try {
      const { data, error: err } = await supabase
        .from('pool_contributions')
        .select(`
          id,
          amount,
          method,
          note,
          paid_at,
          user:users!pool_contributions_user_id_fkey(id, full_name, avatar_url, phone)
        `)
        .eq('pool_id', pool.id)
        .order('paid_at', { ascending: false });

      if (err) {
        // Fallback query without foreign key
        const { data: raw, error: rawErr } = await supabase
          .from('pool_contributions')
          .select('*')
          .eq('pool_id', pool.id);
        if (rawErr) throw rawErr;
        contributions = (raw || []).map(c => ({
          ...c,
          user: allMembers.find(m => m.id === c.user_id) || { full_name: 'عضو' }
        }));
      } else {
        contributions = data || [];
      }
    } catch (e: any) {
      error = e.message || 'تعذّر تحميل بيانات المساهمين';
    } finally {
      loadingContribs = false;
    }
  }

  $effect(() => {
    if (pool.id) loadContributions();
  });

  const totalCollected = $derived.by(() => {
    return contributions.reduce((sum, c) => sum + Number(c.amount || 0), 0);
  });

  const percentCollected = $derived.by(() => {
    if (!pool.target_amount || pool.target_amount <= 0) return 0;
    return Math.min(100, Math.round((totalCollected / pool.target_amount) * 100));
  });

  const paidUserIds = $derived.by(() => {
    return new Set(contributions.map(c => c.user?.id || c.user_id));
  });

  const unpaidMembers = $derived.by(() => {
    return allMembers.filter(m => !paidUserIds.has(m.id));
  });

  async function recordContribution(e: Event) {
    e.preventDefault();
    if (!contribUserId || !contribAmount) return;

    savingContrib = true;
    error = '';
    try {
      const payload = {
        pool_id: pool.id,
        user_id: contribUserId,
        amount: Number(contribAmount),
        method: contribMethod,
        note: contribNote.trim() || null,
        recorded_by: user?.id
      };

      const { error: err } = await supabase.from('pool_contributions').insert(payload);
      if (err) throw err;

      showAddContrib = false;
      contribUserId = '';
      contribAmount = '';
      contribNote = '';
      successMsg = 'تم تسجيل الدفعة بنجاح.';
      setTimeout(() => (successMsg = ''), 3000);
      await loadContributions();
      onupdated();
    } catch (e: any) {
      error = e.message || 'تعذّر تسجيل الدفعة';
    } finally {
      savingContrib = false;
    }
  }

  async function updatePoolStatus(newStatus: 'open' | 'closed' | 'settled') {
    const label = poolStatusLabels[newStatus]?.label || newStatus;
    if (!confirm(`تغيير حالة القطة إلى "${label}"؟`)) return;

    try {
      const { error: err } = await supabase
        .from('pools')
        .update({ status: newStatus })
        .eq('id', pool.id);
      if (err) throw err;
      pool.status = newStatus;
      onupdated();
    } catch (e: any) {
      error = e.message || 'تعذّر تحديث حالة القطة';
    }
  }
</script>

<div class="u-modal" onclick={onclose} onkeydown={(e) => e.key === 'Escape' && onclose()} role="presentation">
  <div class="u-modal-scrim"></div>
  <div class="u-modal-box wide" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
    <div class="u-sheet-handle"></div>
    <div class="u-modal-header">
      <div class="modal-header-info">
        <span>{pool.title}</span>
        <span class="u-pill {poolStatusLabels[pool.status]?.pill || ''}">
          {poolStatusLabels[pool.status]?.label || pool.status}
        </span>
      </div>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق"><Icon icon={X} /></button>
    </div>

    <div class="u-modal-body">
      {#if error}<div class="u-alert err">{error}</div>{/if}
      {#if successMsg}<div class="u-alert ok">{successMsg}</div>{/if}

      <!-- Pool Progress Card -->
      <div class="pool-summary-box">
        <div class="summary-top">
          <div class="stat-col">
            <span class="stat-lbl">المجموع المجموع</span>
            <span class="stat-val tab-num">{fmtCurrency(totalCollected)}</span>
          </div>
          <div class="stat-col end">
            <span class="stat-lbl">الهدف</span>
            <span class="stat-val tab-num">{fmtCurrency(pool.target_amount)}</span>
          </div>
        </div>

        <div class="u-progress-bar">
          <div class="pb-fill" style={`width: ${percentCollected}%;`}></div>
        </div>

        <div class="summary-bottom">
          <span>{percentCollected}% مكتمل</span>
          <span>المتبقي: <b class="tab-num">{fmtCurrency(Math.max(0, (pool.target_amount || 0) - totalCollected))}</b></span>
        </div>
      </div>

      {#if pool.description}
        <p class="pool-description">{pool.description}</p>
      {/if}

      <!-- Admin Actions Row -->
      {#if isManager}
        <div class="manager-toolbar">
          {#if pool.status === 'open'}
            <button
              class="u-btn u-btn-primary sm"
              onclick={() => (showAddContrib = !showAddContrib)}
            >
              <Icon icon={Plus} size={14} />
              <span>تسجيل دفعة</span>
            </button>
            <button
              class="u-btn u-btn-ghost sm"
              onclick={() => updatePoolStatus('closed')}
            >
              <Icon icon={Lock} size={14} />
              <span>إغلاق القطة</span>
            </button>
          {:else if pool.status === 'closed'}
            <button
              class="u-btn u-btn-ghost sm"
              onclick={() => updatePoolStatus('open')}
            >
              <span>إعادة فتح</span>
            </button>
            <button
              class="u-btn u-btn-success sm"
              onclick={() => updatePoolStatus('settled')}
            >
              <Icon icon={CheckCircle2} size={14} />
              <span>تسوية القطة</span>
            </button>
          {/if}
        </div>
      {/if}

      <!-- Add Contribution Form Modal/Subform -->
      {#if showAddContrib}
        <form class="add-contrib-form" onsubmit={recordContribution}>
          <div class="form-title">تسجيل دفعة جديدة</div>

          <div class="u-field">
            <label for="ac-user" class="u-field-label">العضو *</label>
            <select id="ac-user" class="u-input u-select" bind:value={contribUserId} required>
              <option value="">اختر العضو…</option>
              {#each unpaidMembers as m}
                <option value={m.id}>{m.full_name}</option>
              {/each}
            </select>
          </div>

          <div class="form-grid-2">
            <div class="u-field">
              <label for="ac-amt" class="u-field-label">المبلغ (ر.س) *</label>
              <input
                id="ac-amt"
                type="number"
                step="0.01"
                min="0.5"
                class="u-input"
                bind:value={contribAmount}
                required
                placeholder="50.00"
              />
            </div>

            <div class="u-field">
              <label for="ac-method" class="u-field-label">طريقة الدفع *</label>
              <select id="ac-method" class="u-input u-select" bind:value={contribMethod}>
                {#each Object.entries(paymentMethods) as [k, v]}
                  <option value={k}>{v}</option>
                {/each}
              </select>
            </div>
          </div>

          <div class="u-field">
            <label for="ac-note" class="u-field-label">ملاحظات</label>
            <input id="ac-note" class="u-input" bind:value={contribNote} placeholder="رقم الحوالة، اسم المحوّل…" />
          </div>

          <div class="form-actions">
            <button type="button" class="u-btn u-btn-ghost sm" onclick={() => (showAddContrib = false)}>إلغاء</button>
            <button type="submit" class="u-btn u-btn-primary sm" disabled={savingContrib}>
              {savingContrib ? 'جارٍ التسجيل…' : 'حفظ الدفعة'}
            </button>
          </div>
        </form>
      {/if}

      <!-- Tabs: Paid vs Unpaid -->
      <div class="u-seg block">
        <button
          class="seg-btn"
          class:on={activeTab === 'paid'}
          onclick={() => (activeTab = 'paid')}
        >
          من دفع ({contributions.length})
        </button>
        <button
          class="seg-btn"
          class:on={activeTab === 'unpaid'}
          onclick={() => (activeTab = 'unpaid')}
        >
          باقي ({unpaidMembers.length})
        </button>
      </div>

      {#if activeTab === 'paid'}
        {#if loadingContribs}
          <div class="u-skel list-skel"></div>
        {:else if contributions.length === 0}
          <div class="tab-empty">لا توجد دفعات مسجلة بعد.</div>
        {:else}
          <ul class="u-list">
            {#each contributions as c (c.id)}
              <li class="u-list-item">
                <Avatar url={c.user?.avatar_url} name={c.user?.full_name || 'ع'} size="sm" circle={true} />
                <div class="u-list-main">
                  <div class="u-list-title">{c.user?.full_name || 'عضو'}</div>
                  <div class="u-list-sub">
                    {paymentMethods[c.method] || c.method}
                    {#if c.note} · {c.note}{/if}
                  </div>
                </div>
                <div class="contrib-amt tab-num">
                  {fmtCurrency(c.amount)}
                </div>
              </li>
            {/each}
          </ul>
        {/if}
      {:else}
        {#if unpaidMembers.length === 0}
          <div class="tab-empty">الجميع دفع! اكتملت القطة.</div>
        {:else}
          <ul class="u-list">
            {#each unpaidMembers as m (m.id)}
              <li class="u-list-item">
                <Avatar url={m.avatar_url} name={m.full_name} size="sm" circle={true} />
                <div class="u-list-main">
                  <div class="u-list-title">{m.full_name}</div>
                  {#if m.phone}<div class="u-list-sub">{m.phone}</div>{/if}
                </div>
                <span class="u-pill warn">لم يدفع</span>
              </li>
            {/each}
          </ul>
        {/if}
      {/if}
    </div>

    <div class="u-modal-footer">
      <button type="button" class="u-btn u-btn-ghost" onclick={onclose}>إغلاق</button>
    </div>
  </div>
</div>

<style>
  .modal-header-info {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    flex-wrap: wrap;
  }
  .pool-summary-box {
    background: var(--muted-bg);
    border: 1px solid var(--line);
    border-radius: var(--r-lg);
    padding: var(--sp-3);
    margin-bottom: var(--sp-3);
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
  }
  .summary-top {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .stat-col {
    display: flex;
    flex-direction: column;
  }
  .stat-col.end {
    align-items: flex-end;
  }
  .stat-lbl {
    font-size: var(--fs-xs);
    color: var(--ink3);
  }
  .stat-val {
    font: var(--fw-bold) var(--fs-xl) var(--font-num);
    color: var(--brand);
  }
  .summary-bottom {
    display: flex;
    justify-content: space-between;
    font-size: var(--fs-xs);
    color: var(--ink2);
  }
  .pool-description {
    font-size: var(--fs-sm);
    color: var(--ink2);
    margin-bottom: var(--sp-3);
    line-height: var(--lh-base);
  }
  .manager-toolbar {
    display: flex;
    gap: var(--sp-1);
    margin-bottom: var(--sp-3);
    flex-wrap: wrap;
  }
  .add-contrib-form {
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: var(--r-md);
    padding: var(--sp-3);
    margin-bottom: var(--sp-3);
    box-shadow: var(--shadow);
  }
  .form-title {
    font: var(--fw-bold) var(--fs-sm) var(--font-sans);
    color: var(--ink);
    margin-bottom: var(--sp-2);
  }
  .form-grid-2 {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--sp-1);
  }
  .form-actions {
    display: flex;
    justify-content: flex-end;
    gap: var(--sp-1);
    margin-top: var(--sp-2);
  }
  .tab-num {
    font-variant-numeric: tabular-nums;
  }
  .contrib-amt {
    font: var(--fw-bold) var(--fs-base) var(--font-num);
    color: var(--brand);
  }
  .tab-empty {
    text-align: center;
    padding: var(--sp-5) var(--sp-2);
    color: var(--ink3);
    font-size: var(--fs-sm);
  }
  .list-skel {
    height: 120px;
    border-radius: var(--r-md);
    margin-top: var(--sp-2);
  }
</style>
