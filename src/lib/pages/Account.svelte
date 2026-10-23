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

<div class="profile-card">
  <div class="avatar">{initials($profile?.full_name || 'ع')}</div>
  <div class="name">{$profile?.full_name || 'عضو جديد'}</div>
  <div class="email">{$session?.user?.email}</div>
  <div class="roles">
    {#each $roles as r (r)}
      <span class="role">{roleLabels[r] || r}</span>
    {/each}
    {#if $roles.length === 0}
      <span class="role">{roleLabels.member}</span>
    {/if}
  </div>
</div>

<div class="info-card">
  <h3>📋 المعلومات</h3>
  <div class="row"><span>اسم المستخدم</span><b>{$profile?.username || '—'}</b></div>
  <div class="row"><span>الجوال</span><b>{$profile?.phone || '—'}</b></div>
  <div class="row"><span>البريد</span><b>{$session?.user?.email}</b></div>
  <div class="row"><span>تاريخ الانضمام</span><b>{$profile?.joined_at ? new Date($profile.joined_at).toLocaleDateString('ar-SA') : '—'}</b></div>
</div>

<button class="logout" onclick={logout}>تسجيل الخروج</button>

<style>
  .profile-card {
    background: linear-gradient(155deg, var(--brand) 0%, #1A4536 100%);
    color: var(--on-brand);
    border-radius: 20px;
    padding: 28px 20px;
    text-align: center;
    box-shadow: var(--shadow-lg);
    margin-bottom: 14px;
    position: relative;
    overflow: hidden;
  }
  .profile-card::before {
    content: '';
    position: absolute;
    top: -40px; left: -40px;
    width: 160px; height: 160px;
    background: var(--gold);
    opacity: .1;
    clip-path: polygon(25% 5%, 75% 5%, 100% 50%, 75% 95%, 25% 95%, 0 50%);
  }
  .avatar {
    width: 72px; height: 72px;
    border-radius: 50%;
    background: var(--gold);
    color: var(--brand);
    font-weight: 700;
    font-size: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto 14px;
    border: 3px solid rgba(255, 255, 255, 0.2);
    position: relative;
  }
  .name { font-size: 18px; font-weight: 700; margin-bottom: 4px; position: relative; }
  .email { color: var(--gold-bright); font-size: 12.5px; margin-bottom: 14px; position: relative; }
  .roles {
    display: flex;
    gap: 6px;
    justify-content: center;
    flex-wrap: wrap;
    position: relative;
  }
  .role {
    background: rgba(255, 255, 255, 0.14);
    color: #fff;
    padding: 5px 12px;
    border-radius: 999px;
    font-size: 11.5px;
    font-weight: 600;
  }

  .info-card {
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: 18px;
    padding: 18px;
    box-shadow: var(--shadow);
    margin-bottom: 14px;
  }
  .info-card h3 {
    color: var(--brand);
    font-size: 14px;
    margin-bottom: 12px;
  }
  .row {
    display: flex;
    justify-content: space-between;
    padding: 10px 0;
    border-bottom: 1px dashed var(--line);
    font-size: 13px;
  }
  .row:last-child { border-bottom: none; }
  .row span { color: var(--ink3); }
  .row b { color: var(--ink); font-weight: 600; }

  .logout {
    display: block;
    width: 100%;
    padding: 13px;
    background: var(--bad);
    color: #fff;
    border: none;
    border-radius: 12px;
    font-family: inherit;
    font-size: 13.5px;
    font-weight: 600;
    cursor: pointer;
    margin-top: 6px;
  }
  .logout:hover { filter: brightness(1.1); }
</style>
