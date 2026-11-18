// Shared building blocks: toast, data hooks, table, tag, form modal, contract card.
import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { api, inr } from './api.js';

const ToastCtx = createContext(() => {});
export const useToast = () => useContext(ToastCtx);
export function ToastProvider({ children }) {
  const [t, setT] = useState(null);
  const show = useCallback((msg, bad) => { setT({ msg, bad }); clearTimeout(show.id); show.id = setTimeout(() => setT(null), 3500); }, []);
  return <ToastCtx.Provider value={show}>{children}{t && <div className={'toast' + (t.bad ? ' bad' : '')} role="status">{t.msg}</div>}</ToastCtx.Provider>;
}

export function useApi(url) {
  const [data, setData] = useState(null), [error, setError] = useState('');
  const load = useCallback(() => api(url).then(d => { setData(d); setError(''); }).catch(e => setError(e.message)), [url]);
  useEffect(() => { setData(null); load(); }, [load]);
  return { data, error, reload: load };
}
export function useAction(reload) {
  const toast = useToast();
  return async (fn, ok) => { try { await fn(); if (ok) toast(ok); if (reload) await reload(); } catch (e) { toast(e.message, true); } };
}
export function Load({ res, children }) {
  if (res.error) return <div className="panel empty">{res.error}</div>;
  if (!res.data) return <div className="panel empty">Loading…</div>;
  return children(res.data);
}

export const Tag = ({ s }) => <span className={'tag ' + s}>{String(s).replace('_', ' ')}</span>;
export const Btn = ({ primary, ...p }) => <button className={'btn sm' + (primary ? ' primary' : '')} {...p} />;

export function Table({ rows, cols, empty }) {
  if (!rows.length) return <div className="empty">{empty}</div>;
  return (
    <table>
      <thead><tr>{cols.map((c, i) => <th key={i} className={c.num ? 'num' : ''}>{c.h}</th>)}</tr></thead>
      <tbody>{rows.map((r, i) => <tr key={i}>{cols.map((c, j) => <td key={j} className={c.num ? 'num' : ''}>{c.f(r)}</td>)}</tr>)}</tbody>
    </table>
  );
}

// fields: [{name,label,type?,options?,req?}]  (type 'number' is sent as a real number)
export function FormModal({ title, fields, initial = {}, onSubmit, onClose }) {
  const [v, setV] = useState(() => Object.fromEntries(fields.map(f => [f.name, initial[f.name] ?? (f.options ? f.options[0] : '')])));
  const [busy, setBusy] = useState(false);
  const toast = useToast();
  const submit = async e => {
    e.preventDefault(); setBusy(true);
    const out = Object.fromEntries(fields.map(f => [f.name, f.type === 'number' && v[f.name] !== '' ? Number(v[f.name]) : v[f.name]]));
    try { await onSubmit(out); onClose(); } catch (er) { toast(er.message, true); setBusy(false); }
  };
  return (
    <div className="modal-backdrop" onMouseDown={e => e.target === e.currentTarget && onClose()}>
      <form className="modal" onSubmit={submit}>
        <h3>{title}</h3>
        {fields.map(f => (
          <label key={f.name}>{f.label}
            {f.options ? <select value={v[f.name]} onChange={e => setV({ ...v, [f.name]: e.target.value })}>{f.options.map(o => <option key={o}>{o}</option>)}</select>
              : f.type === 'textarea' ? <textarea value={v[f.name]} required={f.req !== false} onChange={e => setV({ ...v, [f.name]: e.target.value })} />
              : <input type={f.type || 'text'} value={v[f.name]} required={f.req !== false} onChange={e => setV({ ...v, [f.name]: e.target.value })} />}
          </label>
        ))}
        <div className="row-actions" style={{ justifyContent: 'flex-end' }}>
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button className="btn primary" disabled={busy}>Save</button>
        </div>
      </form>
    </div>
  );
}

export function ContractCard({ c, link = true }) {
  const a = Number(c.agreed_amount) || 1, pct = v => Math.min(100, (Number(v) / a) * 100);
  return (
    <div className="panel contract-card">
      <div className="top">
        <div><h3 style={{ padding: 0 }}>{c.title}</h3><span className="muted">{c.client_name} with {c.freelancer_name}</span></div>
        <div><Tag s={c.status} /> {link && <Link className="btn sm" to={`/contracts/${c.contract_id}`}>Milestones</Link>}</div>
      </div>
      <div className="moneybar">
        <i style={{ width: pct(c.paid) + '%', background: 'var(--paid)' }} /><i style={{ width: pct(c.awaiting_payment) + '%', background: 'var(--await)' }} />
        <i style={{ width: pct(c.in_review) + '%', background: 'var(--review)' }} />
      </div>
      <div className="legend">
        <span style={{ '--c': 'var(--paid)' }}>Paid {inr(c.paid)}</span><span style={{ '--c': 'var(--await)' }}>Awaiting payment {inr(c.awaiting_payment)}</span>
        <span style={{ '--c': 'var(--review)' }}>In review {inr(c.in_review)}</span><span style={{ '--c': 'var(--pending)' }}>Contract total {inr(c.agreed_amount)}</span>
      </div>
    </div>
  );
}
