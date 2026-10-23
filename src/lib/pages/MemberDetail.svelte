<script lang="ts">
  import {
    Briefcase,
    Calendar,
    Check,
    Copy,
    Mail,
    MapPin,
    MessageCircle,
    Phone,
    Shield,
    ShieldCheck,
    User,
    UserCheck,
    UserX,
    X
  } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { isAdmin } from '../stores';
  import Icon from '../components/Icon.svelte';
  import Avatar from '../components/Avatar.svelte';

  let {
    member,
    onclose,
    onupdate
  }: {
    member: any;
    onclose: () => void;
    onupdate: () => void;
  } = $props();

  let copied = $state(false);
  let statusBusy = $state(false);
  let error = $state('');

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

  const cleanPhone = $derived.by(() => {
    if (!member?.phone) return '';
    let p = member.phone.replace(/\D/g, '');
    if (p.startsWith('05')) p = '966' + p.slice(1);
    else if (p.startsWith('5')) p = '966' + p;
    return p;
  });

  async function copyPhone() {
    if (!member?.phone) return;
    try {
      await navigator.clipboard.writeText(member.phone);
      copied = true;
      setTimeout(() => (copied = false), 2000);
    } catch {
      // fallback
    }
  }

  async function toggleStatus() {
    if (statusBusy) return;
    const newStatus = member.status === 'active' ? 'inactive' : 'active';
    const actionLabel = newStatus === 'active' ? 'تنشيط الحساب' : 'إيقاف الحساب';
    if (!confirm(`هل أنت متأكد من ${actionLabel} لـ ${member.full_name}؟`)) return;

    statusBusy = true;
    error = '';
    try {
      const { error: err } = await supabase
        .from('users')
        .update({ status: newStatus })
        .eq('id', member.id);
      if (err) throw err;
      member.status = newStatus;
      onupdate();
    } catch (e: any) {
      error = e.message || 'تعذّر تحديث الحالة';
    } finally {
      statusBusy = false;
    }
  }
</script>

<div class="u-modal" onclick={onclose} onkeydown={(e) => e.key === 'Escape' && onclose()} role="presentation">
  <div class="u-modal-scrim"></div>
  <div class="u-modal-box" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
    <div class="u-sheet-handle"></div>
    <div class="u-modal-header">
      <span>الملف الشخصي</span>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق"><Icon icon={X} /></button>
    </div>

    <div class="u-modal-body">
      {#if error}<div class="u-alert err">{error}</div>{/if}

      <div class="member-head">
        <Avatar
          url={member.avatar_url}
          name={member.full_name}
          size="xl"
          circle={true}
        />
        <h2 class="member-name">{member.full_name}</h2>
        {#if member.username}
          <div class="member-username">@{member.username}</div>
        {/if}

        <div class="roles-wrap">
          {#each member.roles || [] as r}
            <span class="u-role-badge {r === 'super_admin' ? 'admin' : r.startsWith('mod_') ? 'founder' : 'member'}">
              <Icon icon={r === 'super_admin' ? ShieldCheck : r.startsWith('mod_') ? Shield : User} size={13} />
              {roleLabels[r] || r}
            </span>
          {/each}
          {#if !member.roles || member.roles.length === 0}
            <span class="u-role-badge member">{roleLabels.member}</span>
          {/if}
          {#if member.status === 'inactive'}
            <span class="u-pill bad">موقوف</span>
          {/if}
        </div>
      </div>

      {#if member.bio}
        <div class="section-box">
          <div class="section-label">نبذة</div>
          <p class="bio-text">{member.bio}</p>
        </div>
      {/if}

      {#if Array.isArray(member.interests) && member.interests.length > 0}
        <div class="section-box">
          <div class="section-label">الاهتمامات</div>
          <div class="interests-chips">
            {#each member.interests as tag}
              <span class="u-pill brand">#{tag}</span>
            {/each}
          </div>
        </div>
      {/if}

      <div class="section-box">
        <div class="section-label">معلومات التواصل والتفاصيل</div>
        <ul class="detail-list">
          {#if member.phone}
            <li class="detail-item">
              <span class="detail-label"><Icon icon={Phone} size={15} /> الجوال</span>
              <div class="phone-action-row">
                <span class="detail-value ltr">{member.phone}</span>
                <button
                  type="button"
                  class="u-btn u-btn-ghost sm copy-btn"
                  onclick={copyPhone}
                  title="نسخ رقم الجوال"
                >
                  <Icon icon={copied ? Check : Copy} size={13} />
                  <span>{copied ? 'تم النسخ' : 'نسخ'}</span>
                </button>
              </div>
            </li>
          {/if}

          {#if member.email}
            <li class="detail-item">
              <span class="detail-label"><Icon icon={Mail} size={15} /> البريد</span>
              <a href={`mailto:${member.email}`} class="detail-link">{member.email}</a>
            </li>
          {/if}

          {#if member.region}
            <li class="detail-item">
              <span class="detail-label"><Icon icon={MapPin} size={15} /> المنطقة</span>
              <span class="detail-value">{member.region}</span>
            </li>
          {/if}

          {#if member.profession}
            <li class="detail-item">
              <span class="detail-label"><Icon icon={Briefcase} size={15} /> المهنة</span>
              <span class="detail-value">{member.profession}</span>
            </li>
          {/if}

          {#if member.birthday}
            <li class="detail-item">
              <span class="detail-label"><Icon icon={Calendar} size={15} /> تاريخ الميلاد</span>
              <span class="detail-value">{member.birthday}</span>
            </li>
          {/if}

          {#if member.joined_at}
            <li class="detail-item">
              <span class="detail-label"><Icon icon={UserCheck} size={15} /> عضو منذ</span>
              <span class="detail-value">{new Date(member.joined_at).toLocaleDateString('ar-SA')}</span>
            </li>
          {/if}
        </ul>
      </div>

      {#if member.phone}
        <div class="contact-actions-grid">
          {#if cleanPhone}
            <a
              href={`https://wa.me/${cleanPhone}`}
              target="_blank"
              rel="noopener noreferrer"
              class="u-btn u-btn-primary contact-btn"
            >
              <Icon icon={MessageCircle} size={16} />
              <span>محادثة واتساب</span>
            </a>
          {/if}
          <a href={`tel:${member.phone}`} class="u-btn u-btn-ghost contact-btn">
            <Icon icon={Phone} size={16} />
            <span>اتصال هاتفي</span>
          </a>
        </div>
      {/if}

      {#if $isAdmin}
        <div class="admin-panel-box">
          <div class="section-label">إجراءات المسؤول</div>
          <div class="admin-actions-row">
            <button
              class="u-btn sm {member.status === 'active' ? 'u-btn-danger' : 'u-btn-success'}"
              disabled={statusBusy}
              onclick={toggleStatus}
            >
              <Icon icon={member.status === 'active' ? UserX : UserCheck} size={14} />
              <span>{member.status === 'active' ? 'إيقاف الحساب' : 'تنشيط الحساب'}</span>
            </button>
          </div>
        </div>
      {/if}
    </div>

    <div class="u-modal-footer">
      <button type="button" class="u-btn u-btn-ghost" onclick={onclose}>إغلاق</button>
    </div>
  </div>
</div>

<style>
  .member-head {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--sp-1);
    text-align: center;
    padding-bottom: var(--sp-3);
    border-bottom: 1px solid var(--line);
  }
  .member-name {
    margin: var(--sp-1) 0 0;
    font: var(--fw-bold) var(--fs-xl) var(--font-sans);
    color: var(--ink);
  }
  .member-username {
    font-size: var(--fs-xs);
    color: var(--ink3);
  }
  .roles-wrap {
    display: flex;
    gap: var(--sp-05);
    flex-wrap: wrap;
    justify-content: center;
    margin-top: var(--sp-1);
  }
  .section-box {
    margin-top: var(--sp-3);
  }
  .section-label {
    font: var(--fw-bold) var(--fs-xs) var(--font-sans);
    color: var(--ink3);
    text-transform: uppercase;
    letter-spacing: var(--tracking-wide);
    margin-bottom: var(--sp-1);
  }
  .bio-text {
    margin: 0;
    font-size: var(--fs-sm);
    color: var(--ink2);
    line-height: var(--lh-base);
    background: var(--muted-bg);
    padding: var(--sp-2);
    border-radius: var(--r-md);
  }
  .interests-chips {
    display: flex;
    gap: var(--sp-05);
    flex-wrap: wrap;
  }
  .detail-list {
    list-style: none;
    padding: 0;
    margin: 0;
    background: var(--muted-bg);
    border-radius: var(--r-md);
    overflow: hidden;
  }
  .detail-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: var(--sp-1) var(--sp-2);
    border-bottom: 1px solid var(--line);
    font-size: var(--fs-sm);
  }
  .detail-item:last-child {
    border-bottom: none;
  }
  .detail-label {
    display: inline-flex;
    align-items: center;
    gap: var(--sp-05);
    color: var(--ink3);
  }
  .detail-value {
    color: var(--ink);
    font-weight: var(--fw-medium);
  }
  .detail-link {
    color: var(--brand);
    text-decoration: none;
  }
  .detail-link:hover {
    text-decoration: underline;
  }
  .phone-action-row {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
  }
  .copy-btn {
    padding: 0 var(--sp-1);
    height: 26px;
    font-size: var(--fs-tiny);
  }
  .contact-actions-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--sp-1);
    margin-top: var(--sp-3);
  }
  .contact-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: var(--sp-05);
    text-decoration: none;
  }
  .admin-panel-box {
    margin-top: var(--sp-3);
    padding: var(--sp-2);
    border: 1px dashed var(--line2);
    border-radius: var(--r-md);
    background: var(--muted-bg);
  }
  .admin-actions-row {
    display: flex;
    gap: var(--sp-1);
  }
  .ltr {
    direction: ltr;
    display: inline-block;
  }
</style>
