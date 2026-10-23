<script lang="ts">
  import { supabase } from './supabase';
  let { session } = $props<{ session: any }>();

  async function logout() {
    await supabase.auth.signOut();
  }
</script>

<div class="wrap">
  <header>
    <div class="brand">
      <div class="hex"></div>
      <span>مجموعة تواق</span>
    </div>
    <button class="out" onclick={logout}>خروج</button>
  </header>

  <main>
    <div class="hero">
      <div class="big-hex"></div>
      <h1>أهلاً بك في منصة تواق 👋</h1>
      <p class="sub">{session?.user?.email}</p>

      <div class="status">
        <div class="pill">
          <span class="dot"></span>
          قاعدة البيانات: متصل
        </div>
        <div class="pill">
          <span class="dot"></span>
          المصادقة: فعالة
        </div>
      </div>

      <div class="info">
        <h2>🚧 المنصة قيد البناء</h2>
        <p>الأساس الكامل جاهز: 14 جدول، 50+ RLS policy، نظام تصميم كامل.</p>
        <p>الواجهات والميزات تُبنى تدريجياً. تابع التحديثات.</p>

        <ul class="features">
          <li>✅ تسجيل الدخول والمصادقة</li>
          <li>⏳ لوحة الفعاليات</li>
          <li>⏳ جدول المعازيب</li>
          <li>⏳ تحضير QR + Geofence</li>
          <li>⏳ التذكيرات والإشعارات</li>
          <li>⏳ تقارير وإحصائيات</li>
        </ul>
      </div>
    </div>
  </main>
</div>

<style>
  .wrap { min-height: 100vh; display: flex; flex-direction: column; background: var(--bg); }

  header {
    padding: 14px 20px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: var(--card);
    border-bottom: 1px solid var(--line);
    position: sticky;
    top: 0;
    z-index: 10;
  }
  .brand { display: flex; align-items: center; gap: 9px; font-weight: 700; color: var(--brand); }
  .hex {
    width: 14px; height: 14px; background: var(--gold);
    clip-path: polygon(25% 5%, 75% 5%, 100% 50%, 75% 95%, 25% 95%, 0 50%);
  }
  .out {
    background: var(--card); color: var(--brand);
    border: 1px solid var(--line); padding: 7px 14px;
    border-radius: 10px; font-size: 12.5px; font-weight: 600;
  }
  .out:hover { background: var(--bad-soft); color: var(--bad); border-color: var(--bad-soft); }

  main { flex: 1; padding: 24px 18px; max-width: 760px; margin: 0 auto; width: 100%; }

  .hero {
    background: linear-gradient(155deg, var(--brand) 0%, #1A4536 100%);
    color: var(--on-brand);
    border-radius: 20px;
    padding: 32px 24px;
    text-align: center;
    position: relative;
    overflow: hidden;
    margin-bottom: 20px;
  }
  .big-hex {
    position: absolute;
    top: -40px; left: -40px;
    width: 160px; height: 160px;
    background: var(--gold); opacity: .08;
    clip-path: polygon(25% 5%, 75% 5%, 100% 50%, 75% 95%, 25% 95%, 0 50%);
  }
  .hero h1 { font-size: 22px; font-weight: 700; margin-bottom: 8px; position: relative; }
  .sub { color: var(--gold-bright); font-size: 13px; margin-bottom: 20px; }

  .status {
    display: flex; gap: 10px; justify-content: center;
    margin-top: 18px; flex-wrap: wrap;
  }
  .pill {
    display: inline-flex; align-items: center; gap: 7px;
    padding: 6px 13px; background: rgba(255, 255, 255, 0.12);
    border: 1px solid rgba(217, 199, 154, 0.3);
    border-radius: 99px; font-size: 11.5px; font-weight: 600;
  }
  .dot {
    width: 7px; height: 7px; border-radius: 50%;
    background: #4CC38A;
    box-shadow: 0 0 8px #4CC38A;
    animation: pulse 2s ease-in-out infinite;
  }
  @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.4; } }

  .info {
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: 18px;
    padding: 20px;
    text-align: right;
    box-shadow: var(--shadow);
  }
  .info h2 { font-size: 16px; color: var(--brand); margin-bottom: 10px; }
  .info p { font-size: 13.5px; color: var(--ink2); line-height: 1.7; margin-bottom: 8px; }

  .features {
    list-style: none;
    margin-top: 14px;
    padding-top: 14px;
    border-top: 1px solid var(--line);
  }
  .features li {
    padding: 7px 0;
    font-size: 13px;
    color: var(--ink2);
    border-bottom: 1px dashed var(--line);
  }
  .features li:last-child { border-bottom: none; }
</style>
