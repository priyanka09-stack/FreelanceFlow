-- join
-- inner join - contract + project + both parties
SELECT c.contract_id, p.title, cu.name AS client, fu.name AS freelancer, c.agreed_amount
FROM contracts c
JOIN projects p ON p.project_id = c.project_id
JOIN users cu ON cu.user_id = c.client_id
JOIN users fu ON fu.user_id = c.freelancer_id;

-
SELECT p.project_id, p.title, COUNT(pr.proposal_id) AS proposals
FROM projects p LEFT JOIN proposals pr ON pr.project_id = p.project_id
GROUP BY p.project_id, p.title ORDER BY proposals DESC;


SELECT u.name AS freelancer, c.contract_id
FROM (SELECT * FROM users WHERE role = 'freelancer') u
FULL OUTER JOIN contracts c ON c.freelancer_id = u.user_id;

SELECT a.title AS project_a, b.title AS project_b, a.budget AS budget_a, b.budget AS budget_b
FROM projects a JOIN projects b ON a.client_id = b.client_id AND a.project_id < b.project_id;

-- subquery
SELECT title, budget FROM projects WHERE budget > (SELECT AVG(budget) FROM projects);

-- open projects nobody has bid on yet.
SELECT p.title FROM projects p
WHERE p.status = 'open' AND NOT EXISTS (SELECT 1 FROM proposals pr WHERE pr.project_id = p.project_id);

SELECT name FROM users WHERE user_id IN (SELECT freelancer_id FROM contracts WHERE status = 'active');

SELECT t.client_id, t.total FROM (SELECT client_id, SUM(budget) AS total FROM projects GROUP BY client_id) t WHERE t.total > 60000;

-- set
SELECT client_id AS user_id FROM contracts UNION SELECT freelancer_id FROM contracts;

-- intersect
SELECT freelancer_id FROM proposals pr JOIN projects p USING (project_id) WHERE p.client_id = 2
INTERSECT
SELECT freelancer_id FROM proposals pr JOIN projects p USING (project_id) WHERE p.client_id = 3;

-- except - freelancers who never submitted any proposal
SELECT user_id FROM users WHERE role = 'freelancer' EXCEPT SELECT freelancer_id FROM proposals;

-- agreegation fnc.
SELECT client_id, SUM(budget) AS total_budget, COUNT(*) FILTER (WHERE status = 'open') AS open_projects
FROM projects GROUP BY client_id HAVING COUNT(*) >= 2;

-- window function
-- rank -- leaderboard of freelancers by net earnings 
SELECT name, net_earned, RANK() OVER (ORDER BY net_earned DESC) AS rnk FROM v_freelancer_earnings;

--  the cheapest proposal for each project
SELECT * FROM (
  SELECT pr.project_id, pr.freelancer_id, pr.quote,
         ROW_NUMBER() OVER (PARTITION BY pr.project_id ORDER BY pr.quote) AS rn
  FROM proposals pr) x WHERE rn = 1;

--  cumulative money paid in payment order
SELECT payment_id, paid_at::date, amount, SUM(amount) OVER (ORDER BY paid_at, payment_id) AS running_total FROM payments;

-- gap between consecutive invoice
SELECT invoice_no, issued_at, issued_at - LAG(issued_at) OVER (ORDER BY issued_at) AS since_previous FROM invoices;

-- each client's % of all platform spending
SELECT name, total_paid, ROUND(100.0 * total_paid / NULLIF(SUM(total_paid) OVER (), 0), 1) AS pct_of_platform FROM v_client_spending;

-- CTE
WITH paid AS (
  SELECT m.contract_id, SUM(m.amount) AS paid_amount FROM milestones m WHERE m.status = 'paid' GROUP BY m.contract_id
)
SELECT c.contract_id, c.agreed_amount, p.paid_amount, ROUND(100.0 * p.paid_amount / c.agreed_amount, 1) AS pct_paid
FROM contracts c JOIN paid p USING (contract_id) WHERE p.paid_amount > c.agreed_amount / 2;

-- rec. CTE
WITH RECURSIVE days(d) AS (SELECT current_date UNION ALL SELECT d + 1 FROM days WHERE d < current_date + 6)
SELECT d, COUNT(m.milestone_id) AS due FROM days LEFT JOIN milestones m ON m.due_date = d GROUP BY d ORDER BY d;

--view
SELECT * FROM v_contract_summary WHERE outstanding > 0 ORDER BY outstanding DESC;
