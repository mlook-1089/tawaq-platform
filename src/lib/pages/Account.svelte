<script lang="ts">
  import { onMount } from 'svelte';
  import { Bell, CircleUserRound, LogOut, ShieldCheck, User } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { session, profile, roles } from '../stores';
  import { getPushStatus, subscribeToPush, unsubscribeFromPush, type PushStatus } from '../push';
  import { initials } from '../utils';
  import PageHead from '../components/PageHead.svelte';
  import Icon from '../components/Icon.svelte';

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
    super_admin: 'الإدارة',
    mod_cultural: 'لجنة الثقافي والاستضافات',
    mod_sports: 'لجنة الرياضي',
    mod_competitions: 'لجنة المسابقات',
    mod_trips: 'لجنة الفعاليات',
    mod_hospitality: 'لجنة الاجتماعية والضيافة',
    mod_media: 'لجنة التصميم والإعلام',
    member: 'عضو'
  };

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

<PageHead icon={CircleUserRound} title="حسابي" subtitle="بيانات العضوية وتفضيلات هذا الجهاز" />

<article class="profile-card">
  <div class="avatar-wrap">
    <div class="u-avatar circle xl u-avatar-brand">{initials($profile?.full_name || 'ع')}</div>
  </div>
  <h2>{$profile?.full_name || 'عضو جديد'}</h2>
  <p>{$session?.user?.email}</p>
  <div class="roles-row">
    {#each $roles as r (r)}
      <span class="u-pill {r === 'super_admin' ? 'brand' : ''}"><Icon icon={r === 'super_admin' ? ShieldCheck : User} size={12} />{roleLabels[r] || r}</span>
    {/each}
    {#if $roles.length === 0}
      <span class="u-pill"><Icon icon={User} size={12} />{roleLabels.member}</span>
    {/if}
  </div>
</article>

<section class="u-card info-card">
  <div class="u-card-h">المعلومات</div>
  <ul class="info-list">
    <li><span>اسم المستخدم</span><b>{$profile?.username || '—'}</b></li>
    <li><span>الجوال</span><b>{$profile?.phone || '—'}</b></li>
    <li><span>البريد</span><b>{$session?.user?.email}</b></li>
    <li><span>تاريخ الانضمام</span><b>{$profile?.joined_at ? new Date($profile.joined_at).toLocaleDateString('ar-SA') : '—'}</b></li>
  </ul>
</section>

<section class="u-card push-card">
  <div class="u-row">
    <div class="push-icon"><Icon icon={Bell} size={19} /></div>
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

<button class="u-btn u-btn-ghost block logout-btn" onclick={logout}><Icon icon={LogOut} size={16} /> تسجيل الخروج</button>

<style>
  .profile-card {
    text-align: center;
    padding: var(--sp-5) var(--sp-3);
    border-bottom: 1px solid var(--line);
  }
  .profile-card h2 { margin: 0; font: var(--fw-bold) var(--fs-xl) var(--font-sans); color: var(--ink); }
  .profile-card p { margin: var(--sp-05) 0 0; color: var(--ink3); font-size: var(--fs-sm); }
  .avatar-wrap {
    margin-bottom: var(--sp-2);
    position: relative;
  }
  .profile-card :global(.u-avatar) { border: 1px solid var(--line); }

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
    background: var(--brand-soft);
    color: var(--brand);
    border-radius: var(--r-xs);
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
    border-bottom: 1px solid var(--line);
    font-size: var(--fs-sm);
  }
  .info-list li:last-child { border-bottom: none; }
  .info-list li span { color: var(--ink3); }
  .info-list li b { color: var(--ink); font-weight: var(--fw-semi); }

  .logout-btn { margin-top: var(--sp-2); color: var(--bad); }
  .block { width: 100%; }
</style>
