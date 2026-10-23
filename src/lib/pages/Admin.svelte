<script lang="ts">
  import { onMount } from 'svelte';
  import {
    Activity,
    Check,
    KeyRound,
    Mail,
    MoreHorizontal,
    Plus,
    RefreshCw,
    Search,
    Shield,
    ShieldAlert,
    ShieldCheck,
    Trash2,
    UserCheck,
    Users,
    UserX,
    X
  } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { roles, route } from '../stores';
  import PageHead from '../components/PageHead.svelte';
  import Icon from '../components/Icon.svelte';
  import Avatar from '../components/Avatar.svelte';
  import EmptyIllustrations from '../components/EmptyIllustrations.svelte';
  import RoleEditModal from './RoleEditModal.svelte';
  import InviteUserModal from './InviteUserModal.svelte';

  // Access check
  $effect(() => {
    if (!$roles.includes('super_admin')) {
      route.set('home');
    }
  });

  interface UserItem {
    id: string;
    full_name: string;
    username: string | null;
    email: string | null;
    phone: string | null;
    avatar_url: string | null;
    status: string;
    joined_at: string;
    deleted_at: string | null;
    roles: string[];
  }

  let users = $state<UserItem[]>([]);
  let loading = $state(true);
  let error = $state('');
  let successMsg = $state('');
  let searchQuery = $state('');
  let statusFilter = $state('all');
  let openMenuUserId = $state<string | null>(null);

  // Modals state
  let editingRolesUser = $state<UserItem | null>(null);
  let showInviteModal = $state(false);

  const roleLabels: Record<string, string> = {
    super_admin: 'الإدارة',
    mod_cultural: 'الثقافي والاستضافات',
    mod_sports: 'الرياضي',
    mod_competitions: 'المسابقات',
    mod_trips: 'الفعاليات',
    mod_hospitality: 'الضيافة',
    mod_media: 'الإعلام',
    member: 'عضو'
  };

  async function loadData() {
    loading = true;
    error = '';
    try {
      const [{ data: usersData, error: uErr }, { data: rolesData, error: rErr }] = await Promise.all([
        supabase
          .from('users')
          .select('*')
          .order('created_at', { ascending: false }),
        supabase
          .from('user_roles')
          .select('user_id, role')
      ]);

      if (uErr) throw uErr;
      if (rErr) throw rErr;

      const rolesMap = new Map<string, string[]>();
      for (const r of rolesData || []) {
        const list = rolesMap.get(r.user_id) || [];
        list.push(r.role);
        rolesMap.set(r.user_id, list);
      }

      users = (usersData || []).map((u: any) => ({
        ...u,
        roles: rolesMap.get(u.id) || ['member']
      }));
    } catch (e: any) {
      error = e.message || 'تعذّر تحميل بيانات الإدارة';
    } finally {
      loading = false;
    }
  }

  onMount(loadData);

  // User Actions
  async function toggleUserStatus(u: UserItem) {
    const newStatus = u.status === 'active' ? 'inactive' : 'active';
    const actionLabel = newStatus === 'active' ? 'تنشيط' : 'إيقاف';
    if (!confirm(`هل أنت متأكد من ${actionLabel} حساب ${u.full_name}؟`)) return;

    openMenuUserId = null;
    try {
      const { error: err } = await supabase
        .from('users')
        .update({ status: newStatus })
        .eq('id', u.id);
      if (err) throw err;
      successMsg = `تم ${actionLabel} الحساب بنجاح.`;
      setTimeout(() => (successMsg = ''), 3000);
      await loadData();
    } catch (e: any) {
      error = e.message || 'تعذّر تحديث الحالة';
    }
  }

  async function resetUserPassword(u: UserItem) {
    if (!u.email) {
      alert('لا يوجد بريد إلكتروني مسجل لهذا العضو.');
      return;
    }
    if (!confirm(`إرسال بريد استعادة كلمة المرور إلى ${u.email}؟`)) return;

    openMenuUserId = null;
    try {
      const { error: err } = await supabase.auth.resetPasswordForEmail(u.email, {
        redirectTo: window.location.origin + '/tawaq-platform/'
      });
      if (err) throw err;
      successMsg = `تم إرسال رابط إعادة تعيين كلمة السر إلى ${u.email}`;
      setTimeout(() => (successMsg = ''), 4000);
    } catch (e: any) {
      error = e.message || 'تعذّر إرسال البريد';
    }
  }

  async function softDeleteUser(u: UserItem) {
    if (!confirm(`هل أنت متأكد تماماً من حذف العضو ${u.full_name}؟`)) return;

    openMenuUserId = null;
    try {
      const { error: err } = await supabase
        .from('users')
        .update({ deleted_at: new Date().toISOString() })
        .eq('id', u.id);
      if (err) throw err;
      successMsg = `تم حذف العضو بنجاح.`;
      setTimeout(() => (successMsg = ''), 3000);
      await loadData();
    } catch (e: any) {
      error = e.message || 'تعذّر حذف العضو';
    }
  }

  const filteredUsers = $derived.by(() => {
    let list = users.filter(u => u.deleted_at === null);

    if (statusFilter === 'active') list = list.filter(u => u.status === 'active');
    else if (statusFilter === 'inactive') list = list.filter(u => u.status === 'inactive');

    const q = searchQuery.trim().toLowerCase();
    if (q) {
      list = list.filter(u => {
        const name = (u.full_name || '').toLowerCase();
        const email = (u.email || '').toLowerCase();
        const username = (u.username || '').toLowerCase();
        return name.includes(q) || email.includes(q) || username.includes(q);
      });
    }

    return list;
  });

  // System Health Stats
  const stats = $derived.by(() => {
    const total = users.filter(u => u.deleted_at === null).length;
    const active = users.filter(u => u.deleted_at === null && u.status === 'active').length;
    const inactive = users.filter(u => u.deleted_at === null && u.status === 'inactive').length;

    const roleCounts: Record<string, number> = {};
    for (const u of users.filter(u => u.deleted_at === null)) {
      for (const r of u.roles) {
        roleCounts[r] = (roleCounts[r] || 0) + 1;
      }
    }

    return { total, active, inactive, roleCounts };
  });
</script>

<PageHead
  icon={ShieldCheck}
  title="لوحة الإدارة"
  subtitle="إدارة الأعضاء، الأدوار، ومتابعة صحة المنصة"
>
  {#snippet action()}
    <button class="u-btn u-btn-primary sm" onclick={() => (showInviteModal = true)}>
      <Icon icon={Plus} size={15} />
      <span>إضافة عضو</span>
    </button>
  {/snippet}
</PageHead>

{#if error}<div class="u-alert err">{error}</div>{/if}
{#if successMsg}<div class="u-alert ok">{successMsg}</div>{/if}

<!-- Section A: Users Management -->
<section class="u-card admin-section">
  <div class="u-card-h">
    <span>إدارة الأعضاء ({filteredUsers.length})</span>
    <button class="u-btn u-btn-ghost sm" onclick={loadData} disabled={loading} title="تحديث">
      <Icon icon={RefreshCw} size={14} />
      <span>تحديث</span>
    </button>
  </div>

  <!-- Search and filter -->
  <div class="toolbar-row">
    <div class="search-wrap">
      <span class="search-ic"><Icon icon={Search} size={16} /></span>
      <input
        type="search"
        class="u-input search-input"
        placeholder="بحث بالاسم أو البريد…"
        bind:value={searchQuery}
      />
    </div>

    <div class="u-seg">
      <button
        class="seg-btn"
        class:on={statusFilter === 'all'}
        onclick={() => (statusFilter = 'all')}
      >
        الكل
      </button>
      <button
        class="seg-btn"
        class:on={statusFilter === 'active'}
        onclick={() => (statusFilter = 'active')}
      >
        النشطين
      </button>
      <button
        class="seg-btn"
        class:on={statusFilter === 'inactive'}
        onclick={() => (statusFilter = 'inactive')}
      >
        الموقوفين
      </button>
    </div>
  </div>

  {#if loading}
    <div class="u-stack">
      <div class="u-skel skel-row"></div>
      <div class="u-skel skel-row"></div>
      <div class="u-skel skel-row"></div>
    </div>
  {:else if filteredUsers.length === 0}
    <div class="u-empty">
      <EmptyIllustrations kind="generic" />
      <h3>لا يوجد أعضاء مطابقون</h3>
      <p>جرّب تعديل معايير البحث أو التصفية.</p>
    </div>
  {:else}
    <!-- Desktop Table View -->
    <div class="table-container">
      <table class="admin-table">
        <thead>
          <tr>
            <th>العضو</th>
            <th>البريد</th>
            <th>الأدوار</th>
            <th>الحالة</th>
            <th>تاريخ الانضمام</th>
            <th class="actions-col">إجراءات</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredUsers as u (u.id)}
            <tr>
              <td>
                <div class="user-cell">
                  <Avatar url={u.avatar_url} name={u.full_name} size="sm" circle={true} />
                  <div class="user-cell-info">
                    <span class="user-name">{u.full_name}</span>
                    {#if u.username}<span class="user-handle">@{u.username}</span>{/if}
                  </div>
                </div>
              </td>
              <td>
                <span class="email-text">{u.email || '—'}</span>
              </td>
              <td>
                <div class="roles-tags-cell">
                  {#each u.roles as r}
                    <span class="u-role-badge {r === 'super_admin' ? 'admin' : r.startsWith('mod_') ? 'founder' : 'member'}">
                      {roleLabels[r] || r}
                    </span>
                  {/each}
                </div>
              </td>
              <td>
                <span class="u-pill {u.status === 'active' ? 'ok' : 'bad'}">
                  {u.status === 'active' ? 'نشط' : 'موقوف'}
                </span>
              </td>
              <td>
                <span class="date-text">{u.joined_at ? new Date(u.joined_at).toLocaleDateString('ar-SA') : '—'}</span>
              </td>
              <td class="actions-col">
                <div class="row-menu-wrap">
                  <button
                    class="u-btn-icon"
                    onclick={() => (openMenuUserId = openMenuUserId === u.id ? null : u.id)}
                    aria-label="خيارات"
                  >
                    <Icon icon={MoreHorizontal} size={16} />
                  </button>

                  {#if openMenuUserId === u.id}
                    <div class="dropdown-menu">
                      <button
                        type="button"
                        class="menu-item"
                        onclick={() => { editingRolesUser = u; openMenuUserId = null; }}
                      >
                        <Icon icon={Shield} size={14} />
                        <span>تعديل الأدوار</span>
                      </button>
                      <button
                        type="button"
                        class="menu-item"
                        onclick={() => toggleUserStatus(u)}
                      >
                        <Icon icon={u.status === 'active' ? UserX : UserCheck} size={14} />
                        <span>{u.status === 'active' ? 'إيقاف الحساب' : 'تنشيط الحساب'}</span>
                      </button>
                      <button
                        type="button"
                        class="menu-item"
                        onclick={() => resetUserPassword(u)}
                      >
                        <Icon icon={KeyRound} size={14} />
                        <span>إعادة تعيين كلمة السر</span>
                      </button>
                      <button
                        type="button"
                        class="menu-item danger"
                        onclick={() => softDeleteUser(u)}
                      >
                        <Icon icon={Trash2} size={14} />
                        <span>حذف العضو</span>
                      </button>
                    </div>
                  {/if}
                </div>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    <!-- Mobile Cards View -->
    <div class="mobile-cards-list">
      {#each filteredUsers as u (u.id)}
        <div class="u-card mobile-user-card">
          <div class="mobile-card-top">
            <Avatar url={u.avatar_url} name={u.full_name} size="md" circle={true} />
            <div class="mobile-card-names">
              <div class="user-name">{u.full_name}</div>
              <div class="email-text">{u.email || (u.username ? `@${u.username}` : '')}</div>
            </div>
            <span class="u-pill {u.status === 'active' ? 'ok' : 'bad'}">
              {u.status === 'active' ? 'نشط' : 'موقوف'}
            </span>
          </div>

          <div class="roles-tags-cell">
            {#each u.roles as r}
              <span class="u-role-badge {r === 'super_admin' ? 'admin' : r.startsWith('mod_') ? 'founder' : 'member'}">
                {roleLabels[r] || r}
              </span>
            {/each}
          </div>

          <div class="mobile-card-actions">
            <button
              class="u-btn u-btn-ghost sm"
              onclick={() => (editingRolesUser = u)}
            >
              <Icon icon={Shield} size={13} />
              <span>الأدوار</span>
            </button>
            <button
              class="u-btn u-btn-ghost sm"
              onclick={() => toggleUserStatus(u)}
            >
              <Icon icon={u.status === 'active' ? UserX : UserCheck} size={13} />
              <span>{u.status === 'active' ? 'إيقاف' : 'تنشيط'}</span>
            </button>
            <button
              class="u-btn u-btn-ghost sm"
              onclick={() => resetUserPassword(u)}
              title="إعادة تعيين كلمة السر"
            >
              <Icon icon={KeyRound} size={13} />
            </button>
            <button
              class="u-btn u-btn-ghost sm danger-btn"
              onclick={() => softDeleteUser(u)}
              title="حذف"
            >
              <Icon icon={Trash2} size={13} />
            </button>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</section>

<!-- Section C: System Health Card -->
<section class="u-card health-section">
  <div class="u-card-h">
    <div class="health-title-row">
      <Icon icon={Activity} size={18} />
      <span>صحة النظام والأعضاء</span>
    </div>
  </div>

  <div class="health-grid">
    <div class="u-stat">
      <span class="lbl">إجمالي الأعضاء</span>
      <span class="num">{stats.total}</span>
    </div>
    <div class="u-stat">
      <span class="lbl">الحسابات النشطة</span>
      <span class="num">{stats.active}</span>
    </div>
    <div class="u-stat">
      <span class="lbl">الموقوفين</span>
      <span class="num">{stats.inactive}</span>
    </div>
    <div class="u-stat">
      <span class="lbl">نسبة النشاط</span>
      <span class="num">{stats.total ? Math.round((stats.active / stats.total) * 100) : 0}%</span>
    </div>
  </div>

  <div class="roles-breakdown-box">
    <div class="breakdown-head">توزيع الأعضاء حسب اللجان والأدوار</div>
    <div class="breakdown-grid">
      {#each Object.entries(stats.roleCounts) as [r, cnt]}
        <div class="role-stat-item">
          <span class="role-stat-name">{roleLabels[r] || r}</span>
          <span class="role-stat-num">{cnt}</span>
        </div>
      {/each}
    </div>
  </div>
</section>

<!-- Modals -->
{#if editingRolesUser}
  <RoleEditModal
    user={editingRolesUser}
    currentRoles={editingRolesUser.roles}
    onclose={() => (editingRolesUser = null)}
    onsaved={async () => {
      editingRolesUser = null;
      successMsg = 'تم تحديث الأدوار بنجاح.';
      setTimeout(() => (successMsg = ''), 3000);
      await loadData();
    }}
  />
{/if}

{#if showInviteModal}
  <InviteUserModal
    onclose={() => (showInviteModal = false)}
    oninvited={async () => {
      showInviteModal = false;
      await loadData();
    }}
  />
{/if}

<style>
  .admin-section {
    margin-bottom: var(--sp-3);
  }
  .toolbar-row {
    display: flex;
    gap: var(--sp-1);
    align-items: center;
    justify-content: space-between;
    margin-bottom: var(--sp-2);
    flex-wrap: wrap;
  }
  .search-wrap {
    position: relative;
    flex: 1;
    min-width: 200px;
  }
  .search-ic {
    position: absolute;
    right: var(--sp-2);
    top: 50%;
    transform: translateY(-50%);
    color: var(--ink3);
    pointer-events: none;
  }
  .search-input {
    padding-inline-start: calc(var(--sp-5) + var(--sp-1));
  }

  /* Desktop Table */
  .table-container {
    overflow-x: auto;
    display: none;
  }
  @media (min-width: 768px) {
    .table-container {
      display: block;
    }
    .mobile-cards-list {
      display: none;
    }
  }

  .admin-table {
    width: 100%;
    border-collapse: collapse;
    font-size: var(--fs-sm);
  }
  .admin-table th {
    text-align: start;
    padding: var(--sp-1) var(--sp-2);
    font: var(--fw-bold) var(--fs-xs) var(--font-sans);
    color: var(--ink3);
    border-bottom: 1px solid var(--line);
    white-space: nowrap;
  }
  .admin-table td {
    padding: var(--sp-2);
    border-bottom: 1px solid var(--line);
    vertical-align: middle;
  }
  .user-cell {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
  }
  .user-cell-info {
    display: flex;
    flex-direction: column;
  }
  .user-name {
    font: var(--fw-bold) var(--fs-sm) var(--font-sans);
    color: var(--ink);
  }
  .user-handle {
    font-size: var(--fs-tiny);
    color: var(--ink3);
  }
  .email-text {
    font-size: var(--fs-xs);
    color: var(--ink2);
  }
  .date-text {
    font-size: var(--fs-xs);
    color: var(--ink3);
    white-space: nowrap;
  }
  .roles-tags-cell {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
  }
  .actions-col {
    text-align: end;
    width: 60px;
  }
  .row-menu-wrap {
    position: relative;
    display: inline-block;
  }
  .dropdown-menu {
    position: absolute;
    left: 0;
    top: calc(100% + 4px);
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: var(--r-md);
    box-shadow: var(--shadow-lg);
    z-index: var(--z-modal);
    min-width: 190px;
    display: flex;
    flex-direction: column;
    padding: 4px 0;
  }
  .menu-item {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    padding: var(--sp-1) var(--sp-2);
    background: transparent;
    border: none;
    color: var(--ink);
    font: var(--fw-medium) var(--fs-sm) var(--font-sans);
    cursor: pointer;
    text-align: start;
    width: 100%;
  }
  .menu-item:hover {
    background: var(--muted-bg);
  }
  .menu-item.danger {
    color: var(--bad);
  }
  .menu-item.danger:hover {
    background: var(--bad-soft);
  }

  /* Mobile cards */
  .mobile-cards-list {
    display: flex;
    flex-direction: column;
    gap: var(--sp-1);
  }
  .mobile-user-card {
    display: flex;
    flex-direction: column;
    gap: var(--sp-1);
    padding: var(--sp-2);
  }
  .mobile-card-top {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
  }
  .mobile-card-names {
    flex: 1;
    min-width: 0;
  }
  .mobile-card-actions {
    display: flex;
    gap: var(--sp-05);
    flex-wrap: wrap;
    margin-top: var(--sp-1);
    padding-top: var(--sp-1);
    border-top: 1px solid var(--line);
  }

  /* Health section */
  .health-title-row {
    display: inline-flex;
    align-items: center;
    gap: var(--sp-1);
    color: var(--brand);
  }
  .health-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: var(--sp-1);
    margin-bottom: var(--sp-2);
  }
  @media (min-width: 600px) {
    .health-grid {
      grid-template-columns: repeat(4, 1fr);
    }
  }
  .roles-breakdown-box {
    background: var(--muted-bg);
    border: 1px solid var(--line);
    border-radius: var(--r-md);
    padding: var(--sp-2);
  }
  .breakdown-head {
    font: var(--fw-bold) var(--fs-xs) var(--font-sans);
    color: var(--ink3);
    text-transform: uppercase;
    letter-spacing: var(--tracking-wide);
    margin-bottom: var(--sp-1);
  }
  .breakdown-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: var(--sp-1);
  }
  @media (min-width: 600px) {
    .breakdown-grid {
      grid-template-columns: repeat(4, 1fr);
    }
  }
  .role-stat-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: var(--card);
    padding: var(--sp-1) var(--sp-2);
    border-radius: var(--r-sm);
    font-size: var(--fs-xs);
  }
  .role-stat-name {
    color: var(--ink2);
  }
  .role-stat-num {
    font: var(--fw-bold) var(--fs-sm) var(--font-num);
    color: var(--brand);
  }
  .skel-row {
    height: 60px;
    border-radius: var(--r-md);
  }
  .danger-btn:hover {
    background: var(--bad-soft);
    color: var(--bad);
    border-color: var(--bad-soft);
  }
</style>
