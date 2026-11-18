import os, json, decimal, datetime
from functools import wraps
from contextlib import contextmanager
import psycopg2, psycopg2.extras
from pymongo import MongoClient
from flask import Flask, request, session, Response
from dotenv import load_dotenv
load_dotenv()


PG = dict(dbname=os.getenv("PGDATABASE", "freelanceflow"), user=os.getenv("PGUSER", "postgres"),
          password=os.getenv("PGPASSWORD", "postgres"), host=os.getenv("PGHOST", "localhost"),
          port=os.getenv("PGPORT", "5432"))
mongo = MongoClient(os.getenv("MONGO_URI", "mongodb://localhost:27017"), serverSelectionTimeoutMS=1500)
audit_col = mongo["freelanceflow_audit"]["audit_logs"]

DIST = os.path.join(os.path.dirname(__file__), "frontend", "dist")
app = Flask(__name__, static_folder=DIST, static_url_path="")
app.secret_key = os.getenv("SECRET_KEY", "change-me-in-production")



def _ser(o):
    return float(o) if isinstance(o, decimal.Decimal) else str(o)

def out(data, code=200):
    return Response(json.dumps(data, default=_ser), code, mimetype="application/json")

def err(msg, code=400):
    return out({"error": msg}, code)

@contextmanager
def tx(role=None):
    """One DB transaction. SET LOCAL ROLE makes PostgreSQL enforce RBAC for this request."""
    conn = psycopg2.connect(**PG)
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        if role:
            cur.execute(f"SET LOCAL ROLE app_{role}")   # role comes from the session, never from user input
        yield cur
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

def q(sql, params=None, one=False, **extra):
    p = dict(uid=session.get("uid"), role=session.get("role"), **(params or {}), **extra)
    with tx(session.get("role")) as c:
        c.execute(sql, p)
        if c.description is None:
            return None
        rows = c.fetchall()
        return (rows[0] if rows else None) if one else rows

def audit(action, entity, entity_id=None, details=None):
    """Write-only audit trail in MongoDB. Never breaks the request if Mongo is down."""
    try:
        audit_col.insert_one({"ts": datetime.datetime.utcnow(), "actor_id": session.get("uid"),
                              "actor": session.get("name"), "role": session.get("role"), "action": action,
                              "entity": entity, "entity_id": entity_id, "details": details or {},
                              "ip": request.remote_addr})
    except Exception as e:
        app.logger.warning("audit skipped: %s", e)

def need(*roles):
    def deco(f):
        @wraps(f)
        def w(*a, **k):
            if "uid" not in session:
                return err("Please sign in first", 401)
            if roles and session["role"] not in roles:
                return err("Your role is not allowed to do this", 403)
            return f(*a, **k)
        return w
    return deco

@app.errorhandler(psycopg2.Error)
def db_error(e):
    msg = (e.diag.message_primary if e.diag and e.diag.message_primary else str(e))
    if e.pgcode == "23505": msg = "That already exists (duplicate entry)"
    elif e.pgcode == "23514": msg = "A value is outside the allowed range"
    elif e.pgcode == "42501": msg = "The database denied this action for your role"
    return err(msg, 403 if e.pgcode == "42501" else 400)

def body():
    return request.get_json(silent=True) or {}



@app.get("/")                                                                        #auth
def index():
    if not os.path.exists(os.path.join(DIST, "index.html")):
        return "React build not found. Run: cd frontend && npm install && npm run build  (or use npm run dev)", 404
    return app.send_static_file("index.html")

@app.errorhandler(404)
def spa_fallback(e):
    if request.path.startswith("/api/"):
        return err("Not found", 404)
    return index()   # let React Router handle /contracts/3 etc. on refresh

@app.post("/api/login")
def login():
    b = body()
    with tx() as c:   # login runs as the owner so it can verify the bcrypt hash
        c.execute("SELECT user_id, name, email, role FROM users WHERE email=%s AND password_hash = crypt(%s, password_hash)",
                  (b.get("email", "").strip(), b.get("password", "")))
        u = c.fetchone()
    if not u:
        return err("Wrong email or password", 401)
    session.update(uid=u["user_id"], name=u["name"], role=u["role"])
    audit("LOGIN", "user", u["user_id"])
    return out(u)

@app.post("/api/logout")
def logout():
    audit("LOGOUT", "user", session.get("uid"))
    session.clear()
    return out({"ok": True})

@app.get("/api/me")
def me():
    return out({"user_id": session["uid"], "name": session["name"], "role": session["role"]}) if "uid" in session else err("Not signed in", 401)



@app.get("/api/projects")                                    #projects and proposal
@need()
def projects():
    return out(q("""SELECT p.*, u.name AS client_name,
                           (SELECT COUNT(*) FROM proposals x WHERE x.project_id = p.project_id) AS proposals,
                           EXISTS (SELECT 1 FROM proposals x WHERE x.project_id = p.project_id AND x.freelancer_id = %(uid)s) AS applied
                    FROM projects p JOIN users u ON u.user_id = p.client_id
                    WHERE %(role)s = 'admin' OR p.client_id = %(uid)s OR (%(role)s = 'freelancer' AND p.status = 'open')
                    ORDER BY p.project_id DESC"""))

@app.post("/api/projects")
@need("client")
def create_project():
    b = body()
    r = q("""INSERT INTO projects(client_id,title,description,budget,deadline)
             VALUES (%(uid)s,%(title)s,%(description)s,%(budget)s,NULLIF(%(deadline)s,'')::date) RETURNING project_id""",
          title=b.get("title"), description=b.get("description"), budget=b.get("budget"), deadline=b.get("deadline", ""), one=True)
    audit("PROJECT_CREATED", "project", r["project_id"], {"title": b.get("title"), "budget": b.get("budget")})
    return out(r, 201)

@app.put("/api/projects/<int:pid>")
@need("client")
def edit_project(pid):
    """Optimistic locking: succeeds only if the client still holds the latest version."""
    b = body()
    r = q("""UPDATE projects SET title=%(t)s, description=%(d)s, budget=%(b)s, deadline=NULLIF(%(dl)s,'')::date
             WHERE project_id=%(pid)s AND client_id=%(uid)s AND version=%(v)s AND status='open'
             RETURNING project_id, version""",
          t=b.get("title"), d=b.get("description"), b=b.get("budget"), dl=b.get("deadline", ""), pid=pid, v=b.get("version"), one=True)
    if not r:
        return err("This project changed (or is no longer open). Reload and try again.", 409)
    audit("PROJECT_EDITED", "project", pid, {"new_version": r["version"]})
    return out(r)

@app.get("/api/proposals")
@need()
def proposals():
    return out(q("""SELECT pr.*, p.title, p.client_id, u.name AS freelancer_name
                    FROM proposals pr JOIN projects p ON p.project_id = pr.project_id
                    JOIN users u ON u.user_id = pr.freelancer_id
                    WHERE %(role)s = 'admin' OR p.client_id = %(uid)s OR pr.freelancer_id = %(uid)s
                    ORDER BY pr.proposal_id DESC"""))

@app.post("/api/proposals")
@need("freelancer")
def submit_proposal():
    b = body()
    r = q("""INSERT INTO proposals(project_id,freelancer_id,quote,est_days,cover_letter)
             SELECT project_id, %(uid)s, %(quote)s, %(days)s, %(letter)s FROM projects
             WHERE project_id = %(pid)s AND status = 'open' RETURNING proposal_id""",
          pid=b.get("project_id"), quote=b.get("quote"), days=b.get("est_days"), letter=b.get("cover_letter"), one=True)
    if not r:
        return err("This project is not open for proposals")
    audit("PROPOSAL_SUBMITTED", "proposal", r["proposal_id"], {"project_id": b.get("project_id"), "quote": b.get("quote")})
    return out(r, 201)

@app.post("/api/proposals/<int:pid>/accept")
@need("client")
def accept(pid):
    r = q("SELECT accept_proposal(%(pid)s, %(uid)s) AS contract_id", pid=pid, one=True)
    audit("PROPOSAL_ACCEPTED", "proposal", pid, {"contract_id": r["contract_id"]})
    return out(r)



SCOPE = "(%(role)s = 'admin' OR c.client_id = %(uid)s OR c.freelancer_id = %(uid)s)"            #contracts, milestones & invoices 

@app.get("/api/contracts")
@need()
def contracts():
    return out(q(f"SELECT c.* FROM v_contract_summary c WHERE {SCOPE} ORDER BY c.contract_id DESC"))

@app.get("/api/contracts/<int:cid>/milestones")
@need()
def milestones(cid):
    return out(q(f"""SELECT m.*, i.invoice_id, i.invoice_no, i.status AS invoice_status, i.commission, i.net_amount
                     FROM milestones m JOIN contracts c ON c.contract_id = m.contract_id
                     LEFT JOIN invoices i ON i.milestone_id = m.milestone_id
                     WHERE m.contract_id = %(cid)s AND {SCOPE} ORDER BY m.milestone_id""", cid=cid))

@app.post("/api/milestones")
@need("client")
def add_milestone():
    b = body()
    r = q("""INSERT INTO milestones(contract_id,title,due_date,amount)
             SELECT contract_id, %(t)s, NULLIF(%(d)s,'')::date, %(a)s FROM contracts
             WHERE contract_id = %(cid)s AND client_id = %(uid)s RETURNING milestone_id""",
          cid=b.get("contract_id"), t=b.get("title"), d=b.get("due_date", ""), a=b.get("amount"), one=True)
    if not r:
        return err("Contract not found", 404)
    audit("MILESTONE_ADDED", "milestone", r["milestone_id"], b)
    return out(r, 201)

@app.post("/api/milestones/<int:mid>/<action>")
@need("client", "freelancer")
def milestone_action(mid, action):
    if action == "submit" and session["role"] == "freelancer":
        q("SELECT submit_milestone(%(mid)s, %(uid)s)", mid=mid)
        audit("MILESTONE_SUBMITTED", "milestone", mid); return out({"ok": True})
    if action == "approve" and session["role"] == "client":
        r = q("SELECT approve_milestone(%(mid)s, %(uid)s) AS invoice_id", mid=mid, one=True)
        audit("MILESTONE_APPROVED", "milestone", mid, {"invoice_id": r["invoice_id"]}); return out(r)
    return err("Action not allowed for your role", 403)

@app.get("/api/invoices")
@need()
def invoices():
    return out(q(f"""SELECT i.*, m.title AS milestone, p.title AS project, c.contract_id,
                            (SELECT method FROM payments y WHERE y.invoice_id = i.invoice_id ORDER BY paid_at DESC LIMIT 1) AS method
                     FROM invoices i JOIN milestones m ON m.milestone_id = i.milestone_id
                     JOIN contracts c ON c.contract_id = m.contract_id JOIN projects p ON p.project_id = c.project_id
                     WHERE {SCOPE} ORDER BY i.invoice_id DESC"""))

@app.post("/api/invoices/<int:iid>/pay")
@need("client")
def pay(iid):
    method = body().get("method", "UPI")
    r = q("SELECT pay_invoice(%(iid)s, %(uid)s, %(m)s) AS payment_id", iid=iid, m=method, one=True)
    audit("INVOICE_PAID", "invoice", iid, {"payment_id": r["payment_id"], "method": method})
    return out(r)



@app.get("/api/disputes")                 #disputes
@need()
def disputes():
    return out(q(f"""SELECT d.*, p.title AS project, u.name AS raised_by_name
                     FROM disputes d JOIN contracts c ON c.contract_id = d.contract_id
                     JOIN projects p ON p.project_id = c.project_id JOIN users u ON u.user_id = d.raised_by
                     WHERE {SCOPE} ORDER BY d.dispute_id DESC"""))

@app.post("/api/disputes")
@need("client", "freelancer")
def raise_dispute():
    b = body()
    r = q(f"""INSERT INTO disputes(contract_id, raised_by, reason)
              SELECT c.contract_id, %(uid)s, %(reason)s FROM contracts c
              WHERE c.contract_id = %(cid)s AND {SCOPE} RETURNING dispute_id""",
          cid=b.get("contract_id"), reason=b.get("reason"), one=True)
    if not r:
        return err("Contract not found", 404)
    audit("DISPUTE_RAISED", "dispute", r["dispute_id"], {"contract_id": b.get("contract_id")})
    return out(r, 201)

@app.post("/api/disputes/<int:did>/resolve")
@need("admin")
def resolve(did):
    q("UPDATE disputes SET status='resolved', resolution=%(res)s WHERE dispute_id=%(did)s", res=body().get("resolution"), did=did)
    audit("DISPUTE_RESOLVED", "dispute", did, {"resolution": body().get("resolution")})
    return out({"ok": True})




@app.get("/api/contracts/<int:cid>/history")          #history, notifications, analytics & procedure 
@need()
def contract_history(cid):
    return out(q(f"""SELECT h.entity, h.entity_id, h.old_status, h.new_status, h.changed_at, m.title AS milestone
                     FROM status_history h
                     LEFT JOIN milestones m ON h.entity = 'milestone' AND m.milestone_id = h.entity_id
                     JOIN contracts c ON c.contract_id = %(cid)s
                     WHERE {SCOPE} AND ((h.entity = 'milestone' AND m.contract_id = c.contract_id)
                                     OR (h.entity = 'contract' AND h.entity_id = c.contract_id))
                     ORDER BY h.history_id DESC""", cid=cid))

@app.get("/api/notifications")
@need()
def notifications():
    return out(q("""SELECT * FROM notifications WHERE %(role)s = 'admin' OR user_id = %(uid)s ORDER BY note_id DESC LIMIT 50"""))

@app.post("/api/admin/check-overdue")
@need("admin")
def check_overdue():
    r = q("CALL flag_overdue_milestones(NULL)", one=True)   # stored procedure with a cursor
    audit("OVERDUE_CHECK", "milestone", None, {"new_notifications": r["flagged"]})
    return out(r)

@app.get("/api/analytics")
@need()
def analytics():
    """Window functions and CTEs, scoped to what the current user may see."""
    res = {}
    res["monthly"] = q(f"""
        WITH paid AS (
          SELECT date_trunc('month', y.paid_at)::date AS month, y.amount
          FROM payments y JOIN invoices i ON i.invoice_id = y.invoice_id
          JOIN milestones m ON m.milestone_id = i.milestone_id JOIN contracts c ON c.contract_id = m.contract_id
          WHERE {SCOPE})
        SELECT month, SUM(amount) AS total, SUM(SUM(amount)) OVER (ORDER BY month) AS running_total
        FROM paid GROUP BY month ORDER BY month""")
    res["status_mix"] = q("""SELECT status, COUNT(*) AS n,
                                    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
                             FROM projects p
                             WHERE %(role)s = 'admin' OR p.client_id = %(uid)s OR %(role)s = 'freelancer'
                             GROUP BY status ORDER BY n DESC""")
    if session["role"] == "admin":
        res["ranking"] = q("""SELECT name, net_earned, completed,
                                     RANK() OVER (ORDER BY net_earned DESC) AS rnk
                              FROM v_freelancer_earnings""")
        res["client_share"] = q("""SELECT name, total_paid,
                                          ROUND(100.0 * total_paid / NULLIF(SUM(total_paid) OVER (), 0), 1) AS pct
                                   FROM v_client_spending ORDER BY total_paid DESC""")
    return out(res)


@app.get("/api/reports")     #reports & audit 
@need()
def reports():
    role = session["role"]
    res = {"contracts": q(f"SELECT c.* FROM v_contract_summary c WHERE {SCOPE}")}
    if role == "admin":
        res.update(revenue=q("SELECT * FROM v_platform_revenue", one=True),
                   earnings=q("SELECT * FROM v_freelancer_earnings ORDER BY net_earned DESC"),
                   spending=q("SELECT * FROM v_client_spending ORDER BY total_paid DESC"))
    elif role == "client":
        res["spending"] = q("SELECT * FROM v_client_spending WHERE client_id = %(uid)s")
    else:
        res["earnings"] = q("SELECT * FROM v_freelancer_earnings WHERE freelancer_id = %(uid)s")
    return out(res)

@app.get("/api/audit")
@need("admin")
def audit_log():
    try:
        rows = list(audit_col.find({}, {"_id": 0}).sort("ts", -1).limit(100))
    except Exception:
        return err("MongoDB is not reachable. Start it with: docker compose up -d", 503)
    return out(rows)


if __name__ == "__main__":
    app.run(debug=True, port=5000)
