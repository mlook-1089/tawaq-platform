<script lang="ts">
  import { onMount } from 'svelte';
  import {
    AlertCircle,
    Check,
    CheckCircle2,
    DollarSign,
    FileText,
    Plus,
    RefreshCw,
    Users,
    Wallet,
    X,
    XCircle
  } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { session, canManageFinance } from '../stores';
  import { fmtCurrency, fmtDate } from '../utils';
  import PageHead from '../components/PageHead.svelte';
  import Icon from '../components/Icon.svelte';
  import Avatar from '../components/Avatar.svelte';
  import EmptyIllustrations from '../components/EmptyIllustrations.svelte';
  import PoolFormModal from './finance/PoolFormModal.svelte';
  import PoolDetailModal from './finance/PoolDetailModal.svelte';
  import ExpenseClaimFormModal from './finance/ExpenseClaimFormModal.svelte';
  import ExpenseClaimDetailModal from './finance/ExpenseClaimDetailModal.svelte';

  const user = $derived($session?.user);

  interface Pool {
    id: string;
    type: string;
    title: string;
    description: string | null;
    target_amount: number;
    status: string;
    created_at: string;
    manager_user_id: string;
    manager?: {
      full_name: string;
      avatar_url: string | null;
    };
    total_collected?: number;
    paid_count?: number;
    percent?: number;
  }

  interface Claim {
    id: string;
    title: string;
    amount: number;
    description: string | null;
    status: string;
    receipt_url: string | null;
    created_at: string;
    claimant_user_id: string;
    claimant?: {
      full_name: string;
      avatar_url: string | null;
    };
  }

  let pools = $state<Pool[]>([]);
  let claims = $state<Claim[]>([]);
  let members = $state<any[]>([]);
  let events = $state<any[]>([]);
  let loading = $state(true);
  let error = $state('');

  // Modals state
  let showNewPoolModal = $state(false);
  let showNewClaimModal = $state(false);
  let selectedPool = $state<Pool | null>(null);
  let selectedClaim = $state<Claim | null>(null);

  const poolTypeConfig: Record<string, { label: string; pill: string }> = {
    rest_stop: { label: 'قطة استراحة', pill: 'brand' },
    trip:      { label: 'قطة رحلة',    pill: 'gold' },
    event:     { label: 'قطة فعالية',  pill: 'warn' },
    custom:    { label: 'مخصصة',       pill: 'info' }
  };

  const claimStatusConfig: Record<string, { label: string; pill: string }> = {
    pending:  { label: 'قيد المراجعة', pill: 'warn' },
    approved: { label: 'معتمدة',      pill: 'brand' },
    rejected: { label: 'مرفوضة',      pill: 'bad' },
    paid:     { label: 'تم الصرف',     pill: 'ok' }
  };

  async function loadData() {
    loading = true;
    error = '';
    try {
      const [
        { data: poolsData, error: pErr },
        { data: contribsData, error: cErr },
        { data: claimsData, error: clErr },
        { data: membersData, error: mErr },
        { data: eventsData, error: evErr }
      ] = await Promise.all([
        supabase
          .from('pools')
          .select('*, manager:users!pools_manager_user_id_fkey(full_name, avatar_url)')
          .is('deleted_at', null)
          .order('created_at', { ascending: false }),
        supabase
          .from('pool_contributions')
          .select('pool_id, amount, user_id'),
        supabase
          .from('expense_claims')
          .select('*, claimant:users!expense_claims_claimant_user_id_fkey(full_name, avatar_url)')
          .order('created_at', { ascending: false }),
        supabase
          .from('users')
          .select('id, full_name, avatar_url, phone')
          .is('deleted_at', null)
          .eq('status', 'active'),
        supabase
          .from('events')
          .select('id, title, start_datetime')
          .is('deleted_at', null)
          .gte('start_datetime', new Date().toISOString())
          .order('start_datetime', { ascending: true })
      ]);

      if (pErr) throw pErr;
      if (clErr) throw clErr;

      members = membersData || [];
      events = eventsData || [];

      // Calculate totals for each pool
      const contribsByPool = new Map<string, { total: number; count: number }>();
      for (const c of contribsData || []) {
        const cur = contribsByPool.get(c.pool_id) || { total: 0, count: 0 };
        cur.total += Number(c.amount || 0);
        cur.count += 1;
        contribsByPool.set(c.pool_id, cur);
      }

      pools = (poolsData || []).map((p: any) => {
        const stats = contribsByPool.get(p.id) || { total: 0, count: 0 };
        const percent = p.target_amount > 0 ? Math.min(100, Math.round((stats.total / p.target_amount) * 100)) : 0;
        return {
          ...p,
          total_collected: stats.total,
          paid_count: stats.count,
          percent
        };
      });

      claims = (claimsData || []) as Claim[];
    } catch (e: any) {
      error = e.message || 'تعذّر تحميل البيانات المالية';
    } finally {
      loading = false;
    }
  }

  onMount(loadData);

  // Quick action from claims list
  async function quickResolveClaim(claim: Claim, newStatus: 'approved' | 'rejected') {
    const actionLabel = newStatus === 'approved' ? 'اعتماد' : 'رفض';
    if (!confirm(`هل أنت متأكد من ${actionLabel} المطالبة "${claim.title}"؟`)) return;

    try {
      const { error: err } = await supabase
        .from('expense_claims')
        .update({
          status: newStatus,
          decided_by: user?.id,
          decided_at: new Date().toISOString()
        })
        .eq('id', claim.id);
      if (err) throw err;
      await loadData();
    } catch (e: any) {
      alert(e.message || 'تعذّر تحديث المطالبة');
    }
  }
</script>

<PageHead
  icon={Wallet}
  title="المالية والقطات"
  subtitle="متابعة قطات الاستراحة، الرحلات، ومطالبات الصرف"
>
  {#snippet action()}
    <div class="head-actions">
      <button class="u-btn u-btn-primary sm" onclick={() => (showNewClaimModal = true)}>
        <Icon icon={Plus} size={14} />
        <span>رفع مصاريف</span>
      </button>
      {#if $canManageFinance}
        <button class="u-btn u-btn-ghost sm" onclick={() => (showNewPoolModal = true)}>
          <Icon icon={Plus} size={14} />
          <span>قطة جديدة</span>
        </button>
      {/if}
    </div>
  {/snippet}
</PageHead>

{#if error}<div class="u-alert err">{error}</div>{/if}

<!-- Section 1: Open Pools -->
<section class="finance-block">
  <div class="block-head-row">
    <div class="block-title">القطات النشطة والمفتوحة</div>
    <span class="block-count">({pools.filter(p => p.status === 'open').length})</span>
  </div>

  {#if loading}
    <div class="pools-grid">
      <div class="u-skel pool-card-skel"></div>
      <div class="u-skel pool-card-skel"></div>
    </div>
  {:else if pools.length === 0}
    <div class="u-empty">
      <EmptyIllustrations kind="generic" />
      <h3>لا توجد قطات حالياً</h3>
      <p>يمكن للمسؤولين إنشاء قطة استراحة أو رحلة جديدة.</p>
    </div>
  {:else}
    <div class="pools-grid">
      {#each pools as p (p.id)}
        {@const typeCfg = poolTypeConfig[p.type] || { label: p.type, pill: '' }}
        {@const remainingMembers = Math.max(0, members.length - (p.paid_count || 0))}
        <div
          class="u-card interactive pool-card"
          onclick={() => (selectedPool = p)}
          onkeydown={(e) => e.key === 'Enter' && (selectedPool = p)}
          tabindex="0"
          role="button"
        >
          <div class="pool-card-top">
            <span class="u-pill {typeCfg.pill}">{typeCfg.label}</span>
            {#if p.status !== 'open'}
              <span class="u-pill warn">{p.status === 'closed' ? 'مغلقة' : 'مسوّاة'}</span>
            {/if}
            {#if p.manager}
              <div class="pool-manager-chip">
                <Avatar url={p.manager.avatar_url} name={p.manager.full_name} size="sm" circle={true} />
                <span>{p.manager.full_name}</span>
              </div>
            {/if}
          </div>

          <h3 class="pool-card-title">{p.title}</h3>

          <div class="pool-card-amounts">
            <div>
              <span class="lbl">تم جمع</span>
              <span class="val tab-num">{fmtCurrency(p.total_collected)}</span>
            </div>
            <div class="end">
              <span class="lbl">المستهدف</span>
              <span class="val tab-num">{fmtCurrency(p.target_amount)}</span>
            </div>
          </div>

          <div class="u-progress-bar">
            <div class="pb-fill" style={`width: ${p.percent}%;`}></div>
          </div>

          <div class="pool-card-footer">
            <span class="count-pill ok"><Icon icon={Check} size={11} /> {p.paid_count || 0} دفعوا</span>
            <span class="count-pill"><Icon icon={Users} size={11} /> {remainingMembers} باقي</span>
            <span class="pct-lbl">{p.percent}%</span>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</section>

<!-- Section 3: Expense Claims -->
<section class="finance-block">
  <div class="block-head-row">
    <div class="block-title">مطالبات الصرف والمشتريات</div>
    <span class="block-count">({claims.length})</span>
  </div>

  {#if loading}
    <div class="u-stack">
      <div class="u-skel claim-row-skel"></div>
      <div class="u-skel claim-row-skel"></div>
    </div>
  {:else if claims.length === 0}
    <div class="u-empty">
      <EmptyIllustrations kind="generic" />
      <h3>لا توجد مطالبات صرف</h3>
      <p>إذا اشتريت شيئاً للفعالية أو الاستراحة، ارفع فاتورتك هنا ليتم تعويضك.</p>
    </div>
  {:else}
    <div class="claims-list">
      {#each claims as cl (cl.id)}
        {@const statusCfg = claimStatusConfig[cl.status] || { label: cl.status, pill: '' }}
        <div
          class="u-card interactive claim-row-card"
          onclick={() => (selectedClaim = cl)}
          onkeydown={(e) => e.key === 'Enter' && (selectedClaim = cl)}
          tabindex="0"
          role="button"
        >
          <div class="claim-left">
            <Avatar url={cl.claimant?.avatar_url} name={cl.claimant?.full_name || 'ع'} size="md" circle={true} />
            <div class="claim-info">
              <div class="claim-title-line">
                <span class="claim-title">{cl.title}</span>
                <span class="u-pill {statusCfg.pill}">{statusCfg.label}</span>
              </div>
              <div class="claim-meta">
                <span>{cl.claimant?.full_name || 'عضو'}</span>
                <span>·</span>
                <span>{fmtDate(cl.created_at)}</span>
                {#if cl.receipt_url}
                  <span class="receipt-indicator"><Icon icon={FileText} size={12} /> إيصال</span>
                {/if}
              </div>
            </div>
          </div>

          <div class="claim-right" onclick={(e) => e.stopPropagation()} role="presentation">
            <div class="claim-amount tab-num">{fmtCurrency(cl.amount)}</div>

            {#if $canManageFinance && cl.status === 'pending'}
              <div class="quick-admin-btns">
                <button
                  type="button"
                  class="u-btn-icon ok-btn"
                  onclick={() => quickResolveClaim(cl, 'approved')}
                  title="اعتماد"
                  aria-label="اعتماد"
                >
                  <Icon icon={Check} size={14} />
                </button>
                <button
                  type="button"
                  class="u-btn-icon danger-btn"
                  onclick={() => quickResolveClaim(cl, 'rejected')}
                  title="رفض"
                  aria-label="رفض"
                >
                  <Icon icon={X} size={14} />
                </button>
              </div>
            {/if}
          </div>
        </div>
      {/each}
    </div>
  {/if}
</section>

<!-- Modals -->
{#if showNewPoolModal}
  <PoolFormModal
    {members}
    {events}
    onclose={() => (showNewPoolModal = false)}
    onsaved={() => {
      showNewPoolModal = false;
      loadData();
    }}
  />
{/if}

{#if showNewClaimModal}
  <ExpenseClaimFormModal
    {pools}
    {events}
    onclose={() => (showNewClaimModal = false)}
    onsaved={() => {
      showNewClaimModal = false;
      loadData();
    }}
  />
{/if}

{#if selectedPool}
  <PoolDetailModal
    pool={selectedPool}
    allMembers={members}
    onclose={() => (selectedPool = null)}
    onupdated={() => {
      loadData();
    }}
  />
{/if}

{#if selectedClaim}
  <ExpenseClaimDetailModal
    claim={selectedClaim}
    onclose={() => (selectedClaim = null)}
    onupdated={() => {
      loadData();
    }}
  />
{/if}

<style>
  .head-actions {
    display: flex;
    gap: var(--sp-1);
    align-items: center;
  }
  .finance-block {
    margin-bottom: var(--sp-4);
  }
  .block-head-row {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    margin-bottom: var(--sp-2);
  }
  .block-title {
    font: var(--fw-bold) var(--fs-md) var(--font-sans);
    color: var(--ink);
  }
  .block-count {
    font-size: var(--fs-sm);
    color: var(--ink3);
  }

  /* Pools Grid */
  .pools-grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--sp-2);
  }
  @media (min-width: 600px) {
    .pools-grid {
      grid-template-columns: 1fr 1fr;
    }
  }

  .pool-card {
    display: flex;
    flex-direction: column;
    gap: var(--sp-1);
    padding: var(--sp-3);
  }
  .pool-card-top {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    flex-wrap: wrap;
  }
  .pool-manager-chip {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    margin-inline-start: auto;
    font-size: var(--fs-xs);
    color: var(--ink3);
  }
  .pool-card-title {
    margin: var(--sp-05) 0;
    font: var(--fw-bold) var(--fs-base) var(--font-sans);
    color: var(--ink);
  }
  .pool-card-amounts {
    display: flex;
    justify-content: space-between;
    margin: var(--sp-05) 0;
  }
  .pool-card-amounts .lbl {
    font-size: var(--fs-tiny);
    color: var(--ink3);
    display: block;
  }
  .pool-card-amounts .val {
    font: var(--fw-bold) var(--fs-md) var(--font-num);
    color: var(--brand);
  }
  .pool-card-amounts .end {
    text-align: end;
  }
  .pool-card-footer {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    margin-top: var(--sp-05);
  }
  .count-pill {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    font-size: var(--fs-tiny);
    color: var(--ink3);
  }
  .count-pill.ok {
    color: var(--ok);
  }
  .pct-lbl {
    margin-inline-start: auto;
    font: var(--fw-bold) var(--fs-xs) var(--font-num);
    color: var(--ink2);
  }

  /* Claims List */
  .claims-list {
    display: flex;
    flex-direction: column;
    gap: var(--sp-1);
  }
  .claim-row-card {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: var(--sp-2) var(--sp-3);
    gap: var(--sp-2);
  }
  .claim-left {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    flex: 1;
    min-width: 0;
  }
  .claim-info {
    flex: 1;
    min-width: 0;
  }
  .claim-title-line {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    flex-wrap: wrap;
  }
  .claim-title {
    font: var(--fw-bold) var(--fs-sm) var(--font-sans);
    color: var(--ink);
  }
  .claim-meta {
    display: flex;
    align-items: center;
    gap: var(--sp-05);
    font-size: var(--fs-xs);
    color: var(--ink3);
    margin-top: 2px;
  }
  .receipt-indicator {
    display: inline-flex;
    align-items: center;
    gap: 2px;
    color: var(--brand);
  }
  .claim-right {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: var(--sp-05);
    flex-shrink: 0;
  }
  .claim-amount {
    font: var(--fw-bold) var(--fs-base) var(--font-num);
    color: var(--brand);
  }
  .quick-admin-btns {
    display: flex;
    gap: 4px;
  }
  .ok-btn:hover {
    background: var(--ok-soft);
    color: var(--ok);
    border-color: var(--ok-soft);
  }
  .danger-btn:hover {
    background: var(--bad-soft);
    color: var(--bad);
    border-color: var(--bad-soft);
  }
  .tab-num {
    font-variant-numeric: tabular-nums;
  }
  .pool-card-skel {
    height: 160px;
    border-radius: var(--r-xl);
  }
  .claim-row-skel {
    height: 68px;
    border-radius: var(--r-lg);
  }
</style>
