import { api, inr } from '../api.js';
import { Btn, Load, Table, Tag, useAction, useApi } from '../ui.jsx';

export default function Proposals({ user }) {
  const res = useApi('/api/proposals'), act = useAction(res.reload);
  return (
    <>
      <div className="head"><h2>Proposals</h2></div>
      <div className="panel"><Load res={res}>{rows => <Table rows={rows} empty="No proposals yet." cols={[
        { h: 'Project', f: x => x.title }, { h: 'Freelancer', f: x => x.freelancer_name }, { h: 'Quote', num: 1, f: x => inr(x.quote) }, { h: 'Days', num: 1, f: x => x.est_days },
        { h: 'Cover letter', f: x => x.cover_letter }, { h: 'Status', f: x => <Tag s={x.status} /> },
        { h: '', f: x => user.role === 'client' && x.status === 'pending' && <Btn primary onClick={() => act(() => api(`/api/proposals/${x.proposal_id}/accept`, 'POST'), 'Contract created')}>Accept and create contract</Btn> },
      ]} />}</Load></div>
    </>
  );
}
