import { useState } from 'react';
import { api, inr } from '../api.js';
import { Btn, FormModal, Load, Table, Tag, useApi, useToast } from '../ui.jsx';

export default function Invoices({ user }) {
  const res = useApi('/api/invoices'), toast = useToast();
  const [pay, setPay] = useState(null);
  return (
    <>
      <div className="head"><h2>Invoices</h2></div>
      <div className="panel"><Load res={res}>{rows => <Table rows={rows} empty="No invoices yet. An invoice is created when a client approves a milestone." cols={[
        { h: 'Invoice', f: x => <b>{x.invoice_no}</b> }, { h: 'Project', f: x => x.project }, { h: 'Milestone', f: x => x.milestone },
        { h: 'Amount', num: 1, f: x => inr(x.amount) }, { h: 'Commission', num: 1, f: x => inr(x.commission) }, { h: 'Freelancer gets', num: 1, f: x => inr(x.net_amount) },
        { h: 'Status', f: x => <><Tag s={x.status} />{x.method && <div className="muted">{x.method}</div>}</> },
        { h: '', f: x => user.role === 'client' && x.status === 'unpaid' && <Btn primary onClick={() => setPay(x.invoice_id)}>Pay now</Btn> },
      ]} />}</Load></div>
      {pay && <FormModal title="Pay invoice" onClose={() => setPay(null)} fields={[{ name: 'method', label: 'Payment method', options: ['UPI', 'Card', 'Bank Transfer'] }]}
        onSubmit={d => api(`/api/invoices/${pay}/pay`, 'POST', d).then(() => { toast('Payment recorded'); res.reload(); })} />}
    </>
  );
}
