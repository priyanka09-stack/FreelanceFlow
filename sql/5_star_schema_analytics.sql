SELECT d.month_name, cl.client_name, SUM(f.amount) AS paid, SUM(f.commission) AS platform_commission
FROM fact_payments f JOIN dim_date d USING (date_key) JOIN dim_client cl USING (client_key)
GROUP BY d.year, d.month, d.month_name, cl.client_name ORDER BY d.year, d.month;


SELECT COALESCE(fr.freelancer_name, 'ALL FREELANCERS') AS freelancer, SUM(f.net_amount) AS net_paid
FROM fact_payments f JOIN dim_freelancer fr USING (freelancer_key)
GROUP BY ROLLUP (fr.freelancer_name);

SELECT pr.project_title, cl.client_name, SUM(f.amount) AS paid
FROM fact_payments f JOIN dim_project pr USING (project_key) JOIN dim_client cl ON cl.client_key = pr.client_key
GROUP BY pr.project_title, cl.client_name;

WITH m AS (SELECT date_trunc('month', date_key) AS month, SUM(amount) AS paid FROM fact_payments GROUP BY 1)
SELECT month::date, paid, paid - LAG(paid) OVER (ORDER BY month) AS change_vs_prev_month FROM m ORDER BY month;
