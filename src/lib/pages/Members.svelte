<script lang="ts">
  import { onMount } from 'svelte';
  import {
    MessageCircle,
    Phone,
    Search,
    X
  } from 'lucide-svelte';
  import { supabase } from '../supabase';
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

<div class="u-page">
  <div class="u-top">
    <div>
      <div class="u-sub">{members.length} عضو</div>
      <h1>دليل الأعضاء</h1>
    </div>
  </div>

  <div class="u-search">
    <Icon icon={Search} size={18} />
    <input
      type="search"
      placeholder="ابحث بالاسم أو النبذة…"
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

  <div class="u-chips">
    <button
      class="u-chip"
      class:on={selectedRole === 'all'}
      onclick={() => (selectedRole = 'all')}
    >
      الكل <span class="chip-count">{members.length}</span>
    </button>
    {#each availableRoles as role (role)}
      <button
        class="u-chip"
        class:on={selectedRole === role}
        onclick={() => (selectedRole = role)}
      >
        {roleLabels[role] || role} <span class="chip-count">{roleCounts[role] || 0}</span>
      </button>
    {/each}
  </div>

  {#if loading}
    <section class="u-card flush">
      <div class="u-list">
        {#each Array(6) as _}
          <div class="u-item">
            <div class="u-skel skel-avatar"></div>
            <div class="u-grow"><div class="u-skel skel-line"></div></div>
          </div>
        {/each}
      </div>
    </section>
  {:else if error}
    <div class="u-alert err">{error}</div>
  {:else if filteredMembers.length === 0}
    <div class="u-empty">
      <EmptyIllustrations kind="generic" />
      <h3>لا يوجد أعضاء مطابقون</h3>
      <p>جرّب تغيير كلمات البحث أو تصفية الأدوار.</p>
    </div>
  {:else}
    <section class="u-card flush">
      <div class="u-list">
        {#each filteredMembers as member (member.id)}
          <div
            class="u-item tap member-row"
            onclick={() => (selectedMember = member)}
            onkeydown={(e) => e.key === 'Enter' && (selectedMember = member)}
            tabindex="0" role="button"
          >
            <Avatar
              url={member.avatar_url}
              name={member.full_name}
              hex={true}
              size="sm"
              featured={member.primary_role === 'super_admin'}
            />
            <div class="u-grow">
              <div class="u-name">{member.full_name}</div>
              <div class="u-muted">
                {roleLabels[member.primary_role] || member.primary_role}
                {#if member.region}· {member.region}{/if}
              </div>
            </div>
            <div class="row-actions" onclick={(e) => e.stopPropagation()} role="presentation">
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
    </section>
  {/if}
</div>

{#if selectedMember}
  <MemberDetail
    member={selectedMember}
    onclose={() => (selectedMember = null)}
    onupdate={loadMembers}
  />
{/if}

<style>
  .u-search {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    height: 46px;
    border-radius: var(--r-md);
    background: var(--card);
    border: 1px solid var(--line);
    padding: 0 var(--sp-2);
    color: var(--ink3);
    margin-bottom: var(--sp-2);
  }
  .u-search input {
    flex: 1;
    border: 0;
    outline: 0;
    background: transparent;
    color: var(--ink);
    font-family: inherit;
    font-size: 16px;
    min-width: 0;
  }
  .clear-search {
    background: transparent;
    border: none;
    color: var(--ink3);
    cursor: pointer;
    display: grid;
    place-items: center;
    padding: 4px;
  }
  .clear-search:hover { color: var(--ink); }

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

  .member-row { padding: 10px 0; gap: var(--sp-2); }
  .row-actions {
    display: flex;
    gap: var(--sp-05);
    flex-shrink: 0;
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
  .skel-avatar { width: 40px; height: 40px; border-radius: 50%; flex-shrink: 0; }
  .skel-line { height: 14px; width: 60%; }
</style>
