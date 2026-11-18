CREATE TEMP TABLE big_invoices AS
SELECT g AS invoice_id, 'INV-' || g AS invoice_no, (g % 500) + 1 AS client_id,
       (random() * 50000)::NUMERIC(12,2) AS amount,
       CASE WHEN g % 10 = 0 THEN 'unpaid' ELSE 'paid' END AS status,
       now() - (g || ' minutes')::interval AS issued_at
FROM generate_series(1, 200000) g;
ANALYZE big_invoices;

-- before sequential scan reads all 200,000 rows
EXPLAIN ANALYZE SELECT * FROM big_invoices WHERE client_id = 42;

-- create a B-tree index, then run the SAME query
CREATE INDEX idx_big_client ON big_invoices(client_id);
ANALYZE big_invoices;
EXPLAIN ANALYZE SELECT * FROM big_invoices WHERE client_id = 42;     -- bitmap/index scan, much faster

-- composite index: serves WHERE client_id = ? AND status = ? ORDER BY issued_at
CREATE INDEX idx_big_client_status_date ON big_invoices(client_id, status, issued_at);
ANALYZE big_invoices;
EXPLAIN ANALYZE SELECT * FROM big_invoices WHERE client_id = 42 AND status = 'unpaid' ORDER BY issued_at;

-- partial index
CREATE INDEX idx_big_unpaid ON big_invoices(issued_at) WHERE status = 'unpaid';
ANALYZE big_invoices;
EXPLAIN ANALYZE SELECT * FROM big_invoices WHERE status = 'unpaid' ORDER BY issued_at LIMIT 20;

-- when an index does NOT help
EXPLAIN ANALYZE SELECT * FROM big_invoices WHERE client_id + 0 = 42;    -- seq scan again
-- compare sizes
SELECT indexrelid::regclass AS index_name, pg_size_pretty(pg_relation_size(indexrelid)) AS size FROM pg_index WHERE indrelid = 'big_invoices'::regclass;
