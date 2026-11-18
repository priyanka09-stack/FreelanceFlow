// One place for every HTTP call + small formatters. Add new endpoints here as the app grows.
export async function api(url, method = 'GET', body) {
  const r = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  const d = await r.json().catch(() => ({}));
  if (!r.ok) { const e = new Error(d.error || 'Something went wrong'); e.status = r.status; throw e; }
  return d;
}
export const inr = n => '₹' + Number(n || 0).toLocaleString('en-IN');
export const day = d => (d ? String(d).slice(0, 10) : '-');
export const stamp = d => String(d).slice(0, 16).replace('T', ' ');
