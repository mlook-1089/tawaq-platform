import { mount } from 'svelte';
import './tokens.css';
import './ui.css';
import './app.css';
import App from './App.svelte';

// Theme management (auto system theme + saved preference)
if (typeof document !== 'undefined') {
  const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
  const syncTheme = () => {
    const saved = localStorage.getItem('tawaq-theme');
    const isDark = saved === 'dark' || (!saved && mediaQuery.matches);
    document.documentElement.classList.toggle('dark', isDark);
  };
  syncTheme();
  mediaQuery.addEventListener('change', () => {
    if (!localStorage.getItem('tawaq-theme')) syncTheme();
  });

  // Scroll-shadow for TopBar — adds .scrolled to <html> when page > 0
  const onScroll = () => {
    document.documentElement.classList.toggle('scrolled', window.scrollY > 2);
  };
  window.addEventListener('scroll', onScroll, { passive: true });
}

const app = mount(App, {
  target: document.getElementById('app')!
});

export default app;
