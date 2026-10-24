import { writable } from 'svelte/store';

export type ThemePreference = 'auto' | 'light' | 'dark';

function getInitialTheme(): ThemePreference {
  if (typeof localStorage !== 'undefined') {
    const s = localStorage.getItem('tawaq-theme');
    if (s === 'light' || s === 'dark') return s;
  }
  return 'auto';
}

export const theme = writable<ThemePreference>(getInitialTheme());

export function setTheme(pref: ThemePreference) {
  theme.set(pref);
  if (typeof window === 'undefined') return;
  if (pref === 'auto') {
    localStorage.removeItem('tawaq-theme');
    const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    document.documentElement.classList.toggle('dark', isDark);
  } else {
    localStorage.setItem('tawaq-theme', pref);
    document.documentElement.classList.toggle('dark', pref === 'dark');
  }
}
