import { writable } from 'svelte/store';

export type ToastKind = 'info' | 'ok' | 'warn' | 'err';
export interface ToastItem {
  id: number;
  text: string;
  kind: ToastKind;
}

export const toasts = writable<ToastItem[]>([]);

let seq = 1;

export function showToast(text: string, kind: ToastKind = 'info', timeout = 3200) {
  const id = seq++;
  toasts.update((list) => [...list, { id, text, kind }]);
  if (timeout > 0) {
    setTimeout(() => {
      toasts.update((list) => list.filter((t) => t.id !== id));
    }, timeout);
  }
  return id;
}

export const toastOk   = (t: string) => showToast(t, 'ok');
export const toastWarn = (t: string) => showToast(t, 'warn');
export const toastErr  = (t: string) => showToast(t, 'err');

export interface ConfirmOptions {
  title: string;
  message?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
}

export const confirmState = writable<null | (ConfirmOptions & { resolve: (ok: boolean) => void })>(null);

export function confirmDialog(opts: ConfirmOptions): Promise<boolean> {
  return new Promise((resolve) => {
    confirmState.set({ ...opts, resolve });
  });
}
