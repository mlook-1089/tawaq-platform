<script lang="ts">
  import PageHead from '../components/PageHead.svelte';
</script>

<PageHead icon="🫖" title="جدول المعازيب" />

<div class="placeholder">
  <div class="hex-wrap"><div class="hex"></div></div>
  <h2>قريباً جداً</h2>
  <p>جدول استضافة طلعات الأربعاء مع:</p>
  <ul>
    <li>✓ ربط المعزّبين بطلعات الأربعاء</li>
    <li>✓ تأكيد ذاتي من المعزّب</li>
    <li>✓ طلب تبديل الاستضافة</li>
    <li>✓ قبول/رفض من لجنة الضيافة</li>
    <li>✓ تذكيرات تلقائية قبل الاستضافة بـ 48 ساعة</li>
  </ul>
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
  p { color: var(--ink2); font-size: 13.5px; line-height: 1.7; margin-bottom: 12px; }
  ul {
    list-style: none;
    text-align: start;
    max-width: 340px;
    margin: 16px auto;
    padding: 16px;
    background: var(--bg);
    border-radius: 14px;
  }
  ul li {
    padding: 7px 0;
    font-size: 13px;
    color: var(--ink2);
    border-bottom: 1px dashed var(--line);
  }
  ul li:last-child { border-bottom: none; }
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
