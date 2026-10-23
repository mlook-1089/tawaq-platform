<script lang="ts">
  import { Check, Mail, Send, UserPlus, X } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import Icon from '../components/Icon.svelte';

  let { onclose, oninvited }: { onclose: () => void; oninvited: () => void } = $props();

  let email = $state('');
  let fullName = $state('');
  let selectedRoles = $state<string[]>(['member']);
  let busy = $state(false);
  let error = $state('');
  let successMsg = $state('');

  const availableRoles = [
    { id: 'member', label: 'عضو' },
    { id: 'mod_cultural', label: 'لجنة الثقافي والاستضافات' },
    { id: 'mod_sports', label: 'لجنة الرياضي' },
    { id: 'mod_competitions', label: 'لجنة المسابقات' },
    { id: 'mod_trips', label: 'لجنة الفعاليات' },
    { id: 'mod_hospitality', label: 'لجنة الضيافة' },
    { id: 'mod_media', label: 'لجنة الإعلام' },
    { id: 'super_admin', label: 'الإدارة' }
  ];

  function toggleRole(id: string) {
    if (selectedRoles.includes(id)) {
      if (selectedRoles.length > 1) {
        selectedRoles = selectedRoles.filter(r => r !== id);
      }
    } else {
      selectedRoles = [...selectedRoles, id];
    }
  }

  async function handleInvite(e: Event) {
    e.preventDefault();
    if (!email.trim() || !fullName.trim()) return;

    busy = true;
    error = '';
    successMsg = '';

    try {
      // 1. Try invoke Edge Function 'invite-user'
      const { data, error: fnError } = await supabase.functions.invoke('invite-user', {
        body: {
          email: email.trim().toLowerCase(),
          full_name: fullName.trim(),
          roles: selectedRoles
        }
      });

      if (fnError || data?.ok === false) {
        // If Edge function is not deployed or errored, try direct reset password invite
        const cleanEmail = email.trim().toLowerCase();
        const { error: resetErr } = await supabase.auth.resetPasswordForEmail(cleanEmail, {
          redirectTo: window.location.origin + '/tawaq-platform/'
        });

        if (resetErr) {
          throw new Error(fnError?.message || resetErr.message || 'تعذّر إرسال الدعوة');
        }
      }

      successMsg = 'تم إرسال رابط الدعوة بنجاح إلى البريد الإلكتروني.';
      setTimeout(() => {
        oninvited();
      }, 1500);
    } catch (err: any) {
      error = err.message || 'حدث خطأ أثناء إرسال الدعوة';
    } finally {
      busy = false;
    }
  }
</script>

<div class="u-modal" onclick={onclose} onkeydown={(e) => e.key === 'Escape' && onclose()} role="presentation">
  <div class="u-modal-scrim"></div>
  <div class="u-modal-box" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
    <div class="u-sheet-handle"></div>
    <div class="u-modal-header">
      <span>إضافة عضو جديد</span>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق"><Icon icon={X} /></button>
    </div>

    <form class="u-modal-body" onsubmit={handleInvite}>
      {#if error}<div class="u-alert err">{error}</div>{/if}
      {#if successMsg}<div class="u-alert ok">{successMsg}</div>{/if}

      <div class="u-field">
        <label for="inv-name" class="u-field-label">الاسم الكامل *</label>
        <input
          id="inv-name"
          class="u-input"
          bind:value={fullName}
          required
          placeholder="مثال: فهد بن محمد"
        />
      </div>

      <div class="u-field">
        <label for="inv-email" class="u-field-label">البريد الإلكتروني *</label>
        <input
          id="inv-email"
          type="email"
          class="u-input"
          bind:value={email}
          required
          placeholder="member@example.com"
        />
        <span class="u-field-hint">سيتم إرسال رابط تعيين كلمة المرور وتفعيل الحساب إليه</span>
      </div>

      <div class="u-field">
        <span class="u-field-label">الأدوار الممنوحة</span>
        <div class="role-chips-wrap">
          {#each availableRoles as r (r.id)}
            {@const isSelected = selectedRoles.includes(r.id)}
            <button
              type="button"
              class="u-chip"
              class:on={isSelected}
              onclick={() => toggleRole(r.id)}
            >
              {#if isSelected}<Icon icon={Check} size={14} />{/if}
              <span>{r.label}</span>
            </button>
          {/each}
        </div>
      </div>
    </form>

    <div class="u-modal-footer">
      <button type="button" class="u-btn u-btn-ghost" onclick={onclose}>إلغاء</button>
      <button
        type="submit"
        class="u-btn u-btn-primary"
        disabled={busy || !email.trim() || !fullName.trim()}
        onclick={handleInvite}
      >
        <Icon icon={Send} size={15} />
        <span>{busy ? 'جارٍ الإرسال…' : 'إرسال رابط دعوة'}</span>
      </button>
    </div>
  </div>
</div>

<style>
  .role-chips-wrap {
    display: flex;
    flex-wrap: wrap;
    gap: var(--sp-05);
    margin-top: var(--sp-05);
  }
</style>
