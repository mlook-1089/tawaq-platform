import { mount } from 'svelte';
import './tokens.css';
import './ui.css';
import './app.css';
import App from './App.svelte';

// Scroll-shadow for TopBar — adds .scrolled to <html> when page > 0
if (typeof document !== 'undefined') {
  const onScroll = () => {
    document.documentElement.classList.toggle('scrolled', window.scrollY > 2);
  };
  window.addEventListener('scroll', onScroll, { passive: true });
}

const app = mount(App, {
  target: document.getElementById('app')!
});

export default app;
