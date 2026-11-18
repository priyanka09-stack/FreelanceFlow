-- writes notifications.
UPDATE milestones SET due_date = current_date - 5 WHERE milestone_id = 3;
CALL flag_overdue_milestones(NULL);                     -- returns no. of new notifications  created
SELECT user_id, message FROM notifications ORDER BY note_id DESC;
CALL flag_overdue_milestones(NULL);                     -- returns 0 - on conflict do nothing prevent duplicate

-- trigger - automatic status history logging
SELECT entity, entity_id, old_status, new_status, changed_at FROM status_history ORDER BY history_id DESC LIMIT 5;

-- trigger: check that invoice is not paid before changing it -err
UPDATE invoices SET amount = 1 WHERE status = 'paid';   
DELETE FROM invoices WHERE status = 'paid';             

-- trigger: check that milestone amount is not too high --err
INSERT INTO milestones(contract_id, title, amount) VALUES (1, 'Too much', 999999);   

-- roles and privilege
SET ROLE app_freelancer;
SELECT password_hash FROM users;                        -- ERROR: permission denied (column-level privilege)
INSERT INTO projects(client_id, title, budget) VALUES (4, 'x', 1);   -- ERROR: freelancers cannot create projects
RESET ROLE;
-- revoke and grant privileges to the app_freelancer role
REVOKE INSERT ON disputes FROM app_freelancer;
GRANT  INSERT ON disputes TO   app_freelancer;
