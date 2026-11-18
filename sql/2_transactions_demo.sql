-- commit,rollback and savepoint
BEGIN;
  INSERT INTO projects(client_id, title, budget) VALUES (2, 'Txn demo project', 1000);
  SAVEPOINT after_project;
  INSERT INTO projects(client_id, title, budget) VALUES (2, 'Bad project', -5);   -- fails: CHECK (budget > 0)
  ROLLBACK TO SAVEPOINT after_project;                                           -- undo ONLY the failed part
  SELECT title FROM projects WHERE title LIKE '%demo%' OR title = 'Bad project'; -- demo project still here
ROLLBACK;                                                                        -- now undo everything (use COMMIT to keep)
SELECT COUNT(*) AS should_be_zero FROM projects WHERE title = 'Txn demo project';

-- isolation level - 2 window - for demo
-- Window 1:                                            -- Window 2:
-- BEGIN ISOLATION LEVEL REPEATABLE READ;
-- SELECT budget FROM projects WHERE project_id = 1;
--                                                      UPDATE projects SET budget = budget + 1 WHERE project_id = 1;
-- SELECT budget FROM projects WHERE project_id = 1;    -- same value as before (snapshot), no non-repeatable read
-- COMMIT;
-- SELECT budget FROM projects WHERE project_id = 1;    -- now sees the new value
-- (Repeat with READ COMMITTED, PostgreSQL's default: the second SELECT WOULD show the change.)

-- pessimistic lock & deadlock prevention
-- Window 1: BEGIN; SELECT * FROM projects WHERE project_id = 1 FOR UPDATE;   -- row locked
-- Window 2: BEGIN; UPDATE projects SET title = 'x' WHERE project_id = 1;     -- WAITS until window 1 commits
-- Deadlock: W1: BEGIN; UPDATE projects SET budget=1 WHERE project_id=1;
--           W2: BEGIN; UPDATE projects SET budget=1 WHERE project_id=2;
--           W1: UPDATE projects SET budget=1 WHERE project_id=2;   -- waits for W2
--           W2: UPDATE projects SET budget=1 WHERE project_id=1;   -- PostgreSQL detects the cycle and aborts one
-- Fix: always lock rows in the same order (e.g. ORDER BY id), which is why our functions lock proposal then project in a fixed order.

-- optimistic locking
-- Read the row and remember its version, then update ONLY if nobody changed it meanwhile.
SELECT project_id, budget, version FROM projects WHERE project_id = 1;
UPDATE projects SET budget = 55000 WHERE project_id = 1 AND version = 1 RETURNING project_id, version;   -- 1 row: success, trigger bumps version to 2
UPDATE projects SET budget = 60000 WHERE project_id = 1 AND version = 1 RETURNING project_id, version;   -- 0 rows: stale version, app returns HTTP 409

-- atomic business transition
-- pay_invoice() inserts the payment, flips the invoice and milestone, and may close the contract. All or nothing.
-- Try paying an already paid invoice: the exception rolls everything back.
SELECT pay_invoice(1, 2, 'UPI');
