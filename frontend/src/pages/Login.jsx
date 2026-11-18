import { useState } from 'react';
import { api } from '../api.js';
import { useToast } from '../ui.jsx';

const DEMO = [['admin@ff.com', 'Admin'], ['acme@ff.com', 'Client: Acme'], ['nova@ff.com', 'Client: Nova'], ['riya@ff.com', 'Freelancer: Riya'], ['sara@ff.com', 'Freelancer: Sara']];

export default function Login({ onLogin }) {
  const [email, setEmail] = useState(''), [password, setPassword] = useState('');
  const toast = useToast();
  const submit = async e => {
    e.preventDefault();
    try { onLogin(await api('/api/login', 'POST', { email, password })); } catch (er) { toast(er.message, true); }
  };
  return (
    <section className="login">
      <form className="login-card" onSubmit={submit}>
        <h1>FreelanceFlow</h1>
        <p className="sub">Projects, milestones and payments in one place.</p>
        <label>Email<input type="email" value={email} onChange={e => setEmail(e.target.value)} autoComplete="username" required /></label>
        <label>Password<input type="password" value={password} onChange={e => setPassword(e.target.value)} autoComplete="current-password" required /></label>
        <button className="btn primary">Sign in</button>
        <p className="hint">Demo accounts (password <b>pass123</b>). Click to fill:</p>
        <div className="chips">{DEMO.map(([em, l]) => <button type="button" key={em} className="chip" onClick={() => { setEmail(em); setPassword('pass123'); }}>{l}</button>)}</div>
      </form>
    </section>
  );
}
