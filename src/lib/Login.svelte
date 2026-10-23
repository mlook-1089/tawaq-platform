<script lang="ts">
  import { supabase } from './supabase';

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

<div class="wrap">
  <div class="card">
    <div class="brand">
      <div class="hex"></div>
      <h1>مجموعة تواق</h1>
      <p>من الحلقة إلى الفريق</p>
    </div>

    <form onsubmit={handleSubmit}>
      {#if error}<div class="alert err">{error}</div>{/if}
      {#if info}<div class="alert ok">{info}</div>{/if}

      <div class="field">
        <label for="email">البريد الإلكتروني</label>
        <input id="email" type="email" bind:value={email} required autocomplete="email" />
      </div>
      <div class="field">
        <label for="password">كلمة المرور</label>
        <input id="password" type="password" bind:value={password} required autocomplete={mode === 'signin' ? 'current-password' : 'new-password'} />
      </div>

      <button class="btn" type="submit" disabled={loading}>
        {loading ? 'جارٍ…' : (mode === 'signin' ? 'دخول' : 'إنشاء حساب')}
      </button>

      <button type="button" class="link" onclick={() => { mode = mode === 'signin' ? 'signup' : 'signin'; error=''; info=''; }}>
        {mode === 'signin' ? 'ليس لديك حساب؟ أنشئ حساباً' : 'لديك حساب؟ ادخل'}
      </button>
    </form>
  </div>

  <p class="footer">منصة تواق · النسخة 2.0 · قيد البناء 🚧</p>
</div>

<style>
  .wrap {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 24px;
    background: linear-gradient(160deg, var(--brand) 0%, #061612 100%);
    position: relative;
    overflow: hidden;
  }
  .wrap::before, .wrap::after {
    content: '';
    position: absolute;
    background: var(--gold);
    opacity: 0.07;
    clip-path: polygon(25% 5%, 75% 5%, 100% 50%, 75% 95%, 25% 95%, 0 50%);
  }
  .wrap::before { width: 280px; height: 280px; top: -90px; right: -90px; }
  .wrap::after { width: 200px; height: 200px; bottom: -60px; left: -60px; }

  .card {
    background: var(--card);
    border-radius: 24px;
    padding: 36px 28px;
    box-shadow: 0 24px 60px rgba(0, 0, 0, 0.35);
    max-width: 400px;
    width: 100%;
    position: relative;
    z-index: 1;
  }

  .brand { text-align: center; margin-bottom: 26px; }
  .hex {
    width: 48px; height: 48px;
    background: var(--gold);
    clip-path: polygon(25% 5%, 75% 5%, 100% 50%, 75% 95%, 25% 95%, 0 50%);
    margin: 0 auto 14px;
  }
  .brand h1 { color: var(--brand); font-size: 22px; font-weight: 700; letter-spacing: .2px; }
  .brand p { color: var(--ink3); font-size: 12px; margin-top: 6px; }

  .alert { padding: 10px 12px; border-radius: 10px; font-size: 12.5px; margin-bottom: 12px; font-weight: 500; }
  .alert.err { background: var(--bad-soft); color: var(--bad); }
  .alert.ok { background: var(--ok-soft); color: var(--ok); }

  .field { margin-bottom: 14px; }
  .field label {
    display: block; font-size: 12px; font-weight: 600; margin-bottom: 6px;
    color: var(--brand);
  }
  .field input {
    width: 100%; padding: 12px 14px; border: 1.5px solid var(--line);
    border-radius: 12px; font-size: 15px; background: var(--card); color: var(--ink);
    transition: border .15s, box-shadow .15s;
  }
  .field input:focus {
    outline: none; border-color: var(--brand);
    box-shadow: 0 0 0 3px var(--brand-soft);
  }

  .btn {
    display: block; width: 100%; padding: 13px;
    background: var(--brand); color: var(--on-brand); border: none;
    border-radius: 12px; font-size: 14px; font-weight: 700;
    transition: filter .15s;
  }
  .btn:hover:not(:disabled) { filter: brightness(1.1); }
  .btn:disabled { opacity: .6; cursor: not-allowed; }

  .link {
    background: none; border: none; color: var(--brand);
    display: block; width: 100%; margin-top: 14px;
    font-size: 12.5px; text-align: center;
  }

  .footer {
    position: relative; z-index: 1;
    margin-top: 20px;
    color: var(--gold-bright);
    font-size: 11px;
    opacity: .8;
  }
</style>
