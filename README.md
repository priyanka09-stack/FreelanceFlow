### Freelance Project & Payment Management System

A full stack freelance management platform designed to simplify project tracking, milestone management, invoicing, payments and audit monitoring.

Built using **PostgreSQL, MongoDB, Flask, and React (Vite)**, this project demonstrates practical DBMS concepts through a real-world application.


---

##  Overview

FreelanceFlow is a freelance project and payment management system that connects clients, freelancers and administrators through a centralized platform.

It provides a structured workflow for managing freelance contracts, project milestones, invoice approvals, payments, disputes, notifications and reporting.

The system uses:

- **PostgreSQL** for structured relational data and advanced DBMS operations.
- **MongoDB** for storing audit trail records.
- **Flask** for backend APIs and application logic.
- **React (Vite)** for the interactive user interface.

The project combines core DBMS concepts with a practical full-stack implementation.

##  Key Features

###  Role-Based Access
- Separate access for Admin, Client, and Freelancer roles.
- Role aware application operations.
- Database role enforcement through PostgreSQL.

###  Project & Contract Management
- Manage freelance projects and contracts.
- Organize work through milestones.
- Enforce milestone budget constraints.

###  Invoice & Payment Management
- Freelancer milestone submissions.
- Client invoice approval.
- Payment tracking and commission handling.
- Protection against modification of paid invoices.

###  Notifications & Disputes
- Notification management.
- Overdue milestone monitoring.
- Dispute management for project-related issues.

###  Analytics & Reporting
- Dashboard summaries.
- SQL-based reports and analytics.
- Star schema-based analytical views.

###  Audit Trail
- MongoDB-based audit logging.
- Record important application activities.
- Maintain a separate audit history.

---

##  Technology Stack

| Technology | Purpose |
|---|---|
| PostgreSQL | Main relational database |
| MongoDB | Audit trail storage |
| Python | Backend programming |
| Flask | REST API and application server |
| React | Frontend user interface |
| Vite | Frontend development and build tool |
| SQL | Queries, joins, constraints and analytics |
| PL/pgSQL | Stored procedures, functions and triggers |

---

##  System Architecture

```text
              ┌──────────────────────┐
              │     React (Vite)     │
              │     Frontend UI      │
              └──────────┬───────────┘
                         │ HTTP / API
                         ▼
              ┌──────────────────────┐
              │       Flask          │
              │     Backend API      │
              └──────────┬───────────┘
                         │
              ┌──────────┴───────────┐
              ▼                      ▼
    ┌──────────────────┐   ┌──────────────────┐
    │   PostgreSQL     │   │     MongoDB      │
    │  Core Database   │   │   Audit Trail    │
    │                  │   │                  │
    │ Tables           │   │ Activity Logs    │
    │ Constraints      │   │ Audit Records    │
    │ Functions        │   └──────────────────┘
    │ Procedures       │
    │ Triggers         │
    │ Views            │
    └──────────────────┘
```

**Application flow:** React communicates with Flask through HTTP APIs. Flask interacts with PostgreSQL for core application data and MongoDB for audit records.

---

##  Project Structure

```text
FreelanceFlow/
│
├── db/
│   ├── schema.sql
│   ├── advanced.sql
│   └── seed.sql
│
│
├── frontend/
│   ├── src/
│   │   ├── pages/
│   │   ├── api.js
│   │   ├── ui.jsx
│   │   └── App.jsx
│   ├── dist/
│   ├── package.json
│   └── package-lock.json
│
├── sql/
│   ├── 1_*.sql
│   ├── 2_*.sql
│   ├── 3_*.sql
│   ├── 4_*.sql
│   └── 5_*.sql
│
├── app.py
├── init_db.py
├── requirements.txt
├── .gitignore
└── README.md
```

---

##  Getting Started

Follow these steps to run FreelanceFlow locally.

### 1. Prerequisites

Make sure the following are installed:

- Python 3.12+
- PostgreSQL
- MongoDB
- Node.js and npm (required for frontend development or rebuilding the UI)

Ensure both PostgreSQL and MongoDB services are running.

### 2. Clone the Repository

```bash
git clone https://github.com/YOUR-USERNAME/FreelanceFlow.git
cd FreelanceFlow
```

### 3. Create a Python Virtual Environment

**Windows (CMD):**

```cmd
python -m venv venv
venv\Scripts\activate
```

### 4. Install Python Dependencies

```cmd
pip install -r requirements.txt
```

### 5. Configure Environment Variables

Create a `.env` file in the project root.

Refer to the [Environment Configuration](#-environment-configuration) section below.

### 6. Initialize the Database

```cmd
python init_db.py
```

This initializes the PostgreSQL database by loading:

1. `db/schema.sql`
2. `db/advanced.sql`
3. `db/seed.sql`

It creates the required tables, constraints, functions, triggers, procedures, views, roles, and demo data.

**Important:** The initialization script uses PostgreSQL superuser credentials. Make sure the configured database credentials are correct.

Running this script again resets the demo data. Avoid rerunning it on a database containing data you want to preserve.

### 7. Run the Application

```cmd
python app.py
```

Open the application:

**http://127.0.0.1:5000**

The Flask application serves the already-built React frontend from `frontend/dist`.

---

##  Environment Configuration

Example `.env` configuration:

```env example
PGUSER=postgres
PGPASSWORD=your_postgresql_password
PGHOST=localhost
PGPORT=5432
PGDATABASE=freelanceflow

MONGO_URI=mongodb://localhost:27017

SECRET_KEY=replace_with_a_secure_secret
```

Replace the example values with your own local configuration.


---

##  Frontend Development

To work on the React interface with Vite's hot-reload functionality:

Open a separate terminal:

```cmd
cd frontend
npm install
npm run dev
```

Open:

**http://localhost:5173**

The Vite development server proxies API requests to the Flask backend running on port `5000`.

### Build the Frontend

After making frontend changes:

```cmd
npm run build
```

This regenerates `frontend/dist`, which is served by Flask.

---


##  Database Implementation

FreelanceFlow demonstrates several important DBMS concepts.

### PostgreSQL – Core Database

**1. Relational Schema**
- Structured tables and relationships.
- Primary and foreign key constraints.
- Data integrity constraints.

**2. Triggers**
- Milestone budget validation.
- Status history tracking.
- Paid invoice immutability.
- Optimistic locking.

**3. Functions & Stored Procedures**
- Transactional database functions.
- Stored procedure using a cursor.
- Overdue milestone checks and alert generation.

**4. Views & Analytics**
- Reporting views.
- Star schema-based analytical views.
- SQL-based reporting and aggregation.

**5. Advanced SQL**
- Joins and subqueries.
- Common Table Expressions (CTEs).
- Window functions.
- Transactions and savepoints.
- Isolation levels and locking.
- Indexing and EXPLAIN ANALYZE.

### MongoDB – Audit Trail

MongoDB is used as a separate audit storage system for recording important application activities.

This demonstrates the integration of relational and document-oriented databases within one application.

---


##  Future Enhancements

Potential improvements for future versions:

- PostgreSQL Row-Level Security (RLS) policies.
- JWT-based authentication.
- API pagination and improved filtering.
- Advanced analytics and interactive charts.
- Enhanced audit monitoring.
- Additional reporting capabilities.

---

