<script lang="ts">
  import { onMount } from 'svelte';
  import {
    Bell,
    Briefcase,
    Calendar,
    CircleUserRound,
    Edit3,
    LogOut,
    MapPin,
    ShieldCheck,
    User,
    Users
  } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { session, profile, roles, route, isAdmin } from '../stores';
  import { getPushStatus, subscribeToPush, unsubscribeFromPush, type PushStatus } from '../push';
  import PageHead from '../components/PageHead.svelte';
  import Icon from '../components/Icon.svelte';
  import Avatar from '../components/Avatar.svelte';
  import ProfileEditModal from '../components/ProfileEditModal.svelte';

  let pushStatus = $state<PushStatus>('not-subscribed');
  let pushBusy = $state(true);
  let pushMessage = $state('');
  let showEditModal = $state(false);

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
    <Avatar
      url={$profile?.avatar_url}
      name={$profile?.full_name || 'ع'}
      size="xl"
      circle={true}
    />
  </div>
  <h2>{$profile?.full_name || 'عضو جديد'}</h2>
  <p class="user-email">{$session?.user?.email}</p>

  {#if $profile?.bio}
    <p class="user-bio">{$profile.bio}</p>
  {/if}

  {#if $profile?.region || $profile?.profession}
    <div class="profile-meta-row">
      {#if $profile?.region}
        <span class="meta-tag"><Icon icon={MapPin} size={14} /> {$profile.region}</span>
      {/if}
      {#if $profile?.profession}
        <span class="meta-tag"><Icon icon={Briefcase} size={14} /> {$profile.profession}</span>
      {/if}
      {#if $profile?.birthday}
        <span class="meta-tag"><Icon icon={Calendar} size={14} /> {$profile.birthday}</span>
      {/if}
    </div>
  {/if}

  {#if Array.isArray($profile?.interests) && $profile.interests.length > 0}
    <div class="interests-tags">
      {#each $profile.interests as tag}
        <span class="u-pill brand">#{tag}</span>
      {/each}
    </div>
  {/if}

  <div class="roles-row">
    {#each $roles as r (r)}
      <span class="u-pill {r === 'super_admin' ? 'gold' : ''}">
        <Icon icon={r === 'super_admin' ? ShieldCheck : User} size={12} />
        {roleLabels[r] || r}
      </span>
    {/each}
    {#if $roles.length === 0}
      <span class="u-pill"><Icon icon={User} size={12} />{roleLabels.member}</span>
    {/if}
  </div>

  <div class="profile-actions">
    <button class="u-btn u-btn-primary sm" onclick={() => (showEditModal = true)}>
      <Icon icon={Edit3} size={15} />
      <span>تعديل الملف الشخصي</span>
    </button>
  </div>
</article>

{#if $isAdmin}
  <button class="u-card interactive admin-card" onclick={() => route.set('admin')}>
    <div class="admin-icon"><Icon icon={ShieldCheck} size={20} /></div>
    <div class="admin-text">
      <div class="admin-title">لوحة الإدارة</div>
      <div class="admin-sub">إدارة الأعضاء، الأدوار، وصحة النظام</div>
    </div>
  </button>
{/if}

<button class="u-card interactive nav-card" onclick={() => route.set('members')}>
  <div class="nav-card-icon"><Icon icon={Users} size={20} /></div>
  <div class="nav-card-text">
    <div class="nav-card-title">دليل الأعضاء</div>
    <div class="nav-card-sub">تصفح ملفات الأعضاء والتواصل معهم</div>
  </div>
</button>

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

<button class="u-btn u-btn-ghost block logout-btn" onclick={logout}>
  <Icon icon={LogOut} size={16} /> تسجيل الخروج
</button>

{#if showEditModal}
  <ProfileEditModal
    onclose={() => (showEditModal = false)}
    onsaved={() => (showEditModal = false)}
  />
{/if}

<style>
  .profile-card {
    text-align: center;
    padding: var(--sp-4) var(--sp-3);
    border: 1px solid var(--line);
    border-radius: var(--r-xl);
    background: var(--card);
    margin-bottom: var(--sp-2);
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--sp-1);
  }
  .avatar-wrap {
    margin-bottom: var(--sp-1);
  }
  .profile-card h2 {
    margin: 0;
    font: var(--fw-bold) var(--fs-xl) var(--font-sans);
    color: var(--ink);
  }
  .user-email {
    margin: 0;
    color: var(--ink3);
    font-size: var(--fs-sm);
  }
  .user-bio {
    margin: var(--sp-1) 0 0;
    color: var(--ink2);
    font-size: var(--fs-sm);
    line-height: var(--lh-base);
    max-width: 440px;
  }
  .profile-meta-row {
    display: flex;
    gap: var(--sp-2);
    flex-wrap: wrap;
    justify-content: center;
    margin-top: var(--sp-1);
    color: var(--ink3);
    font-size: var(--fs-xs);
  }
  .meta-tag {
    display: inline-flex;
    align-items: center;
    gap: var(--sp-05);
  }
  .interests-tags {
    display: flex;
    gap: var(--sp-05);
    flex-wrap: wrap;
    justify-content: center;
    margin-top: var(--sp-1);
  }
  .roles-row {
    display: flex;
    gap: var(--sp-05);
    justify-content: center;
    flex-wrap: wrap;
    margin-top: var(--sp-1);
  }
  .profile-actions {
    margin-top: var(--sp-2);
  }

  .admin-card, .nav-card {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    text-align: start;
    width: 100%;
    margin-bottom: var(--sp-2);
  }
  .admin-icon, .nav-card-icon {
    width: var(--touch);
    height: var(--touch);
    display: grid;
    place-items: center;
    border-radius: var(--r-xs);
    flex-shrink: 0;
  }
  .admin-icon {
    background: var(--gold-soft);
    color: var(--gold-dark);
  }
  .nav-card-icon {
    background: var(--brand-soft);
    color: var(--brand-ink);
  }
  .admin-text, .nav-card-text {
    flex: 1;
    min-width: 0;
  }
  .admin-title, .nav-card-title {
    font: var(--fw-bold) var(--fs-base) var(--font-sans);
    color: var(--ink);
  }
  .admin-sub, .nav-card-sub {
    font-size: var(--fs-xs);
    color: var(--ink3);
    margin-top: 2px;
  }

  .info-card {
    margin-bottom: var(--sp-2);
  }
  .push-card {
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
    margin-bottom: var(--sp-2);
  }
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
  .push-toggle {
    margin-top: var(--sp-1);
  }
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
  .info-list li:last-child {
    border-bottom: none;
  }
  .info-list li span {
    color: var(--ink3);
  }
  .info-list li b {
    color: var(--ink);
    font-weight: var(--fw-semi);
  }

  .logout-btn {
    margin-top: var(--sp-2);
    color: var(--bad);
  }
  .block {
    width: 100%;
  }
</style>
