<script lang="ts">
  import { untrack } from 'svelte';
  import { Camera, Check, Plus, Save, Trash2, X } from 'lucide-svelte';
  import { supabase } from '../supabase';
  import { profile, session, loadProfile } from '../stores';
  import Icon from './Icon.svelte';
  import Avatar from './Avatar.svelte';

  let { onclose, onsaved }: { onclose: () => void; onsaved: () => void } = $props();

  const user = $derived($session?.user);
  const initial = untrack(() => $profile);

  let avatarUrl = $state(initial?.avatar_url || '');
  let bio = $state(initial?.bio || '');
  let interests = $state<string[]>(Array.isArray(initial?.interests) ? [...initial.interests] : []);
  let newInterest = $state('');
  let birthday = $state(initial?.birthday || '');
  let region = $state(initial?.region || '');
  let profession = $state(initial?.profession || '');

  let fileInput: HTMLInputElement | undefined;
  let uploading = $state(false);
  let saving = $state(false);
  let error = $state('');
  let avatarError = $state('');

  const bioRemaining = $derived(500 - (bio?.length || 0));

  function addInterest() {
    const tag = newInterest.trim().replace(/^#/, '');
    if (!tag) return;
    if (interests.length >= 10) {
      error = 'الحد الأقصى للاهتمامات هو 10 عناصر';
      return;
    }
    if (interests.includes(tag)) {
      newInterest = '';
      return;
    }
    interests = [...interests, tag];
    newInterest = '';
    error = '';
  }

  function removeInterest(tag: string) {
    interests = interests.filter(t => t !== tag);
  }

  async function handleFileSelect(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    avatarError = '';

    if (!file.type.startsWith('image/')) {
      avatarError = 'يرجى اختيار ملف صورة صالح';
      return;
    }

    if (file.size > 1024 * 1024) {
      avatarError = 'الحد الأقصى لحجم الصورة هو 1 ميغابايت';
      return;
    }

    uploading = true;
    try {
      // Crop square on client using HTMLCanvas
      const croppedBlob = await cropImageToSquare(file, 400);
      const userId = user?.id;
      if (!userId) throw new Error('المستخدم غير مسجل');

      const filePath = `${userId}/${Date.now()}.jpg`;

      const { error: uploadError } = await supabase.storage
        .from('avatars')
        .upload(filePath, croppedBlob, {
          upsert: true,
          contentType: 'image/jpeg'
        });

      if (uploadError) throw uploadError;

      const { data } = supabase.storage.from('avatars').getPublicUrl(filePath);
      avatarUrl = data.publicUrl;
    } catch (err: any) {
      avatarError = err.message || 'تعذّر رفع الصورة';
    } finally {
      uploading = false;
    }
  }

  function cropImageToSquare(file: File, size = 400): Promise<Blob> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (e) => {
        const img = new Image();
        img.onload = () => {
          const canvas = document.createElement('canvas');
          canvas.width = size;
          canvas.height = size;
          const ctx = canvas.getContext('2d');
          if (!ctx) {
            reject(new Error('Canvas context unavailable'));
            return;
          }

          const minDim = Math.min(img.width, img.height);
          const sx = (img.width - minDim) / 2;
          const sy = (img.height - minDim) / 2;

          ctx.drawImage(img, sx, sy, minDim, minDim, 0, 0, size, size);
          canvas.toBlob(
            (blob) => {
              if (blob) resolve(blob);
              else reject(new Error('Failed to create blob'));
            },
            'image/jpeg',
            0.9
          );
        };
        img.onerror = () => reject(new Error('Failed to load image'));
        img.src = e.target?.result as string;
      };
      reader.onerror = () => reject(new Error('Failed to read file'));
      reader.readAsDataURL(file);
    });
  }

  function removeAvatar() {
    avatarUrl = '';
  }

  async function handleSave(e: Event) {
    e.preventDefault();
    const userId = user?.id;
    if (!userId) return;

    saving = true;
    error = '';

    try {
      const updates = {
        avatar_url: avatarUrl || null,
        bio: bio.trim() || null,
        interests: interests.length > 0 ? interests : null,
        birthday: birthday || null,
        region: region.trim() || null,
        profession: profession.trim() || null
      };

      const { error: updateError } = await supabase
        .from('users')
        .update(updates)
        .eq('id', userId);

      if (updateError) throw updateError;

      await loadProfile(userId);
      onsaved();
    } catch (err: any) {
      error = err.message || 'حدث خطأ أثناء حفظ الملف الشخصي';
    } finally {
      saving = false;
    }
  }
</script>

<div class="u-modal" onclick={onclose} onkeydown={(e) => e.key === 'Escape' && onclose()} role="presentation">
  <div class="u-modal-scrim"></div>
  <div class="u-modal-box wide" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
    <div class="u-sheet-handle"></div>
    <div class="u-modal-header">
      <span>تعديل الملف الشخصي</span>
      <button class="u-modal-close" onclick={onclose} aria-label="إغلاق"><Icon icon={X} /></button>
    </div>

    <form class="u-modal-body" onsubmit={handleSave}>
      {#if error}<div class="u-alert err">{error}</div>{/if}

      <!-- Avatar Picker -->
      <div class="avatar-section">
        <div class="avatar-preview-wrap">
          <Avatar url={avatarUrl} name={initial?.full_name || 'ع'} size="xl" circle={true} />
          {#if uploading}
            <div class="upload-overlay"><span class="u-spinner"></span></div>
          {/if}
        </div>
        <div class="avatar-controls">
          <input
            type="file"
            accept="image/*"
            bind:this={fileInput}
            onchange={handleFileSelect}
            class="u-sr-only"
            id="avatar-file-input"
          />
          <button
            type="button"
            class="u-btn u-btn-ghost sm"
            disabled={uploading}
            onclick={() => fileInput?.click()}
          >
            <Icon icon={Camera} size={15} />
            <span>{avatarUrl ? 'تغيير الصورة' : 'رفع صورة'}</span>
          </button>
          {#if avatarUrl}
            <button
              type="button"
              class="u-btn u-btn-ghost sm danger-btn"
              disabled={uploading}
              onclick={removeAvatar}
              aria-label="حذف الصورة"
            >
              <Icon icon={Trash2} size={15} />
            </button>
          {/if}
          <span class="u-muted">مربع، بحد أقصى 1 ميغابايت</span>
        </div>
        {#if avatarError}<div class="u-alert err avatar-alert">{avatarError}</div>{/if}
      </div>

      <div class="u-field">
        <label for="pe-name" class="u-field-label">الاسم الكامل</label>
        <input
          id="pe-name"
          class="u-input"
          value={initial?.full_name || ''}
          readonly
          disabled
        />
        <span class="u-field-hint">لتغيير الاسم، يرجى التواصل مع الإدارة</span>
      </div>

      <div class="u-field">
        <div class="bio-label-row">
          <label for="pe-bio" class="u-field-label">النبذة التعريفية</label>
          <span class="bio-counter" class:warn={bioRemaining < 50}>{bioRemaining} حرف</span>
        </div>
        <textarea
          id="pe-bio"
          class="u-input u-textarea"
          bind:value={bio}
          maxlength="500"
          rows="3"
          placeholder="اكتب نبذة قصيرة عنك…"
        ></textarea>
      </div>

      <!-- Interests tags -->
      <div class="u-field">
        <label for="pe-interest" class="u-field-label">الاهتمامات ({interests.length}/10)</label>
        <div class="interests-input-row">
          <input
            id="pe-interest"
            class="u-input"
            bind:value={newInterest}
            placeholder="أضف اهتمامًا (مثل: قراءة، هايكنج، تقنية)…"
            maxlength="30"
            onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addInterest(); } }}
          />
          <button
            type="button"
            class="u-btn u-btn-ghost sm"
            onclick={addInterest}
            disabled={!newInterest.trim() || interests.length >= 10}
          >
            <Icon icon={Plus} size={15} />
            إضافة
          </button>
        </div>
        {#if interests.length > 0}
          <div class="interests-chips">
            {#each interests as tag (tag)}
              <span class="interest-chip">
                <span>{tag}</span>
                <button
                  type="button"
                  class="chip-remove"
                  onclick={() => removeInterest(tag)}
                  aria-label={`إزالة ${tag}`}
                >
                  <Icon icon={X} size={13} />
                </button>
              </span>
            {/each}
          </div>
        {/if}
      </div>

      <div class="form-grid">
        <div class="u-field">
          <label for="pe-region" class="u-field-label">المنطقة / المدينة</label>
          <input
            id="pe-region"
            class="u-input"
            bind:value={region}
            placeholder="مثال: الرياض"
            maxlength="50"
          />
        </div>

        <div class="u-field">
          <label for="pe-profession" class="u-field-label">المهنة / التخصص</label>
          <input
            id="pe-profession"
            class="u-input"
            bind:value={profession}
            placeholder="مثال: مهندس برمجيات"
            maxlength="60"
          />
        </div>
      </div>

      <div class="u-field">
        <label for="pe-bday" class="u-field-label">تاريخ الميلاد</label>
        <input
          id="pe-bday"
          type="date"
          class="u-input"
          bind:value={birthday}
        />
      </div>
    </form>

    <div class="u-modal-footer">
      <button type="button" class="u-btn u-btn-ghost" onclick={onclose}>إلغاء</button>
      <button type="submit" class="u-btn u-btn-primary" disabled={saving || uploading} onclick={handleSave}>
        <Icon icon={Save} size={15} />
        {saving ? 'جارٍ الحفظ…' : 'حفظ التغييرات'}
      </button>
    </div>
  </div>
</div>

<style>
  .avatar-section {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--sp-2);
    margin-bottom: var(--sp-3);
    padding: var(--sp-2) 0;
    border-bottom: 1px solid var(--line);
  }
  .avatar-preview-wrap {
    position: relative;
    width: 80px;
    height: 80px;
    border-radius: var(--r-pill);
    overflow: hidden;
  }
  .upload-overlay {
    position: absolute;
    inset: 0;
    background: var(--overlay);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .avatar-controls {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    flex-wrap: wrap;
    justify-content: center;
  }
  .avatar-alert {
    width: 100%;
    margin-top: var(--sp-1);
  }
  .bio-label-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .bio-counter {
    font-size: var(--fs-tiny);
    color: var(--ink3);
    font-family: var(--font-num);
  }
  .bio-counter.warn {
    color: var(--warn);
  }
  .interests-input-row {
    display: flex;
    gap: var(--sp-1);
    align-items: center;
  }
  .interests-chips {
    display: flex;
    flex-wrap: wrap;
    gap: var(--sp-05);
    margin-top: var(--sp-1);
  }
  .interest-chip {
    display: inline-flex;
    align-items: center;
    gap: var(--sp-05);
    padding: 4px 10px;
    background: var(--brand-soft);
    color: var(--brand-ink);
    border-radius: var(--r-pill);
    font: var(--fw-semi) var(--fs-xs) var(--font-sans);
  }
  .chip-remove {
    background: transparent;
    border: none;
    color: var(--brand-ink);
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0;
    opacity: 0.7;
    transition: opacity var(--t-fast);
  }
  .chip-remove:hover {
    opacity: 1;
  }
  .form-grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--sp-1);
  }
  @media (min-width: 480px) {
    .form-grid {
      grid-template-columns: 1fr 1fr;
    }
  }
  .danger-btn:hover {
    background: var(--bad-soft);
    color: var(--bad);
    border-color: var(--bad-soft);
  }
</style>
