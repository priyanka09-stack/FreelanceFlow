import { useEffect, useState } from 'react';
import { NavLink, Navigate, Route, Routes } from 'react-router-dom';
import { api } from './api.js';
import Login from './pages/Login.jsx';
import Overview from './pages/Overview.jsx';
import Projects from './pages/Projects.jsx';
import Proposals from './pages/Proposals.jsx';
import { Contracts, ContractDetail } from './pages/Contracts.jsx';
import Invoices from './pages/Invoices.jsx';
import Disputes from './pages/Disputes.jsx';
import Analytics from './pages/Analytics.jsx';
import Audit from './pages/Audit.jsx';

// Add a page = add one entry here + one file in pages/.
const NAV = [
  ['/', 'Overview'], ['/projects', 'Projects'], ['/proposals', 'Proposals'], ['/contracts', 'Contracts'],
  ['/invoices', 'Invoices'], ['/disputes', 'Disputes'], ['/analytics', 'Analytics'], ['/audit', 'Audit log', 'admin'],
];

export default function App() {
  const [user, setUser] = useState(undefined);
  useEffect(() => { api('/api/me').then(setUser).catch(() => setUser(null)); }, []);
  if (user === undefined) return null;
  if (!user) return <Login onLogin={setUser} />;
  const logout = async () => { await api('/api/logout', 'POST'); setUser(null); };
  return (
    <div className="app">
      <aside className="side">
        <div className="brand">FreelanceFlow</div>
        <nav>{NAV.filter(n => !n[2] || n[2] === user.role).map(([to, label]) =>
          <NavLink key={to} to={to} end={to === '/'} className="nav-link">{label}</NavLink>)}</nav>
        <div className="who"><b>{user.name}</b><span>{user.role}</span><button className="link" onClick={logout}>Sign out</button></div>
      </aside>
      <main>
        <Routes>
          <Route path="/" element={<Overview user={user} />} />
          <Route path="/projects" element={<Projects user={user} />} />
          <Route path="/proposals" element={<Proposals user={user} />} />
          <Route path="/contracts" element={<Contracts />} />
          <Route path="/contracts/:id" element={<ContractDetail user={user} />} />
          <Route path="/invoices" element={<Invoices user={user} />} />
          <Route path="/disputes" element={<Disputes user={user} />} />
          <Route path="/analytics" element={<Analytics user={user} />} />
          <Route path="/audit" element={user.role === 'admin' ? <Audit /> : <Navigate to="/" />} />
          <Route path="*" element={<Navigate to="/" />} />
        </Routes>
      </main>
    </div>
  );
}
