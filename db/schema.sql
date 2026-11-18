DROP VIEW IF EXISTS v_platform_revenue, v_client_spending, v_freelancer_earnings, v_contract_summary;
DROP TABLE IF EXISTS payments, invoices, disputes, milestones, contracts, proposals, projects,
                     client_profiles, freelancer_profiles, users CASCADE;
DROP SEQUENCE IF EXISTS invoice_seq;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SEQUENCE invoice_seq START 1001;

-- rbac role
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='app_admin')      THEN CREATE ROLE app_admin NOLOGIN;      END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='app_client')     THEN CREATE ROLE app_client NOLOGIN;     END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='app_freelancer') THEN CREATE ROLE app_freelancer NOLOGIN; END IF;
END $$;

-- tables

CREATE TABLE users (
  user_id       SERIAL PRIMARY KEY,
  name          VARCHAR(80)  NOT NULL,
  email         VARCHAR(120) NOT NULL UNIQUE,
  password_hash TEXT         NOT NULL,
  role          VARCHAR(12)  NOT NULL CHECK (role IN ('admin','client','freelancer')),
  created_at    TIMESTAMP    NOT NULL DEFAULT now()
);
CREATE TABLE client_profiles (
  user_id INT PRIMARY KEY REFERENCES users ON DELETE CASCADE,
  company VARCHAR(100)
);
CREATE TABLE freelancer_profiles (
  user_id     INT PRIMARY KEY REFERENCES users ON DELETE CASCADE,
  skills      TEXT[] NOT NULL DEFAULT '{}',
  hourly_rate NUMERIC(10,2) CHECK (hourly_rate > 0)
);
CREATE TABLE projects (
  project_id  SERIAL PRIMARY KEY,
  client_id   INT NOT NULL REFERENCES users,
  title       VARCHAR(120) NOT NULL,
  description TEXT,
  budget      NUMERIC(12,2) NOT NULL CHECK (budget > 0),
  deadline    DATE,
  status      VARCHAR(12) NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','completed','cancelled')),
  version     INT NOT NULL DEFAULT 1,          -- optimistic locking
  created_at  TIMESTAMP NOT NULL DEFAULT now()
);
CREATE TABLE proposals (
  proposal_id   SERIAL PRIMARY KEY,
  project_id    INT NOT NULL REFERENCES projects ON DELETE CASCADE,
  freelancer_id INT NOT NULL REFERENCES users,
  quote         NUMERIC(12,2) NOT NULL CHECK (quote > 0),
  est_days      INT NOT NULL CHECK (est_days > 0),
  cover_letter  TEXT,
  status        VARCHAR(10) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected')),
  created_at    TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (project_id, freelancer_id)
);
CREATE TABLE contracts (
  contract_id     SERIAL PRIMARY KEY,
  proposal_id     INT NOT NULL UNIQUE REFERENCES proposals,
  project_id      INT NOT NULL UNIQUE REFERENCES projects,
  client_id       INT NOT NULL REFERENCES users,
  freelancer_id   INT NOT NULL REFERENCES users,
  agreed_amount   NUMERIC(12,2) NOT NULL CHECK (agreed_amount > 0),
  commission_rate NUMERIC(4,2) NOT NULL DEFAULT 10 CHECK (commission_rate BETWEEN 0 AND 50),
  start_date      DATE NOT NULL DEFAULT current_date,
  status          VARCHAR(12) NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','terminated'))
);
CREATE TABLE milestones (
  milestone_id SERIAL PRIMARY KEY,
  contract_id  INT NOT NULL REFERENCES contracts ON DELETE CASCADE,
  title        VARCHAR(120) NOT NULL,
  due_date     DATE,
  amount       NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  status       VARCHAR(10) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','submitted','approved','paid'))
);
CREATE TABLE invoices (
  invoice_id   SERIAL PRIMARY KEY,
  invoice_no   VARCHAR(20) NOT NULL UNIQUE,
  milestone_id INT NOT NULL UNIQUE REFERENCES milestones,
  amount       NUMERIC(12,2) NOT NULL,
  commission   NUMERIC(12,2) NOT NULL,
  net_amount   NUMERIC(12,2) NOT NULL,
  issued_at    TIMESTAMP NOT NULL DEFAULT now(),
  status       VARCHAR(8) NOT NULL DEFAULT 'unpaid' CHECK (status IN ('unpaid','paid'))
);
CREATE TABLE payments (
  payment_id SERIAL PRIMARY KEY,
  invoice_id INT NOT NULL REFERENCES invoices,
  amount     NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  method     VARCHAR(20) NOT NULL CHECK (method IN ('UPI','Card','Bank Transfer')),
  status     VARCHAR(10) NOT NULL DEFAULT 'completed' CHECK (status IN ('pending','completed','failed')),
  paid_at    TIMESTAMP NOT NULL DEFAULT now()
);
CREATE TABLE disputes (
  dispute_id  SERIAL PRIMARY KEY,
  contract_id INT NOT NULL REFERENCES contracts,
  raised_by   INT NOT NULL REFERENCES users,
  reason      TEXT NOT NULL,
  status      VARCHAR(12) NOT NULL DEFAULT 'open' CHECK (status IN ('open','under_review','resolved')),
  resolution  TEXT,
  created_at  TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX idx_projects_status     ON projects(status);
CREATE INDEX idx_proposals_project   ON proposals(project_id);
CREATE INDEX idx_milestones_contract ON milestones(contract_id);

-- trigger + procedure + cursor
CREATE OR REPLACE FUNCTION trg_milestone_budget() RETURNS TRIGGER AS $$
DECLARE cap NUMERIC; used NUMERIC;
BEGIN
  SELECT agreed_amount INTO cap FROM contracts WHERE contract_id = NEW.contract_id FOR UPDATE;
  SELECT COALESCE(SUM(amount),0) INTO used FROM milestones
   WHERE contract_id = NEW.contract_id AND milestone_id IS DISTINCT FROM NEW.milestone_id;
  IF used + NEW.amount > cap THEN
    RAISE EXCEPTION 'Milestones total (%) would exceed the contract amount (%)', used + NEW.amount, cap;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
CREATE TRIGGER milestone_budget BEFORE INSERT OR UPDATE OF amount ON milestones
  FOR EACH ROW EXECUTE FUNCTION trg_milestone_budget();

-- transaction inntegrity
CREATE OR REPLACE FUNCTION accept_proposal(p_id INT, p_client INT) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE pr proposals%ROWTYPE; pj projects%ROWTYPE; c_id INT;
BEGIN
  SELECT * INTO pr FROM proposals WHERE proposal_id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Proposal not found'; END IF;
  SELECT * INTO pj FROM projects WHERE project_id = pr.project_id FOR UPDATE;
  IF pj.client_id <> p_client THEN RAISE EXCEPTION 'This is not your project'; END IF;
  IF pj.status <> 'open' OR pr.status <> 'pending' THEN RAISE EXCEPTION 'This proposal can no longer be accepted'; END IF;
  UPDATE proposals SET status='accepted' WHERE proposal_id = p_id;
  UPDATE proposals SET status='rejected' WHERE project_id = pj.project_id AND proposal_id <> p_id AND status='pending';
  UPDATE projects  SET status='in_progress' WHERE project_id = pj.project_id;
  INSERT INTO contracts(proposal_id, project_id, client_id, freelancer_id, agreed_amount)
  VALUES (p_id, pj.project_id, pj.client_id, pr.freelancer_id, pr.quote) RETURNING contract_id INTO c_id;
  RETURN c_id;
END $$;

CREATE OR REPLACE FUNCTION submit_milestone(m_id INT, f_id INT) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE milestones m SET status='submitted'
    FROM contracts c
   WHERE m.milestone_id = m_id AND c.contract_id = m.contract_id
     AND c.freelancer_id = f_id AND m.status = 'pending' AND c.status = 'active';
  IF NOT FOUND THEN RAISE EXCEPTION 'This milestone cannot be submitted'; END IF;
END $$;

CREATE OR REPLACE FUNCTION approve_milestone(m_id INT, c_client INT) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE m milestones%ROWTYPE; k contracts%ROWTYPE; comm NUMERIC; inv INT;
BEGIN
  SELECT * INTO m FROM milestones WHERE milestone_id = m_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Milestone not found'; END IF;
  SELECT * INTO k FROM contracts WHERE contract_id = m.contract_id;
  IF k.client_id <> c_client THEN RAISE EXCEPTION 'This is not your contract'; END IF;
  IF m.status <> 'submitted' THEN RAISE EXCEPTION 'Only submitted milestones can be approved'; END IF;
  comm := ROUND(m.amount * k.commission_rate / 100, 2);
  UPDATE milestones SET status='approved' WHERE milestone_id = m_id;
  INSERT INTO invoices(invoice_no, milestone_id, amount, commission, net_amount)
  VALUES ('INV-' || to_char(now(),'YYYY') || '-' || nextval('invoice_seq'), m_id, m.amount, comm, m.amount - comm)
  RETURNING invoice_id INTO inv;
  RETURN inv;
END $$;

CREATE OR REPLACE FUNCTION pay_invoice(inv_id INT, c_client INT, p_method TEXT) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE i invoices%ROWTYPE; k contracts%ROWTYPE; pay INT; unpaid INT;
BEGIN
  SELECT * INTO i FROM invoices WHERE invoice_id = inv_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Invoice not found'; END IF;
  SELECT c.* INTO k FROM contracts c JOIN milestones m USING (contract_id) WHERE m.milestone_id = i.milestone_id;
  IF k.client_id <> c_client THEN RAISE EXCEPTION 'This is not your invoice'; END IF;
  IF i.status = 'paid' THEN RAISE EXCEPTION 'This invoice is already paid'; END IF;
  INSERT INTO payments(invoice_id, amount, method) VALUES (inv_id, i.amount, p_method) RETURNING payment_id INTO pay;
  UPDATE invoices   SET status='paid' WHERE invoice_id = inv_id;
  UPDATE milestones SET status='paid' WHERE milestone_id = i.milestone_id;
  SELECT COUNT(*) INTO unpaid FROM milestones WHERE contract_id = k.contract_id AND status <> 'paid';
  IF unpaid = 0 AND (SELECT SUM(amount) FROM milestones WHERE contract_id = k.contract_id) = k.agreed_amount THEN
    UPDATE contracts SET status='completed' WHERE contract_id = k.contract_id;
    UPDATE projects  SET status='completed' WHERE project_id  = k.project_id;
  END IF;
  RETURN pay;
END $$;

-- reports view
CREATE VIEW v_contract_summary AS
SELECT c.contract_id, p.title, c.client_id, c.freelancer_id, cu.name AS client_name, fu.name AS freelancer_name,
       c.agreed_amount, c.commission_rate, c.status,
       COALESCE(SUM(m.amount),0) AS planned,
       COALESCE(SUM(m.amount) FILTER (WHERE m.status='paid'),0)      AS paid,
       COALESCE(SUM(m.amount) FILTER (WHERE m.status='approved'),0)  AS awaiting_payment,
       COALESCE(SUM(m.amount) FILTER (WHERE m.status='submitted'),0) AS in_review,
       c.agreed_amount - COALESCE(SUM(m.amount) FILTER (WHERE m.status='paid'),0) AS outstanding
FROM contracts c
JOIN projects p ON p.project_id = c.project_id
JOIN users cu ON cu.user_id = c.client_id
JOIN users fu ON fu.user_id = c.freelancer_id
LEFT JOIN milestones m ON m.contract_id = c.contract_id
GROUP BY c.contract_id, p.title, cu.name, fu.name;

CREATE VIEW v_freelancer_earnings AS
SELECT u.user_id AS freelancer_id, u.name,
       COUNT(DISTINCT c.contract_id) AS contracts,
       COUNT(DISTINCT c.contract_id) FILTER (WHERE c.status='completed') AS completed,
       COALESCE(SUM(i.amount)     FILTER (WHERE i.status='paid'),0) AS gross,
       COALESCE(SUM(i.commission) FILTER (WHERE i.status='paid'),0) AS commission,
       COALESCE(SUM(i.net_amount) FILTER (WHERE i.status='paid'),0) AS net_earned
FROM users u
LEFT JOIN contracts  c ON c.freelancer_id = u.user_id
LEFT JOIN milestones m ON m.contract_id = c.contract_id
LEFT JOIN invoices   i ON i.milestone_id = m.milestone_id
WHERE u.role='freelancer' GROUP BY u.user_id, u.name;

CREATE VIEW v_client_spending AS
SELECT u.user_id AS client_id, u.name,
       COUNT(DISTINCT c.contract_id) AS contracts,
       COALESCE(SUM(i.amount) FILTER (WHERE i.status='paid'),0)   AS total_paid,
       COALESCE(SUM(i.amount) FILTER (WHERE i.status='unpaid'),0) AS outstanding
FROM users u
LEFT JOIN contracts  c ON c.client_id = u.user_id
LEFT JOIN milestones m ON m.contract_id = c.contract_id
LEFT JOIN invoices   i ON i.milestone_id = m.milestone_id
WHERE u.role='client' GROUP BY u.user_id, u.name;

CREATE VIEW v_platform_revenue AS
SELECT (SELECT COALESCE(SUM(amount),0)     FROM invoices WHERE status='paid')   AS total_paid,
       (SELECT COALESCE(SUM(commission),0) FROM invoices WHERE status='paid')   AS commission_earned,
       (SELECT COALESCE(SUM(amount),0)     FROM invoices WHERE status='unpaid') AS outstanding,
       (SELECT COUNT(*) FROM contracts WHERE status='active')                   AS active_contracts,
       (SELECT COUNT(*) FROM disputes  WHERE status <> 'resolved')              AS open_disputes;

-- rbac grants
GRANT USAGE ON SCHEMA public TO app_admin, app_client, app_freelancer;
GRANT SELECT ON client_profiles, freelancer_profiles, projects, proposals, contracts, milestones,
                invoices, payments, disputes, v_contract_summary, v_freelancer_earnings,
                v_client_spending, v_platform_revenue TO app_admin, app_client, app_freelancer;
GRANT SELECT (user_id, name, email, role, created_at) ON users TO app_client, app_freelancer;
GRANT ALL ON ALL TABLES IN SCHEMA public TO app_admin;
GRANT INSERT ON projects, milestones TO app_client;
GRANT UPDATE (title, description, budget, deadline, version) ON projects TO app_client;
GRANT INSERT ON proposals TO app_freelancer;
GRANT INSERT ON disputes TO app_client, app_freelancer;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_admin, app_client, app_freelancer;
GRANT EXECUTE ON FUNCTION accept_proposal(INT,INT), submit_milestone(INT,INT),
      approve_milestone(INT,INT), pay_invoice(INT,INT,TEXT) TO app_admin, app_client, app_freelancer;
