<script lang="ts">
  import { Check, KeyRound, LoaderCircle, X } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import Icon from './Icon.svelte';

  let {
    onclose
  }: {
    onclose: () => void;
  } = $props();

  let password = $state('');
  let confirmPassword = $state('');
  let loading = $state(false);
  let error = $state('');
  let success = $state('');

  async function handleSubmit(e: Event) {
    e.preventDefault();
    error = '';
    success = '';

    if (!password || password.length < 6) {
      error = 'كلمة المرور يجب أن لا تقل عن 6 خانات';
      return;
    }

    if (password !== confirmPassword) {
      error = 'كلمتا المرور غير متطابقتين';
      return;
    }

    loading = true;
    try {
      const { error: err } = await supabase.auth.updateUser({
        password
      });

      if (err) throw err;

      success = 'تم تحديث كلمة المرور بنجاح.';
      setTimeout(() => {
        onclose();
      }, 1500);
    } catch (e: any) {
      error = e.message || 'تعذّر تحديث كلمة المرور';
    } finally {
      loading = false;
    }
  }
</script>

<div
  class="u-modal"
  onclick={onclose}
  onkeydown={(e) => e.key === 'Escape' && onclose()}
  role="presentation"
>
  <div class="u-modal-scrim"></div>
  <div
    class="u-modal-box reset-modal-box"
    onclick={(e) => e.stopPropagation()}
    onkeydown={(e) => e.stopPropagation()}
    role="dialog"
    aria-modal="true"
    tabindex="-1"
  >
    <div class="u-sheet-handle"></div>
    <div class="u-modal-header">
      <div class="modal-title">
        <Icon icon={KeyRound} size={18} />
        <span>تعيين كلمة مرور جديدة</span>
      </div>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق">
        <Icon icon={X} />
      </button>
    </div>

    <form onsubmit={handleSubmit}>
      <div class="u-modal-body u-stack">
        {#if error}
          <div class="u-alert err" role="alert">{error}</div>
        {/if}
        {#if success}
          <div class="u-alert ok" role="status">
            <Icon icon={Check} size={16} />
            <span>{success}</span>
          </div>
        {/if}

        <p class="u-muted reset-desc">
          أدخل كلمة المرور الجديدة لحسابك لتتمكن من تسجيل الدخول مستقبلاً.
        </p>

        <div class="u-field">
          <label for="new-pw" class="u-field-label">كلمة المرور الجديدة</label>
          <input
            id="new-pw"
            class="u-input"
            type="password"
            bind:value={password}
            placeholder="6 خانات على الأقل"
            required
            minlength="6"
            autocomplete="new-password"
          />
        </div>

        <div class="u-field">
          <label for="confirm-pw" class="u-field-label">تأكيد كلمة المرور</label>
          <input
            id="confirm-pw"
            class="u-input"
            type="password"
            bind:value={confirmPassword}
            placeholder="أعد إدخال كلمة المرور"
            required
            minlength="6"
            autocomplete="new-password"
          />
        </div>
      </div>

      <div class="u-modal-footer">
        <button type="button" class="u-btn u-btn-ghost" onclick={onclose} disabled={loading}>
          إلغاء
        </button>
        <button type="submit" class="u-btn u-btn-primary" disabled={loading || !!success}>
          {#if loading}
            <Icon icon={LoaderCircle} size={16} class="u-spin-icon" />
            <span>جارٍ الحفظ…</span>
          {:else}
            <Icon icon={Check} size={16} />
            <span>حفظ كلمة المرور</span>
          {/if}
        </button>
      </div>
    </form>
  </div>
</div>

<style>
  .reset-modal-box {
    max-width: 440px;
    margin-inline: auto;
  }
  .modal-title {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    font-weight: var(--fw-bold);
  }
  .reset-desc {
    margin: 0;
    font-size: var(--fs-sm);
    line-height: var(--lh-relaxed);
  }
</style>
