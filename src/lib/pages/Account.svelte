<script lang="ts">
  import { supabase } from '../supabase';
  import { session, profile, roles } from '../stores';
  import PageHead from '../components/PageHead.svelte';

  const roleLabels: Record<string, string> = {
    super_admin: '🛡️ الإدارة',
    mod_cultural: '📚 لجنة الثقافي والاستضافات',
    mod_sports: '⚽ لجنة الرياضي',
    mod_competitions: '🏆 لجنة المسابقات',
    mod_trips: '🏕️ لجنة الفعاليات',
    mod_hospitality: '🫖 لجنة الاجتماعية والضيافة',
    mod_media: '🎨 لجنة التصميم والإعلام',
    member: '👤 عضو'
  };

  function initials(name: string) {
    const parts = String(name || '').trim().split(/\s+/);
    return (parts[0] || '').charAt(0) + ((parts[1] || '').charAt(0) || '');
  }

  async function logout() {
    if (!confirm('تسجيل الخروج؟')) return;
    await supabase.auth.signOut();
  }
</script>

<PageHead icon="👤" title="حسابي" />

<article class="u-hero profile-hero">
  <div class="avatar-wrap">
    <div class="u-avatar circle xl u-avatar-brand">{initials($profile?.full_name || 'ع')}</div>
  </div>
  <h2>{$profile?.full_name || 'عضو جديد'}</h2>
  <p>{$session?.user?.email}</p>
  <div class="roles-row">
    {#each $roles as r (r)}
      <span class="u-role-badge {r === 'super_admin' ? 'admin' : 'member'}">{roleLabels[r] || r}</span>
    {/each}
    {#if $roles.length === 0}
      <span class="u-role-badge member">{roleLabels.member}</span>
    {/if}
  </div>
</article>

<section class="u-card info-card">
  <div class="u-card-h">📋 المعلومات</div>
  <ul class="info-list">
    <li><span>اسم المستخدم</span><b>{$profile?.username || '—'}</b></li>
    <li><span>الجوال</span><b>{$profile?.phone || '—'}</b></li>
    <li><span>البريد</span><b>{$session?.user?.email}</b></li>
    <li><span>تاريخ الانضمام</span><b>{$profile?.joined_at ? new Date($profile.joined_at).toLocaleDateString('ar-SA') : '—'}</b></li>
  </ul>
</section>

<button class="u-btn u-btn-danger block logout-btn" onclick={logout}>تسجيل الخروج</button>

<style>
  .profile-hero {
    text-align: center;
    padding: var(--sp-5) var(--sp-3);
    margin-bottom: var(--sp-2);
  }
  .avatar-wrap {
    margin-bottom: var(--sp-2);
    position: relative;
  }
  .profile-hero :global(.u-avatar) {
    border: 3px solid rgba(255,255,255,0.2);
  }

  .roles-row {
    display: flex;
    gap: var(--sp-05);
    justify-content: center;
    flex-wrap: wrap;
    margin-top: var(--sp-2);
    position: relative;
  }

  .info-card { margin-bottom: var(--sp-2); }
  .info-list {
    list-style: none;
    padding: 0;
    margin: 0;
  }
  .info-list li {
    display: flex;
    justify-content: space-between;
    padding: var(--sp-1) 0;
    border-bottom: 1px dashed var(--line);
    font-size: var(--fs-sm);
  }
  .info-list li:last-child { border-bottom: none; }
  .info-list li span { color: var(--ink3); }
  .info-list li b { color: var(--ink); font-weight: var(--fw-semi); }

  .logout-btn { margin-top: var(--sp-2); }
  .block { width: 100%; }
</style>
