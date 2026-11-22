window.WATER_BACKEND_CONFIG = {
  // This public anon/publishable key is safe to expose only with the supplied RLS policies.
  supabaseUrl: 'https://goplraasrkjnkrspvgsh.supabase.co',
  supabaseAnonKey: 'sb_publishable_lMjHu2X6Qcd5yDc3z2SCuQ_oOJ2ObGn'
};

function isPublicSupabaseKey(key) {
  if (typeof key !== 'string') return false;
  if (/^sb_publishable_[A-Za-z0-9_-]+$/.test(key)) return true;
  const parts = key.split('.');
  if (parts.length !== 3) return false;
  try {
    let payload = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    payload += '='.repeat((4 - payload.length % 4) % 4);
    return JSON.parse(atob(payload)).role === 'anon';
  } catch (error) {
    return false;
  }
}

window.waterBackendConfig = function () {
  const config = window.WATER_BACKEND_CONFIG;
  if (!config || !isPublicSupabaseKey(config.supabaseAnonKey || '')) return null;
  try {
    const url = new URL(config.supabaseUrl);
    if (url.protocol !== 'https:' || !url.hostname.endsWith('.supabase.co')) return null;
    return { url: url.origin, anonKey: config.supabaseAnonKey };
  } catch (error) {
    return null;
  }
};

window.waterBackendFetch = async function (path, options) {
  const config = window.waterBackendConfig();
  if (!config) throw new Error('Backend is not configured');
  if (!path.startsWith('/auth/v1/') && !path.startsWith('/rest/v1/'))
    throw new Error('Unsupported backend path');
  const request = options || {};
  const headers = { apikey: config.anonKey };
  if (request.token) headers.Authorization = `Bearer ${request.token}`;
  else if (!config.anonKey.startsWith('sb_publishable_'))
    headers.Authorization = `Bearer ${config.anonKey}`;
  if (request.body !== undefined) headers['Content-Type'] = 'application/json';
  if (request.prefer) headers.Prefer = request.prefer;
  const response = await fetch(config.url + path, {
    method: request.method || 'GET',
    headers,
    body: request.body === undefined ? undefined : JSON.stringify(request.body)
  });
  if (!response.ok) throw new Error(`Backend request failed (${response.status})`);
  const text = await response.text();
  return text ? JSON.parse(text) : null;
};
