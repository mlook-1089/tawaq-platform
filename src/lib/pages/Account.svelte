<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../supabase';
  import { session, profile, roles } from '../stores';
  import { getPushStatus, subscribeToPush, unsubscribeFromPush, type PushStatus } from '../push';
  import PageHead from '../components/PageHead.svelte';

  let pushStatus = $state<PushStatus>('not-subscribed');
  let pushBusy = $state(true);
  let pushMessage = $state('');

  const pushStatusLabels: Record<PushStatus, string> = {
    unsupported: 'غير مدعوم',
    denied: 'محظور',
    subscribed: 'مفعّلة',
    'not-subscribed': 'غير مفعّلة'
  };

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

  async function togglePush() {
    const userId = $session?.user.id;
    if (!userId || pushBusy || pushStatus === 'unsupported' || pushStatus === 'denied') return;
    pushBusy = true;
    pushMessage = '';
    try {
      pushStatus = pushStatus === 'subscribed'
        ? await unsubscribeFromPush(userId)
        : await subscribeToPush(userId);
      pushMessage = pushStatus === 'subscribed' ? 'تم تفعيل الإشعارات على هذا الجهاز.' : 'تم إيقاف الإشعارات على هذا الجهاز.';
    } catch (error: any) {
      pushMessage = error?.message || 'تعذّر تحديث إعداد الإشعارات.';
    } finally {
      pushBusy = false;
    }
  }

  onMount(() => {
    void (async () => {
      try {
        pushStatus = await getPushStatus();
      } catch {
        pushStatus = 'not-subscribed';
      } finally {
        pushBusy = false;
      }
    })();
  });
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

<section class="u-card push-card">
  <div class="u-row">
    <div class="push-icon" aria-hidden="true">🔔</div>
    <div class="u-list-main">
      <div class="u-list-title">الإشعارات</div>
      <div class="u-list-sub">تنبيهات التكليفات وطلبات التبديل</div>
    </div>
    <span class="u-pill" class:ok={pushStatus === 'subscribed'} class:warn={pushStatus === 'denied'}>
      {pushStatusLabels[pushStatus]}
    </span>
  </div>
  <button
    class="u-btn block push-toggle"
    class:u-btn-primary={pushStatus !== 'subscribed'}
    class:u-btn-ghost={pushStatus === 'subscribed'}
    role="switch"
    aria-checked={pushStatus === 'subscribed'}
    disabled={pushBusy || pushStatus === 'unsupported' || pushStatus === 'denied'}
    onclick={togglePush}
  >
    {pushBusy ? 'جارٍ التحقق…' : pushStatus === 'subscribed' ? 'إيقاف الإشعارات' : 'تفعيل الإشعارات'}
  </button>
  {#if pushStatus === 'denied'}
    <div class="u-alert warn">اسمح بالإشعارات من إعدادات المتصفح ثم أعد فتح المنصة.</div>
  {:else if pushStatus === 'unsupported'}
    <div class="u-alert info">هذا المتصفح لا يدعم الإشعارات الدافعة.</div>
  {:else if pushMessage}
    <div class="u-alert" class:ok={pushStatus === 'subscribed'}>{pushMessage}</div>
  {/if}
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
  .push-card { display: flex; flex-direction: column; gap: var(--sp-2); margin-bottom: var(--sp-2); }
  .push-icon {
    width: var(--touch);
    height: var(--touch);
    display: grid;
    place-items: center;
    background: var(--gold-soft);
    border-radius: var(--r-md);
    font-size: var(--fs-xl);
    flex-shrink: 0;
  }
  .push-toggle { margin-top: var(--sp-1); }
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
