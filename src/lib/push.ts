import { supabase } from './supabase';

export type PushStatus = 'unsupported' | 'denied' | 'subscribed' | 'not-subscribed';

const serviceWorkerUrl = `${import.meta.env.BASE_URL}sw.js`;
const serviceWorkerScope = '/tawaq-platform/';

function supported() {
  return typeof window !== 'undefined'
    && 'serviceWorker' in navigator
    && 'PushManager' in window
    && 'Notification' in window;
}

function urlBase64ToUint8Array(value: string) {
  const padding = '='.repeat((4 - value.length % 4) % 4);
  const base64 = (value + padding).replaceAll('-', '+').replaceAll('_', '/');
  const raw = window.atob(base64);
  return Uint8Array.from(raw, (character) => character.charCodeAt(0));
}

async function registration() {
  return navigator.serviceWorker.register(serviceWorkerUrl, { scope: serviceWorkerScope });
}

export async function getPushStatus(): Promise<PushStatus> {
  if (!supported()) return 'unsupported';
  if (Notification.permission === 'denied') return 'denied';

  const worker = await registration();
  const subscription = await worker.pushManager.getSubscription();
  return subscription ? 'subscribed' : 'not-subscribed';
}

export async function subscribeToPush(userId: string): Promise<PushStatus> {
  if (!supported()) return 'unsupported';
  const permission = await Notification.requestPermission();
  if (permission !== 'granted') return permission === 'denied' ? 'denied' : 'not-subscribed';

  const publicKey = import.meta.env.VITE_VAPID_PUBLIC_KEY as string | undefined;
  if (!publicKey) throw new Error('مفتاح الإشعارات العام غير مضبوط.');

  const worker = await registration();
  const subscription = await worker.pushManager.getSubscription() || await worker.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(publicKey)
  });
  const json = subscription.toJSON();
  if (!json.endpoint || !json.keys?.p256dh || !json.keys?.auth) {
    throw new Error('تعذّر قراءة بيانات اشتراك المتصفح.');
  }

  const { error } = await supabase.from('push_subscriptions').upsert({
    user_id: userId,
    endpoint: json.endpoint,
    p256dh_key: json.keys.p256dh,
    auth_key: json.keys.auth,
    user_agent: navigator.userAgent,
    last_used_at: new Date().toISOString()
  }, { onConflict: 'endpoint' });
  if (error) {
    await subscription.unsubscribe();
    throw error;
  }

  await supabase.from('users').update({ notifications_enabled: true }).eq('id', userId);
  return 'subscribed';
}

export async function unsubscribeFromPush(userId: string): Promise<PushStatus> {
  if (!supported()) return 'unsupported';
  const worker = await registration();
  const subscription = await worker.pushManager.getSubscription();
  if (!subscription) return 'not-subscribed';

  const { error } = await supabase
    .from('push_subscriptions')
    .delete()
    .eq('user_id', userId)
    .eq('endpoint', subscription.endpoint);
  if (error) throw error;
  await subscription.unsubscribe();
  return 'not-subscribed';
}
