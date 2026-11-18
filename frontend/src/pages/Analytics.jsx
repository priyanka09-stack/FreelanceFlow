import { inr } from '../api.js';
import { Load, Table, useApi } from '../ui.jsx';

const Bars = ({ rows, label, value, fmt = inr }) => {
  const max = Math.max(...rows.map(r => Number(value(r))), 1);
  return <div className="bars">{rows.map((r, i) => (
    <div className="bar-row" key={i}><span>{label(r)}</span><div className="bar"><i style={{ width: (Number(value(r)) / max) * 100 + '%' }} /></div><b style={{ textAlign: 'right' }}>{fmt(value(r))}</b></div>))}</div>;
};

export default function Analytics({ user }) {
  const res = useApi('/api/analytics');
  return (
    <>
      <div className="head"><h2>Analytics</h2></div>
      <Load res={res}>{d => (<>
        <div className="panel"><h3>Money paid per month</h3>
          {d.monthly.length ? <Bars rows={d.monthly} label={r => String(r.month).slice(0, 7)} value={r => r.total} /> : <div className="empty">No payments yet.</div>}
          {d.monthly.length > 0 && <Table rows={d.monthly} empty="" cols={[{ h: 'Month', f: r => String(r.month).slice(0, 7) }, { h: 'Paid', num: 1, f: r => inr(r.total) }, { h: 'Running total', num: 1, f: r => inr(r.running_total) }]} />}
          <p className="sqlnote">SQL: CTE + <code>SUM(SUM(amount)) OVER (ORDER BY month)</code> for the running total.</p></div>
        <div className="panel"><h3>Projects by status</h3>
          <Bars rows={d.status_mix} label={r => r.status.replace('_', ' ')} value={r => r.n} fmt={v => v} />
          <p className="sqlnote">SQL: <code>COUNT(*) / SUM(COUNT(*)) OVER ()</code> gives each status's percentage.</p></div>
        {user.role === 'admin' && <>
          <div className="panel"><h3>Freelancer leaderboard</h3><Table rows={d.ranking} empty="No data." cols={[
            { h: 'Rank', num: 1, f: r => r.rnk }, { h: 'Freelancer', f: r => r.name }, { h: 'Completed', num: 1, f: r => r.completed }, { h: 'Net earned', num: 1, f: r => inr(r.net_earned) }]} />
            <p className="sqlnote">SQL: <code>RANK() OVER (ORDER BY net_earned DESC)</code>, ties share a rank.</p></div>
          <div className="panel"><h3>Client share of platform spending</h3><Bars rows={d.client_share} label={r => r.name} value={r => r.pct || 0} fmt={v => v + '%'} /></div></>}
      </>)}</Load>
    </>
  );
}
