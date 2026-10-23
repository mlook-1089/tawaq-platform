const DAYS = ['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];

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
