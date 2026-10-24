const DAYS = ['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];

export function initials(name: string): string {
  const parts = String(name || '').trim().split(/\s+/);
  const strip = (word: string) => word.replace(/^(ال|عبد|عبدال|أبو|ابن|بن|أم)/u, '').trim() || word;
  const firstPart = strip(parts[0] || '');
  const secondPart = strip(parts[1] || '');
  const first = firstPart.charAt(0) || parts[0]?.charAt(0) || '';
  const second = secondPart.charAt(0) || parts[1]?.charAt(0) || '';
  return (first + second) || first || 'ع';
}

export function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  const p = (n: number) => String(n).padStart(2, '0');
  return `${DAYS[d.getDay()]} ${p(d.getDate())}-${p(d.getMonth() + 1)}-${d.getFullYear()}`;
}

export function fmtTime(iso: string): string {
  const d = new Date(iso);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${p(d.getHours())}:${p(d.getMinutes())}`;
}

export function fmtDT(iso: string): string {
  return iso ? fmtDate(iso) + ' · ' + fmtTime(iso) : '';
}

export function fmtCurrency(amount: number | string | null | undefined): string {
  const n = Number(amount) || 0;
  return `ر.س ${n.toFixed(2)}`;
}

export function timeAgo(iso: string | null | undefined): string {
  if (!iso) return '';
  const diff = Date.now() - new Date(iso).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'الآن';
  if (m < 60) return `منذ ${m} د`;
  const h = Math.floor(m / 60);
  if (h < 24) return `منذ ${h} س`;
  const d = Math.floor(h / 24);
  if (d < 30) return `منذ ${d} ي`;
  return fmtDate(iso);
}

export function fmtInput(iso: string | null | undefined, dateOnly = false): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  const p = (n: number) => String(n).padStart(2, '0');
  const base = `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
  return dateOnly ? base : `${base}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

export function hijriDate(iso: string | null | undefined): string {
  if (!iso) return '';
  try {
    return new Intl.DateTimeFormat('ar-SA-u-ca-islamic', {
      day: 'numeric', month: 'long', year: 'numeric'
    }).format(new Date(iso));
  } catch { return ''; }
}

export const EVENT_TYPES: Record<string, { label: string; color: string; owner: string }> = {
  weekly:       { label: 'طلعة الأربعاء', color: 'var(--brand)', owner: 'super_admin' },
  sport:        { label: 'رياضي',          color: 'var(--gold)', owner: 'mod_sports' },
  cultural:     { label: 'ثقافي',          color: 'var(--brand-3)', owner: 'mod_cultural' },
  competition:  { label: 'مسابقة',         color: 'var(--warn)', owner: 'mod_competitions' },
  event:        { label: 'فعالية مصاحبة',  color: 'var(--brand-2)', owner: 'mod_trips' },
  hospitality:  { label: 'ضيافة',          color: 'var(--gold-dark)', owner: 'mod_hospitality' }
};

export function canCreateType(roles: string[], type: string): boolean {
  if (roles.includes('super_admin')) return true;
  const owner = EVENT_TYPES[type]?.owner;
  return !!owner && roles.includes(owner);
}

export function myAllowedTypes(roles: string[]): string[] {
  if (roles.includes('super_admin')) return Object.keys(EVENT_TYPES);
  return Object.keys(EVENT_TYPES).filter(t => roles.includes(EVENT_TYPES[t].owner));
}

export function esc(str: string | null | undefined): string {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
