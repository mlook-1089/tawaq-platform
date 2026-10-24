<script lang="ts">
  import { onMount } from 'svelte';
  import {
    Contact,
    MessageCircle,
    Phone,
    Search,
    Shield,
    ShieldCheck,
    User,
    Users,
    X
  } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import PageHead from '../components/PageHead.svelte';
  import Icon from '../components/Icon.svelte';
  import Avatar from '../components/Avatar.svelte';
  import EmptyIllustrations from '../components/EmptyIllustrations.svelte';
  import MemberDetail from './MemberDetail.svelte';

  interface Member {
    id: string;
    full_name: string;
    username: string | null;
    avatar_url: string | null;
    bio: string | null;
    region: string | null;
    profession: string | null;
    phone: string | null;
    email: string | null;
    birthday: string | null;
    status: string;
    joined_at: string;
    roles: string[];
    primary_role: string;
  }

  let members = $state<Member[]>([]);
  let loading = $state(true);
  let error = $state('');
  let searchQuery = $state('');
  let debouncedSearch = $state('');
  let selectedRole = $state('all');
  let selectedMember = $state<Member | null>(null);

  let searchTimer: ReturnType<typeof setTimeout> | undefined;

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

  const availableRoles = $derived.by(() => {
    const set = new Set<string>();
    for (const m of members) {
      for (const r of m.roles) set.add(r);
    }
    return Array.from(set);
  });

  const roleCounts = $derived.by(() => {
    const counts: Record<string, number> = {};
    for (const m of members) {
      for (const r of m.roles) {
        counts[r] = (counts[r] || 0) + 1;
      }
    }
    return counts;
  });

  function getPrimaryRole(roles: string[]): string {
    if (roles.includes('super_admin')) return 'super_admin';
    const mod = roles.find(r => r.startsWith('mod_'));
    if (mod) return mod;
    return 'member';
  }

  function formatWaLink(phone: string | null): string {
    if (!phone) return '';
    let p = phone.replace(/\D/g, '');
    if (p.startsWith('05')) p = '966' + p.slice(1);
    else if (p.startsWith('5')) p = '966' + p;
    return `https://wa.me/${p}`;
  }

  async function loadMembers() {
    loading = true;
    error = '';
    try {
      const [{ data: usersData, error: usersErr }, { data: rolesData, error: rolesErr }] = await Promise.all([
        supabase
          .from('users')
          .select('*')
          .is('deleted_at', null)
          .order('full_name', { ascending: true }),
        supabase
          .from('user_roles')
          .select('user_id, role')
      ]);

      if (usersErr) throw usersErr;
      if (rolesErr) throw rolesErr;

      const rolesMap = new Map<string, string[]>();
      for (const r of rolesData || []) {
        const list = rolesMap.get(r.user_id) || [];
        list.push(r.role);
        rolesMap.set(r.user_id, list);
      }

      members = (usersData || []).map((u: any) => {
        const userRoles = rolesMap.get(u.id) || ['member'];
        return {
          ...u,
          roles: userRoles,
          primary_role: getPrimaryRole(userRoles)
        };
      });
    } catch (err: any) {
      error = err.message || 'تعذّر تحميل قائمة الأعضاء';
    } finally {
      loading = false;
    }
  }

  onMount(loadMembers);

  function handleSearchInput(e: Event) {
    const val = (e.target as HTMLInputElement).value;
    searchQuery = val;
    if (searchTimer) clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      debouncedSearch = val.trim().toLowerCase();
    }, 300);
  }

  const filteredMembers = $derived.by(() => {
    let list = members;

    if (selectedRole !== 'all') {
      list = list.filter(m => m.roles.includes(selectedRole));
    }

    if (debouncedSearch) {
      list = list.filter(m => {
        const name = (m.full_name || '').toLowerCase();
        const username = (m.username || '').toLowerCase();
        const bio = (m.bio || '').toLowerCase();
        const region = (m.region || '').toLowerCase();
        return (
          name.includes(debouncedSearch) ||
          username.includes(debouncedSearch) ||
          bio.includes(debouncedSearch) ||
          region.includes(debouncedSearch)
        );
      });
    }

    return list;
  });
</script>

<PageHead
  icon={Contact}
  title="دليل الأعضاء"
  subtitle={`أعضاء مجموعة تواق (${members.length})`}
/>

<!-- Search Bar -->
<div class="search-box">
  <div class="search-input-wrap">
    <span class="search-icon"><Icon icon={Search} size={18} /></span>
    <input
      type="search"
      class="u-input search-input"
      placeholder="ابحث بالاسم، اسم المستخدم، أو النبذة…"
      value={searchQuery}
      oninput={handleSearchInput}
    />
    {#if searchQuery}
      <button
        class="clear-search"
        onclick={() => { searchQuery = ''; debouncedSearch = ''; }}
        aria-label="مسح البحث"
      >
        <Icon icon={X} size={16} />
      </button>
    {/if}
  </div>
</div>

<!-- Filter chips -->
<div class="filters">
  <div class="u-chips">
    <button
      class="u-chip"
      class:on={selectedRole === 'all'}
      onclick={() => (selectedRole = 'all')}
    >
      الكل ({members.length})
    </button>
    {#each availableRoles as role (role)}
      <button
        class="u-chip"
        class:on={selectedRole === role}
        onclick={() => (selectedRole = role)}
      >
        {roleLabels[role] || role} ({roleCounts[role] || 0})
      </button>
    {/each}
  </div>
</div>

{#if loading}
  <div class="members-grid">
    {#each Array(6) as _}
      <div class="u-skel member-card-skel"></div>
    {/each}
  </div>
{:else if error}
  <div class="u-alert err">{error}</div>
{:else if filteredMembers.length === 0}
  <div class="u-empty">
    <EmptyIllustrations kind="generic" />
    <h3>لا يوجد أعضاء مطابقون</h3>
    <p>جرّب تغيير كلمات البحث أو تصفية الأدوار.</p>
  </div>
{:else}
  <div class="members-grid">
    {#each filteredMembers as member (member.id)}
      <div
        class="u-card interactive member-card"
        onclick={() => (selectedMember = member)}
        onkeydown={(e) => e.key === 'Enter' && (selectedMember = member)}
        tabindex="0"
        role="button"
      >
        <div class="card-avatar">
          <Avatar
            url={member.avatar_url}
            name={member.full_name}
            hex={true}
            size="lg"
            featured={member.primary_role === 'super_admin'}
          />
        </div>

        <div class="card-info">
          <div class="member-name">{member.full_name}</div>
          <div class="badge-line">
            <span class="u-role-badge {member.primary_role === 'super_admin' ? 'admin' : member.primary_role.startsWith('mod_') ? 'founder' : 'member'}">
              {roleLabels[member.primary_role] || member.primary_role}
            </span>
          </div>
          {#if member.region || member.profession}
            <div class="member-meta">
              {member.region || member.profession}
            </div>
          {/if}
        </div>

        <div class="card-actions" onclick={(e) => e.stopPropagation()} role="presentation">
          {#if member.phone}
            <a
              href={formatWaLink(member.phone)}
              target="_blank"
              rel="noopener noreferrer"
              class="u-btn-icon wa-btn"
              title="واتساب"
              aria-label="واتساب"
            >
              <Icon icon={MessageCircle} size={16} />
            </a>
            <a
              href={`tel:${member.phone}`}
              class="u-btn-icon call-btn"
              title="اتصال"
              aria-label="اتصال"
            >
              <Icon icon={Phone} size={16} />
            </a>
          {/if}
        </div>
      </div>
    {/each}
  </div>
{/if}

{#if selectedMember}
  <MemberDetail
    member={selectedMember}
    onclose={() => (selectedMember = null)}
    onupdate={loadMembers}
  />
{/if}

<style>
  .search-box {
    margin-bottom: var(--sp-2);
  }
  .search-input-wrap {
    position: relative;
    display: flex;
    align-items: center;
  }
  .search-icon {
    position: absolute;
    right: var(--sp-2);
    color: var(--ink3);
    pointer-events: none;
    display: grid;
    place-items: center;
  }
  .search-input {
    padding-inline-start: calc(var(--sp-5) + var(--sp-1));
    padding-inline-end: var(--sp-5);
  }
  .clear-search {
    position: absolute;
    left: var(--sp-2);
    background: transparent;
    border: none;
    color: var(--ink3);
    cursor: pointer;
    display: grid;
    place-items: center;
    padding: var(--sp-05);
  }
  .clear-search:hover {
    color: var(--ink);
  }

  .filters {
    margin-bottom: var(--sp-3);
  }

  .members-grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--sp-2);
  }

  @media (min-width: 480px) {
    .members-grid {
      grid-template-columns: repeat(2, 1fr);
    }
  }

  @media (min-width: 768px) {
    .members-grid {
      grid-template-columns: repeat(3, 1fr);
    }
  }

  .member-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    padding: var(--sp-3);
    position: relative;
    gap: var(--sp-1);
  }

  .card-avatar {
    margin-bottom: var(--sp-1);
    display: flex;
    justify-content: center;
  }

  .card-info {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    width: 100%;
  }

  .member-name {
    font: var(--fw-bold) var(--fs-base) var(--font-sans);
    color: var(--ink);
    line-height: var(--lh-tight);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 100%;
  }

  .badge-line {
    margin-top: 2px;
  }

  .member-meta {
    font-size: var(--fs-xs);
    color: var(--ink3);
    margin-top: 2px;
  }

  .card-actions {
    display: flex;
    gap: var(--sp-1);
    margin-top: var(--sp-2);
    justify-content: center;
  }

  .wa-btn:hover {
    background: var(--ok-soft);
    color: var(--ok);
    border-color: var(--ok-soft);
  }

  .call-btn:hover {
    background: var(--brand-soft);
    color: var(--brand-ink);
    border-color: var(--brand-soft);
  }

  .member-card-skel {
    height: 200px;
    border-radius: var(--r-xl);
  }
</style>
