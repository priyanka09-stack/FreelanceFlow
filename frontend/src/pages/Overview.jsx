import { api, inr, stamp } from '../api.js';
import { ContractCard, Load, Table, useAction, useApi, Btn } from '../ui.jsx';

export default function Overview({ user }) {
  const rep = useApi('/api/reports'), notes = useApi('/api/notifications');
  const act = useAction(notes.reload);
  const tiles = r => {
    if (user.role === 'admin') { const v = r.revenue; return [['Paid through the platform', inr(v.total_paid)], ['Commission earned', inr(v.commission_earned)], ['Waiting for payment', inr(v.outstanding)], ['Active contracts', v.active_contracts], ['Open disputes', v.open_disputes]]; }
    if (user.role === 'client') { const s = r.spending[0] || {}; return [['Total paid', inr(s.total_paid)], ['Invoices waiting for you', inr(s.outstanding)], ['Contracts', s.contracts || 0]]; }
    const s = r.earnings[0] || {}; return [['Net earned', inr(s.net_earned)], ['Commission paid', inr(s.commission)], ['Completed contracts', s.completed || 0], ['All contracts', s.contracts || 0]];
  };
  return (
    <>
      <div className="head"><h2>Overview</h2></div>
      <Load res={rep}>{r => (<>
        <div className="stats">{tiles(r).map(([l, n]) => <div className="stat" key={l}><span>{l}</span><b>{n}</b></div>)}</div>
        {user.role === 'admin' && <>
          <div className="panel"><h3>Freelancer earnings</h3><Table rows={r.earnings} empty="No data yet." cols={[
            { h: 'Freelancer', f: x => x.name }, { h: 'Contracts', num: 1, f: x => x.contracts }, { h: 'Gross', num: 1, f: x => inr(x.gross) },
            { h: 'Commission', num: 1, f: x => inr(x.commission) }, { h: 'Net earned', num: 1, f: x => inr(x.net_earned) }]} /></div>
          <div className="panel"><h3>Client spending</h3><Table rows={r.spending} empty="No data yet." cols={[
            { h: 'Client', f: x => x.name }, { h: 'Paid', num: 1, f: x => inr(x.total_paid) }, { h: 'Outstanding', num: 1, f: x => inr(x.outstanding) }]} /></div></>}
        <div className="head"><h2>Alerts</h2>
          {user.role === 'admin' && <Btn primary onClick={() => act(async () => { const r = await api('/api/admin/check-overdue', 'POST'); notes.reload(); if (!r.flagged) throw new Error('No new overdue milestones'); }, 'Overdue check done')}>Run overdue check</Btn>}</div>
        <div className="panel"><Load res={notes}>{n => n.length ? n.map(x => <div className="note" key={x.note_id}>{x.message} <span className="muted">· {stamp(x.created_at)}</span></div>) : <div className="empty">No alerts. Overdue milestones will appear here.</div>}</Load></div>
        <div className="head"><h2>Contract progress</h2></div>
        {r.contracts.length ? r.contracts.map(c => <ContractCard key={c.contract_id} c={c} />) : <div className="panel empty">No contracts yet. Accepted proposals become contracts.</div>}
      </>)}</Load>
    </>
  );
}
