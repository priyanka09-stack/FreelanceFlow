-- demo data for FreelanceFlow (users, projects, proposals, contracts, milestones, invoices, payments, disputes)
INSERT INTO users(name,email,password_hash,role) VALUES
 ('Admin','admin@ff.com',      crypt('pass123',gen_salt('bf')),'admin'),
 ('Acme Corp','acme@ff.com',   crypt('pass123',gen_salt('bf')),'client'),
 ('Nova Studio','nova@ff.com', crypt('pass123',gen_salt('bf')),'client'),
 ('Riya Sharma','riya@ff.com', crypt('pass123',gen_salt('bf')),'freelancer'),
 ('Aman Verma','aman@ff.com',  crypt('pass123',gen_salt('bf')),'freelancer'),
 ('Sara Khan','sara@ff.com',   crypt('pass123',gen_salt('bf')),'freelancer');
INSERT INTO client_profiles VALUES (2,'Acme Corp'),(3,'Nova Studio');
INSERT INTO freelancer_profiles VALUES (4,'{react,ui}',900),(5,'{python,postgres}',1100),(6,'{design,branding}',800);

INSERT INTO projects(client_id,title,description,budget,deadline) VALUES
 (2,'Inventory dashboard','Web dashboard for warehouse stock levels',50000,current_date+45),
 (3,'Brand identity kit','Logo, colours and social templates',32000,current_date+30),
 (2,'Mobile app API','REST API for a delivery app',70000,current_date+60),
 (3,'Reporting pipeline','Nightly ETL into PostgreSQL',40000,current_date+40);
INSERT INTO proposals(project_id,freelancer_id,quote,est_days,cover_letter) VALUES
 (1,4,45000,20,'I have built three stock dashboards in React.'),
 (1,5,52000,25,'Full stack with PostgreSQL views.'),
 (2,6,30000,15,'Brand work is my speciality.'),
 (4,5,38000,18,'ETL and SQL tuning are my daily work.');

SELECT accept_proposal(1,2);   -- contract 1: Acme + Riya
SELECT accept_proposal(3,3);   -- contract 2: Nova + Sara
INSERT INTO milestones(contract_id,title,due_date,amount) VALUES
 (1,'Wireframes',current_date+7,10000),(1,'Frontend build',current_date+20,20000),(1,'Backend integration',current_date+35,15000),
 (2,'Logo concepts',current_date+5,12000),(2,'Final kit',current_date-2,18000);
SELECT submit_milestone(1,4); SELECT approve_milestone(1,2); SELECT pay_invoice(1,2,'UPI');
SELECT submit_milestone(2,4); SELECT approve_milestone(2,2);
SELECT submit_milestone(4,6);
INSERT INTO disputes(contract_id,raised_by,reason) VALUES (1,2,'Frontend build is missing the export-to-CSV feature agreed in the brief.');
