import { useState } from 'react';
import { api, inr, day } from '../api.js';
import { Btn, Load, Table, Tag, FormModal, useApi, useToast } from '../ui.jsx';

const PROJECT_FIELDS = [{ name: 'title', label: 'Title' }, { name: 'description', label: 'Description', type: 'textarea', req: false },
  { name: 'budget', label: 'Budget (₹)', type: 'number' }, { name: 'deadline', label: 'Deadline', type: 'date', req: false }];

export default function Projects({ user }) {
  const res = useApi('/api/projects'), toast = useToast();
  const [modal, setModal] = useState(null);
  return (
    <>
      <div className="head"><h2>Projects</h2>{user.role === 'client' && <button className="btn primary" onClick={() => setModal({ t: 'new' })}>New project</button>}</div>
      <div className="panel"><Load res={res}>{rows => <Table rows={rows} empty={user.role === 'client' ? 'You have no projects yet. Create one to start receiving proposals.' : 'No projects to show.'} cols={[
        { h: 'Project', f: x => <><b>{x.title}</b><div className="muted">{x.description}</div></> }, { h: 'Client', f: x => x.client_name },
        { h: 'Budget', num: 1, f: x => inr(x.budget) }, { h: 'Deadline', f: x => day(x.deadline) }, { h: 'Proposals', num: 1, f: x => x.proposals }, { h: 'Status', f: x => <Tag s={x.status} /> },
        { h: '', f: x => <div className="row-actions">
          {user.role === 'freelancer' && x.status === 'open' && (x.applied ? <span className="muted">Applied</span> : <Btn primary onClick={() => setModal({ t: 'propose', p: x })}>Send proposal</Btn>)}
          {user.role === 'client' && x.client_id === user.user_id && x.status === 'open' && <Btn onClick={() => setModal({ t: 'edit', p: x })}>Edit</Btn>}</div> },
      ]} />}</Load></div>

      {modal?.t === 'new' && <FormModal title="New project" fields={PROJECT_FIELDS} onClose={() => setModal(null)}
        onSubmit={d => api('/api/projects', 'POST', d).then(() => { toast('Project created'); res.reload(); })} />}
      {modal?.t === 'edit' && <FormModal title="Edit project" fields={PROJECT_FIELDS} initial={{ ...modal.p, deadline: modal.p.deadline ? String(modal.p.deadline).slice(0, 10) : '' }} onClose={() => setModal(null)}
        onSubmit={d => api(`/api/projects/${modal.p.project_id}`, 'PUT', { ...d, version: modal.p.version }).then(() => { toast('Project updated'); res.reload(); })} />}
      {modal?.t === 'propose' && <FormModal title={`Proposal for ${modal.p.title}`} onClose={() => setModal(null)}
        fields={[{ name: 'quote', label: 'Your quote (₹)', type: 'number' }, { name: 'est_days', label: 'Estimated days', type: 'number' }, { name: 'cover_letter', label: 'Cover letter', type: 'textarea', req: false }]}
        onSubmit={d => api('/api/proposals', 'POST', { ...d, project_id: modal.p.project_id }).then(() => { toast('Proposal sent'); res.reload(); })} />}
    </>
  );
}
