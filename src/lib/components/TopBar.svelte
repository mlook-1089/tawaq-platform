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

<header class="u-topbar">
  <div class="u-brand-chip">
    <span class="hex"></span>
    مجموعة تواق
  </div>
  <button class="user-btn" onclick={() => route.set('account')} aria-label="فتح حسابي">
    <span class="u-role-badge {primaryRole === 'super_admin' ? 'admin' : 'member'}">{roleLabels[primaryRole] || 'عضو'}</span>
    <span class="u-avatar circle sm u-avatar-brand">{initials($profile?.full_name || 'ع')}</span>
  </button>
</header>

<style>
  .user-btn {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    background: transparent;
    border: none;
    padding: 2px;
    cursor: pointer;
    min-height: var(--touch);
  }
  .user-btn:focus-visible {
    outline: 2px solid var(--brand-ink);
    outline-offset: 2px;
    border-radius: var(--r-pill);
  }
</style>
