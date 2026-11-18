import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { api, day, inr, stamp } from '../api.js';
import { Btn, ContractCard, FormModal, Load, Tag, useAction, useApi, useToast } from '../ui.jsx';

export function Contracts() {
  const res = useApi('/api/contracts');
  return (<><div className="head"><h2>Contracts</h2></div>
    <Load res={res}>{rows => rows.length ? rows.map(c => <ContractCard key={c.contract_id} c={c} />) : <div className="panel empty">No contracts yet.</div>}</Load></>);
}

export function ContractDetail({ user }) {
  const { id } = useParams();
  const cs = useApi('/api/contracts'), ms = useApi(`/api/contracts/${id}/milestones`), hist = useApi(`/api/contracts/${id}/history`);
  const reload = () => { cs.reload(); ms.reload(); hist.reload(); };
  const act = useAction(reload), toast = useToast();
  const [modal, setModal] = useState(null);
  const c = cs.data?.find(x => x.contract_id === Number(id));
  const left = c ? Number(c.agreed_amount) - Number(c.planned) : 0;
  const button = m => {
    if (user.role === 'freelancer' && m.status === 'pending') return <Btn primary onClick={() => act(() => api(`/api/milestones/${m.milestone_id}/submit`, 'POST'), 'Submitted for review')}>Submit work</Btn>;
    if (user.role === 'client' && m.status === 'submitted') return <Btn primary onClick={() => act(() => api(`/api/milestones/${m.milestone_id}/approve`, 'POST'), 'Approved. Invoice created')}>Approve and invoice</Btn>;
    if (user.role === 'client' && m.status === 'approved') return <Btn primary onClick={() => setModal({ t: 'pay', inv: m.invoice_id })}>Pay {inr(m.amount)}</Btn>;
  };
  return (
    <>
      <Link className="btn back" to="/contracts">Back to contracts</Link>
      {c && <ContractCard c={c} link={false} />}
      <div className="head"><h2>Milestones</h2><div className="row-actions">
        {user.role === 'client' && left > 0 && <Btn primary onClick={() => setModal({ t: 'add' })}>Add milestone ({inr(left)} left)</Btn>}
        {user.role !== 'admin' && <Btn onClick={() => setModal({ t: 'dispute' })}>Raise dispute</Btn>}</div></div>
      <div className="panel pipeline"><Load res={ms}>{rows => rows.length ? rows.map(m => (
        <div className="stage" key={m.milestone_id}>
          <div><div className="t">{m.title}</div><div className="muted">Due {day(m.due_date)} · {inr(m.amount)}{m.invoice_no ? ' · ' + m.invoice_no : ''}</div></div>
          <div className="row-actions"><Tag s={m.status} />{button(m)}</div></div>
      )) : <div className="empty">No milestones yet. Split the contract into deliverables with deadlines and amounts.</div>}</Load></div>
      <div className="head"><h2>History</h2><span className="muted">Written automatically by a database trigger</span></div>
      <div className="panel"><Load res={hist}>{rows => rows.length ? <ul className="timeline">{rows.map((h, i) => (
        <li key={i}><span><b>{h.milestone || 'Contract'}</b>: {h.old_status} to {h.new_status}</span><span className="muted">{stamp(h.changed_at)}</span></li>))}</ul> : <div className="empty">No status changes yet.</div>}</Load></div>

      {modal?.t === 'add' && <FormModal title="Add milestone" onClose={() => setModal(null)}
        fields={[{ name: 'title', label: 'Deliverable' }, { name: 'amount', label: 'Amount (₹)', type: 'number' }, { name: 'due_date', label: 'Due date', type: 'date', req: false }]}
        onSubmit={d => api('/api/milestones', 'POST', { ...d, contract_id: Number(id) }).then(() => { toast('Milestone added'); reload(); })} />}
      {modal?.t === 'pay' && <FormModal title="Pay invoice" onClose={() => setModal(null)} fields={[{ name: 'method', label: 'Payment method', options: ['UPI', 'Card', 'Bank Transfer'] }]}
        onSubmit={d => api(`/api/invoices/${modal.inv}/pay`, 'POST', d).then(() => { toast('Payment recorded'); reload(); })} />}
      {modal?.t === 'dispute' && <FormModal title="Raise dispute" onClose={() => setModal(null)} fields={[{ name: 'reason', label: 'What went wrong?', type: 'textarea' }]}
        onSubmit={d => api('/api/disputes', 'POST', { ...d, contract_id: Number(id) }).then(() => toast('Dispute raised'))} />}
    </>
  );
}
