<script lang="ts">
  import { ArrowLeft, LogIn } from 'lucide-svelte';
  import { supabase } from './supabase';
  import HexLogo from './components/HexLogo.svelte';
  import Icon from './components/Icon.svelte';

  let email = $state('');
  let password = $state('');
  let loading = $state(false);
  let error = $state('');
  let info = $state('');
  let mode = $state<'signin' | 'signup'>('signin');

  async function handleSubmit(e: Event) {
    e.preventDefault();
    error = ''; info = ''; loading = true;
    try {
      if (mode === 'signin') {
        const { error: err } = await supabase.auth.signInWithPassword({ email, password });
        if (err) throw err;
      } else {
        const { error: err } = await supabase.auth.signUp({ email, password });
        if (err) throw err;
        info = 'تحقق من بريدك لتأكيد الحساب.';
      }
    } catch (e: any) {
      error = e.message || 'حدث خطأ';
    } finally {
      loading = false;
    }
  }
</script>

<div class="login-wrap">
  <div class="login-card">
    <div class="brand-area">
      <HexLogo size={64} />
      <h1>مجموعة تواق</h1>
      <p>من الحلقة إلى الفريق</p>
    </div>

    <form onsubmit={handleSubmit}>
      {#if error}<div class="u-alert err" role="alert">{error}</div>{/if}
      {#if info}<div class="u-alert ok" role="status">{info}</div>{/if}

      <div class="u-field">
        <label for="email" class="u-field-label">البريد الإلكتروني</label>
        <input id="email" class="u-input" type="email" bind:value={email} required autocomplete="email" />
      </div>

      <div class="u-field">
        <label for="password" class="u-field-label">كلمة المرور</label>
        <input id="password" class="u-input" type="password" bind:value={password} required
          autocomplete={mode === 'signin' ? 'current-password' : 'new-password'} />
      </div>

      <button class="u-btn u-btn-primary block" type="submit" disabled={loading}>
        <Icon icon={mode === 'signin' ? LogIn : ArrowLeft} size={16} />
        {loading ? 'جارٍ…' : (mode === 'signin' ? 'دخول' : 'إنشاء حساب')}
      </button>

      <button type="button" class="switch-mode"
        onclick={() => { mode = mode === 'signin' ? 'signup' : 'signin'; error=''; info=''; }}>
        {mode === 'signin' ? 'ليس لديك حساب؟ أنشئ حساباً' : 'لديك حساب؟ ادخل'}
      </button>
    </form>
  </div>

  <p class="footer">منصة تواق · النسخة 2.0</p>
</div>

<style>
  .login-wrap {
    min-height: 100vh;
    min-height: 100dvh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: var(--sp-4);
    background: linear-gradient(160deg, var(--brand), color-mix(in oklab, var(--brand) 82%, var(--ink)));
    position: relative;
    overflow: hidden;
  }
  .login-wrap::before, .login-wrap::after {
    content: '';
    position: absolute;
    background: var(--gold);
    opacity: 0.07;
    clip-path: var(--hex-clip);
  }
  .login-wrap::before { width: 280px; height: 280px; top: -90px; right: -90px; }
  .login-wrap::after  { width: 200px; height: 200px; bottom: -60px; left: -60px; }

  .login-card {
    background: var(--card);
    border-radius: var(--r-lg);
    padding: var(--sp-5) var(--sp-4);
    box-shadow: var(--shadow-lg);
    max-width: 400px;
    width: 100%;
    position: relative;
    z-index: 1;
  }

  .brand-area { text-align: center; margin-bottom: var(--sp-4); }
  .brand-area :global(.hex-logo) { margin: 0 auto var(--sp-2); }
  .brand-area h1 {
    color: var(--brand);
    font: var(--fw-bold) var(--fs-2xl) var(--font-sans);
    letter-spacing: var(--tracking-tight);
    margin: 0;
  }
  .brand-area p {
    color: var(--ink3);
    font-size: var(--fs-xs);
    margin-top: var(--sp-05);
  }

  .block { width: 100%; margin-top: var(--sp-1); }

  .switch-mode {
    background: none; border: none;
    color: var(--brand-ink);
    display: block; width: 100%; margin-top: var(--sp-2);
    font-size: var(--fs-xs);
    text-align: center;
    cursor: pointer;
  }
  .switch-mode:hover { text-decoration: underline; }

  .footer {
    position: relative; z-index: 1;
    margin-top: var(--sp-3);
    color: var(--gold-bright);
    font-size: var(--fs-tiny);
    opacity: 0.8;
  }
</style>
