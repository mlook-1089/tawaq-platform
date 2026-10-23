<script lang="ts">
  import { profile, roles, route } from '../stores';

  const roleLabels: Record<string, string> = {
    super_admin: 'الإدارة',
    mod_cultural: 'لجنة ثقافي',
    mod_sports: 'لجنة الرياضي',
    mod_competitions: 'لجنة المسابقات',
    mod_trips: 'لجنة الفعاليات',
    mod_hospitality: 'لجنة الضيافة',
    mod_media: 'لجنة الإعلام',
    member: 'عضو'
  };

  function initials(name: string) {
    const parts = String(name || '').trim().split(/\s+/);
    return (parts[0] || '').charAt(0) + ((parts[1] || '').charAt(0) || '');
  }

  const primaryRole = $derived($roles[0] || 'member');
</script>

<header class="topbar">
  <div class="brand">
    <div class="hex"></div>
    <span>مجموعة تواق</span>
  </div>
  <button class="user" onclick={() => route.set('account')}>
    <span class="rolebadge">{roleLabels[primaryRole] || 'عضو'}</span>
    <div class="avatar">{initials($profile?.full_name || 'ع')}</div>
  </button>
</header>

<style>
  .topbar {
    padding: calc(10px + env(safe-area-inset-top)) 18px 10px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: var(--bg);
    border-bottom: 1px solid var(--line);
    position: sticky;
    top: 0;
    z-index: 10;
  }
  .brand {
    display: flex;
    align-items: center;
    gap: 9px;
    font-weight: 700;
    font-size: 15.5px;
    color: var(--brand);
  }
  .hex {
    width: 14px; height: 14px;
    background: var(--gold);
    clip-path: polygon(25% 5%, 75% 5%, 100% 50%, 75% 95%, 25% 95%, 0 50%);
  }
  .user {
    display: flex;
    align-items: center;
    gap: 8px;
    background: transparent;
    border: none;
    padding: 2px;
    cursor: pointer;
  }
  .rolebadge {
    font-size: 10.5px;
    font-weight: 600;
    background: var(--card);
    color: var(--brand);
    border: 1px solid var(--line);
    border-radius: 999px;
    padding: 5px 11px;
    box-shadow: var(--shadow);
  }
  .avatar {
    width: 36px; height: 36px;
    border-radius: 50%;
    background: var(--brand);
    color: var(--gold-bright);
    font-weight: 700;
    font-size: 13px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 2px solid var(--gold-bright);
  }
</style>
