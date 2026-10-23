<script lang="ts">
  import { untrack } from 'svelte';
  import { Check, Save, ShieldCheck, X } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import Icon from '../components/Icon.svelte';

  let {
    user,
    currentRoles,
    onclose,
    onsaved
  }: {
    user: any;
    currentRoles: string[];
    onclose: () => void;
    onsaved: () => void;
  } = $props();

  const allRoles: { id: string; label: string; desc: string }[] = [
    { id: 'super_admin', label: 'الإدارة الكاملة', desc: 'صلاحيات الإدارة والتحكم بكافة أقسام المنصة' },
    { id: 'mod_cultural', label: 'لجنة الثقافي والاستضافات', desc: 'إدارة الفعاليات الثقافية' },
    { id: 'mod_sports', label: 'لجنة الرياضي', desc: 'إدارة الفعاليات والأنشطة الرياضية' },
    { id: 'mod_competitions', label: 'لجنة المسابقات', desc: 'إدارة التحديات والمسابقات' },
    { id: 'mod_trips', label: 'لجنة الفعاليات والرحلات', desc: 'إدارة الرحلات والطلعات المصاحبة' },
    { id: 'mod_hospitality', label: 'لجنة الضيافة والمالية', desc: 'إدارة المعازيب والقطات والمصاريف' },
    { id: 'mod_media', label: 'لجنة التصميم والإعلام', desc: 'إدارة الأخبار ونشر المحتوى' },
    { id: 'member', label: 'عضو', desc: 'المشاركة وحضور الفعاليات' }
  ];

  let selected = $state<string[]>(untrack(() => [...currentRoles]));
  let saving = $state(false);
  let error = $state('');

  function toggleRole(roleId: string) {
    if (selected.includes(roleId)) {
      if (selected.length === 1) {
        error = 'يجب تعيين دور واحد على الأقل للعضو';
        return;
      }
      selected = selected.filter(r => r !== roleId);
    } else {
      selected = [...selected, roleId];
    }
    error = '';
  }

  async function saveRoles() {
    saving = true;
    error = '';
    try {
      // Delete old roles
      const { error: delErr } = await supabase
        .from('user_roles')
        .delete()
        .eq('user_id', user.id);

      if (delErr) throw delErr;

      // Insert new roles
      const inserts = selected.map(role => ({
        user_id: user.id,
        role
      }));

      const { error: insErr } = await supabase
        .from('user_roles')
        .insert(inserts);

      if (insErr) throw insErr;

      onsaved();
    } catch (e: any) {
      error = e.message || 'تعذّر حفظ الأدوار';
    } finally {
      saving = false;
    }
  }
</script>

<div class="u-modal" onclick={onclose} onkeydown={(e) => e.key === 'Escape' && onclose()} role="presentation">
  <div class="u-modal-scrim"></div>
  <div class="u-modal-box" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
    <div class="u-sheet-handle"></div>
    <div class="u-modal-header">
      <span>تعديل أدوار: {user.full_name}</span>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق"><Icon icon={X} /></button>
    </div>

    <div class="u-modal-body">
      {#if error}<div class="u-alert err">{error}</div>{/if}

      <p class="role-intro">اختر الأدوار والصلاحيات التي يمتلكها هذا العضو في المنصة:</p>

      <div class="roles-selection-list">
        {#each allRoles as r (r.id)}
          {@const isChecked = selected.includes(r.id)}
          <button
            type="button"
            class="role-option-card"
            class:selected={isChecked}
            onclick={() => toggleRole(r.id)}
          >
            <div class="role-check-box" class:checked={isChecked}>
              {#if isChecked}<Icon icon={Check} size={14} />{/if}
            </div>
            <div class="role-text-col">
              <div class="role-title">{r.label}</div>
              <div class="role-desc">{r.desc}</div>
            </div>
          </button>
        {/each}
      </div>
    </div>

    <div class="u-modal-footer">
      <button type="button" class="u-btn u-btn-ghost" onclick={onclose}>إلغاء</button>
      <button type="button" class="u-btn u-btn-primary" disabled={saving} onclick={saveRoles}>
        <Icon icon={Save} size={15} />
        {saving ? 'جارٍ الحفظ…' : 'حفظ الأدوار'}
      </button>
    </div>
  </div>
</div>

<style>
  .role-intro {
    font-size: var(--fs-xs);
    color: var(--ink3);
    margin: 0 0 var(--sp-2);
  }
  .roles-selection-list {
    display: flex;
    flex-direction: column;
    gap: var(--sp-1);
  }
  .role-option-card {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    padding: var(--sp-2);
    border: 1px solid var(--line);
    border-radius: var(--r-md);
    background: var(--card);
    cursor: pointer;
    text-align: start;
    width: 100%;
    transition: all var(--t-fast);
  }
  .role-option-card:hover {
    background: var(--muted-bg);
    border-color: var(--line2);
  }
  .role-option-card.selected {
    border-color: var(--brand);
    background: var(--brand-soft);
  }
  .role-check-box {
    width: 22px;
    height: 22px;
    border-radius: var(--r-xs);
    border: 1.5px solid var(--line2);
    display: grid;
    place-items: center;
    background: var(--card);
    color: var(--brand);
    flex-shrink: 0;
  }
  .role-check-box.checked {
    background: var(--brand);
    border-color: var(--brand);
    color: var(--on-brand);
  }
  .role-text-col {
    flex: 1;
    min-width: 0;
  }
  .role-title {
    font: var(--fw-bold) var(--fs-sm) var(--font-sans);
    color: var(--ink);
  }
  .role-desc {
    font-size: var(--fs-tiny);
    color: var(--ink3);
    margin-top: 2px;
  }
</style>
