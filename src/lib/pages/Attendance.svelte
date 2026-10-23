<script lang="ts">
  import PageHead from '../components/PageHead.svelte';
</script>

<PageHead icon="✓" title="التحضير الذكي" />

<div class="placeholder">
  <div class="hex-wrap"><div class="hex"></div></div>
  <h2>قريباً جداً</h2>
  <p>تحضير حضوري أو QR أو عبر الموقع:</p>
  <div class="features">
    <div class="feature">
      <div class="ic">📱</div>
      <div class="t">QR Code</div>
      <div class="d">المسؤول يُظهر رمز، العضو يمسحه</div>
    </div>
    <div class="feature">
      <div class="ic">📍</div>
      <div class="t">Geofence</div>
      <div class="d">تحضير تلقائي عند الوصول</div>
    </div>
    <div class="feature">
      <div class="ic">✍️</div>
      <div class="t">يدوي</div>
      <div class="d">تحضير من قبل المسؤول</div>
    </div>
  </div>
  <p class="note">البنية التحتية جاهزة في قاعدة البيانات ✅ — الواجهة قيد البناء.</p>
</div>

<style>
  .placeholder {
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: 20px;
    padding: 36px 24px;
    text-align: center;
    box-shadow: var(--shadow);
  }
  .hex-wrap { margin-bottom: 20px; }
  .hex {
    width: 60px; height: 60px;
    background: var(--gold);
    opacity: .3;
    clip-path: polygon(25% 5%, 75% 5%, 100% 50%, 75% 95%, 25% 95%, 0 50%);
    margin: 0 auto;
    animation: float 3s ease-in-out infinite;
  }
  @keyframes float {
    0%,100% { transform: translateY(0); }
    50% { transform: translateY(-8px); }
  }
  h2 { color: var(--brand); font-size: 22px; margin-bottom: 10px; }
  p { color: var(--ink2); font-size: 13.5px; line-height: 1.7; margin-bottom: 16px; }
  .features {
    display: grid;
    grid-template-columns: 1fr;
    gap: 10px;
    max-width: 400px;
    margin: 16px auto;
  }
  @media (min-width: 500px) { .features { grid-template-columns: 1fr 1fr 1fr; } }
  .feature {
    background: var(--bg);
    border: 1px solid var(--line);
    border-radius: 14px;
    padding: 16px 12px;
    text-align: center;
  }
  .feature .ic { font-size: 28px; margin-bottom: 8px; }
  .feature .t { font-weight: 700; color: var(--brand); font-size: 13.5px; }
  .feature .d { font-size: 11px; color: var(--ink3); margin-top: 4px; }
  .note {
    margin-top: 16px;
    padding: 10px 14px;
    background: var(--ok-soft);
    color: var(--ok);
    border-radius: 10px;
    font-size: 12px;
    font-weight: 600;
    display: inline-block;
  }
</style>
