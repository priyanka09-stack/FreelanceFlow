import { stamp } from '../api.js';
import { Load, Table, useApi } from '../ui.jsx';

export default function Audit() {
  const res = useApi('/api/audit');
  return (
    <>
      <div className="head"><h2>Audit log</h2><span className="muted">Stored in MongoDB, last 100 events</span></div>
      <div className="panel"><Load res={res}>{rows => <Table rows={rows} empty="No events yet." cols={[
        { h: 'Time', f: x => stamp(x.ts) }, { h: 'Who', f: x => <>{x.actor || '-'} <span className="muted">{x.role}</span></> },
        { h: 'Action', f: x => <b>{x.action}</b> }, { h: 'Entity', f: x => `${x.entity} #${x.entity_id ?? ''}` },
        { h: 'Details', f: x => <span className="muted">{JSON.stringify(x.details)}</span> }]} />}</Load></div>
    </>
  );
}
