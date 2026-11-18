DROP TABLE IF EXISTS status_history, notifications CASCADE;
--extra table
CREATE TABLE status_history (
  history_id SERIAL PRIMARY KEY,
  entity     VARCHAR(12) NOT NULL,           -- 'project' | 'contract' | 'milestone'
  entity_id  INT NOT NULL,
  old_status VARCHAR(12),
  new_status VARCHAR(12) NOT NULL,
  changed_at TIMESTAMP NOT NULL DEFAULT now()
);
CREATE TABLE notifications (
  note_id      SERIAL PRIMARY KEY,
  user_id      INT NOT NULL REFERENCES users,
  milestone_id INT REFERENCES milestones ON DELETE CASCADE,
  kind         VARCHAR(20) NOT NULL,
  message      TEXT NOT NULL,
  created_at   TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (milestone_id, user_id, kind)       -- one overdue alert per person per milestone
);

-- trigger - automatic status history logging
CREATE OR REPLACE FUNCTION trg_log_status() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO status_history(entity, entity_id, old_status, new_status)
  VALUES (TG_ARGV[0], (to_jsonb(NEW) ->> TG_ARGV[1])::INT, OLD.status, NEW.status);
  RETURN NEW;
END $$;
CREATE TRIGGER log_milestone_status AFTER UPDATE OF status ON milestones FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION trg_log_status('milestone','milestone_id');
CREATE TRIGGER log_contract_status AFTER UPDATE OF status ON contracts FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION trg_log_status('contract','contract_id');
CREATE TRIGGER log_project_status AFTER UPDATE OF status ON projects FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION trg_log_status('project','project_id');

-- paid invoice can't be changed
CREATE OR REPLACE FUNCTION trg_protect_paid_invoice() RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status = 'paid' THEN
    RAISE EXCEPTION 'Invoice % is paid and cannot be changed or deleted', OLD.invoice_no;
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;
CREATE TRIGGER protect_paid_invoice BEFORE UPDATE OR DELETE ON invoices
  FOR EACH ROW EXECUTE FUNCTION trg_protect_paid_invoice();

-- trigger
CREATE OR REPLACE FUNCTION trg_bump_version() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.version = OLD.version THEN NEW.version := OLD.version + 1; END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;
CREATE TRIGGER project_version BEFORE UPDATE OF title, description, budget, deadline ON projects
  FOR EACH ROW EXECUTE FUNCTION trg_bump_version();

-- stored procedure + cursor
CREATE OR REPLACE PROCEDURE flag_overdue_milestones(INOUT flagged INT DEFAULT 0)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  cur CURSOR FOR
    SELECT m.milestone_id, m.title, m.due_date, c.freelancer_id, c.client_id
      FROM milestones m JOIN contracts c ON c.contract_id = m.contract_id
     WHERE m.due_date < current_date AND m.status IN ('pending','submitted') AND c.status = 'active'
     ORDER BY m.due_date;
  r RECORD; n INT;
BEGIN
  flagged := 0;
  OPEN cur;
  LOOP
    FETCH cur INTO r;
    EXIT WHEN NOT FOUND;
    INSERT INTO notifications(user_id, milestone_id, kind, message)
    VALUES (r.freelancer_id, r.milestone_id, 'overdue', format('Milestone "%s" was due on %s', r.title, r.due_date))
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS n = ROW_COUNT; flagged := flagged + n;
    INSERT INTO notifications(user_id, milestone_id, kind, message)
    VALUES (r.client_id, r.milestone_id, 'overdue', format('Milestone "%s" is overdue (due %s)', r.title, r.due_date))
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS n = ROW_COUNT; flagged := flagged + n;
  END LOOP;
  CLOSE cur;
END $$;

-- extra index
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_milestones_open_due ON milestones(due_date) WHERE status IN ('pending','submitted');  -- partial index
CREATE INDEX idx_history_entity ON status_history(entity, entity_id);
CREATE INDEX idx_payments_paid_at ON payments(paid_at);

-- star schema
CREATE VIEW dim_client AS
  SELECT u.user_id AS client_key, u.name AS client_name, cp.company FROM users u LEFT JOIN client_profiles cp ON cp.user_id = u.user_id WHERE u.role = 'client';
CREATE VIEW dim_freelancer AS
  SELECT u.user_id AS freelancer_key, u.name AS freelancer_name, fp.hourly_rate, fp.skills FROM users u LEFT JOIN freelancer_profiles fp ON fp.user_id = u.user_id WHERE u.role = 'freelancer';
CREATE VIEW dim_project AS
  SELECT project_id AS project_key, title AS project_title, client_id AS client_key, budget FROM projects;
CREATE VIEW dim_date AS
  SELECT DISTINCT paid_at::date AS date_key, EXTRACT(YEAR FROM paid_at)::INT AS year, EXTRACT(MONTH FROM paid_at)::INT AS month, to_char(paid_at,'Mon YYYY') AS month_name FROM payments;
CREATE VIEW fact_payments AS
  SELECT y.payment_id, y.paid_at::date AS date_key, c.client_id AS client_key, c.freelancer_id AS freelancer_key, c.project_id AS project_key,
         y.amount, i.commission, i.net_amount, y.method
  FROM payments y JOIN invoices i ON i.invoice_id = y.invoice_id
  JOIN milestones m ON m.milestone_id = i.milestone_id JOIN contracts c ON c.contract_id = m.contract_id
  WHERE y.status = 'completed';

-- grants
GRANT SELECT ON status_history, notifications TO app_admin, app_client, app_freelancer;
GRANT ALL ON status_history, notifications TO app_admin;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_admin, app_client, app_freelancer;
GRANT SELECT ON dim_client, dim_freelancer, dim_project, dim_date, fact_payments TO app_admin;
GRANT EXECUTE ON PROCEDURE flag_overdue_milestones(INT) TO app_admin;
