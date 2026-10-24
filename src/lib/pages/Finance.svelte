<script lang="ts">
  import { onMount } from 'svelte';
  import {
    Check,
    FileText,
    Plus,
    Users,
    X
  } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { session, canManageFinance } from '../stores';
  import { fmtCurrency, fmtDate } from '../utils';
  import { confirmDialog, toastErr, toastOk } from '../toast';
  import Icon from '../components/Icon.svelte';
  import Avatar from '../components/Avatar.svelte';
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
    const ok = await confirmDialog({
      title: `${actionLabel} المطالبة`,
      message: `هل أنت متأكد من ${actionLabel} "${claim.title}"؟`,
      confirmLabel: actionLabel,
      danger: newStatus === 'rejected'
    });
    if (!ok) return;

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
      toastOk(newStatus === 'approved' ? 'تم اعتماد المطالبة' : 'تم رفض المطالبة');
      await loadData();
    } catch (e: any) {
      toastErr(e.message || 'تعذّر تحديث المطالبة');
    }
  }
</script>

<div class="u-page">
  <div class="u-top">
    <div>
      <div class="u-sub">قطات ومطالبات</div>
      <h1>المالية</h1>
    </div>
    <div class="u-actions">
      <button class="u-btn u-btn-primary sm" onclick={() => (showNewClaimModal = true)}>
        <Icon icon={Plus} size={14} /> رفع مصاريف
      </button>
      {#if $canManageFinance}
        <button class="u-btn u-btn-ghost sm" onclick={() => (showNewPoolModal = true)}>
          <Icon icon={Plus} size={14} /> قطة
        </button>
      {/if}
    </div>
  </div>

  {#if error}<div class="u-alert err">{error}</div>{/if}

  <div class="u-grid2 stats-row">
    <div class="u-stat">
      <span class="lbl">قطات نشطة</span>
      <span class="num">{pools.filter(p => p.status === 'open').length}</span>
    </div>
    <div class="u-stat">
      <span class="lbl">مطالبات معلّقة</span>
      <span class="num">{claims.filter(c => c.status === 'pending').length}</span>
    </div>
  </div>

  <section class="u-card">
    <div class="u-card-h">
      <h2>القطات المفتوحة</h2>
      <span class="u-pill brand">{pools.filter(p => p.status === 'open').length}</span>
    </div>

    {#if loading}
      <div class="u-list">
        <div class="u-item"><div class="u-skel skel-line"></div></div>
        <div class="u-item"><div class="u-skel skel-line"></div></div>
      </div>
    {:else if pools.length === 0}
      <div class="u-empty-inline">
        <p>لا توجد قطات حالياً</p>
      </div>
    {:else}
      <div class="u-list">
        {#each pools as p (p.id)}
          {@const typeCfg = poolTypeConfig[p.type] || { label: p.type, pill: '' }}
          <button
            class="u-item tap pool-row"
            onclick={() => (selectedPool = p)}
          >
            <div class="u-grow">
              <div class="pool-head">
                <span class="u-name">{p.title}</span>
                <span class="u-pill {typeCfg.pill}">{typeCfg.label}</span>
                {#if p.status !== 'open'}
                  <span class="u-pill warn">{p.status === 'closed' ? 'مغلقة' : 'مسوّاة'}</span>
                {/if}
              </div>
              <div class="pool-amounts">
                <span class="u-num amount">{fmtCurrency(p.total_collected)}</span>
                <span class="u-muted">من {fmtCurrency(p.target_amount)}</span>
                <span class="u-muted pct">{p.percent}%</span>
              </div>
              <div class="u-bar light"><i style="width: {p.percent}%"></i></div>
              <div class="pool-footer u-muted">
                <span><Icon icon={Check} size={11} /> {p.paid_count || 0} دفعوا</span>
                <span><Icon icon={Users} size={11} /> {Math.max(0, members.length - (p.paid_count || 0))} باقي</span>
              </div>
            </div>
          </button>
        {/each}
      </div>
    {/if}
  </section>

  <section class="u-card">
    <div class="u-card-h">
      <h2>مطالبات الصرف</h2>
      <span class="u-pill brand">{claims.length}</span>
    </div>

    {#if loading}
      <div class="u-list">
        <div class="u-item"><div class="u-skel skel-line"></div></div>
      </div>
    {:else if claims.length === 0}
      <div class="u-empty-inline">
        <p>لا توجد مطالبات حالياً</p>
      </div>
    {:else}
      <div class="u-list">
        {#each claims as cl (cl.id)}
          {@const statusCfg = claimStatusConfig[cl.status] || { label: cl.status, pill: '' }}
          <div
            class="u-item tap"
            onclick={() => (selectedClaim = cl)}
            onkeydown={(e) => e.key === 'Enter' && (selectedClaim = cl)}
            tabindex="0" role="button"
          >
            <Avatar url={cl.claimant?.avatar_url} name={cl.claimant?.full_name || 'ع'} size="sm" circle={true} />
            <div class="u-grow">
              <div class="u-name">{cl.title}</div>
              <div class="u-muted claim-meta">
                <span>{cl.claimant?.full_name || 'عضو'}</span>
                <span>· {fmtDate(cl.created_at)}</span>
                {#if cl.receipt_url}<span class="receipt-indicator"><Icon icon={FileText} size={11} /> إيصال</span>{/if}
              </div>
            </div>
            <div class="claim-end" onclick={(e) => e.stopPropagation()} role="presentation">
              <div class="claim-amount u-num">{fmtCurrency(cl.amount)}</div>
              <span class="u-pill {statusCfg.pill}">{statusCfg.label}</span>
              {#if $canManageFinance && cl.status === 'pending'}
                <div class="quick-admin-btns">
                  <button
                    type="button"
                    class="u-btn-icon ok-btn"
                    onclick={() => quickResolveClaim(cl, 'approved')}
                    aria-label="اعتماد"
                  >
                    <Icon icon={Check} size={14} />
                  </button>
                  <button
                    type="button"
                    class="u-btn-icon danger-btn"
                    onclick={() => quickResolveClaim(cl, 'rejected')}
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
</div>

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
  .stats-row {
    margin-bottom: var(--sp-3);
  }

  .u-empty-inline {
    text-align: center;
    padding: var(--sp-3);
    color: var(--ink3);
    font-size: var(--fs-sm);
  }
  .u-empty-inline p { margin: 0; }

  .pool-row {
    padding: var(--sp-2) 0;
    background: transparent;
    border: none;
    width: 100%;
    text-align: start;
    cursor: pointer;
  }
  .pool-head {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    flex-wrap: wrap;
    margin-bottom: 4px;
  }
  .pool-amounts {
    display: flex;
    align-items: baseline;
    gap: var(--sp-1);
    margin-bottom: 6px;
  }
  .pool-amounts .amount {
    font: var(--fw-bold) 16px var(--font-num);
    color: var(--brand);
    font-variant-numeric: tabular-nums;
  }
  .pool-amounts .pct {
    margin-inline-start: auto;
    font-weight: var(--fw-bold);
  }
  .pool-footer {
    display: flex;
    gap: var(--sp-2);
    margin-top: 6px;
    font-size: var(--fs-tiny);
  }
  .pool-footer span {
    display: inline-flex;
    align-items: center;
    gap: 3px;
  }

  .claim-end {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 4px;
    flex-shrink: 0;
  }
  .claim-amount {
    font: var(--fw-bold) var(--fs-base) var(--font-num);
    color: var(--brand);
    font-variant-numeric: tabular-nums;
  }
  .claim-meta {
    display: flex;
    align-items: center;
    gap: 4px;
    flex-wrap: wrap;
  }
  .receipt-indicator {
    display: inline-flex;
    align-items: center;
    gap: 2px;
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
  .skel-line { height: 44px; width: 100%; border-radius: var(--r-sm); }
</style>
