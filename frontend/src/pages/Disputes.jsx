import { useState } from 'react';
import { api } from '../api.js';
import { Btn, FormModal, Load, Table, Tag, useApi, useToast } from '../ui.jsx';

export default function Disputes({ user }) {
  const res = useApi('/api/disputes'), toast = useToast();
  const [sel, setSel] = useState(null);
  return (
    <>
      <div className="head"><h2>Disputes</h2></div>
      <div className="panel"><Load res={res}>{rows => <Table rows={rows} empty="No disputes. Raise one from a contract if a milestone or payment goes wrong." cols={[
        { h: 'Project', f: x => x.project }, { h: 'Raised by', f: x => x.raised_by_name }, { h: 'Reason', f: x => x.reason },
        { h: 'Resolution', f: x => x.resolution || '-' }, { h: 'Status', f: x => <Tag s={x.status} /> },
        { h: '', f: x => user.role === 'admin' && x.status !== 'resolved' && <Btn primary onClick={() => setSel(x.dispute_id)}>Resolve</Btn> },
      ]} />}</Load></div>
      {sel && <FormModal title="Resolve dispute" onClose={() => setSel(null)} fields={[{ name: 'resolution', label: 'Resolution', type: 'textarea' }]}
        onSubmit={d => api(`/api/disputes/${sel}/resolve`, 'POST', d).then(() => { toast('Dispute resolved'); res.reload(); })} />}
    </>
  );
}
