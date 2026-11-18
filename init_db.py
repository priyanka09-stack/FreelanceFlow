import os, psycopg2                                  #creates the database -- if missing , then loads schema.sql and seed.sql
from psycopg2 import sql
from dotenv import load_dotenv
load_dotenv()
HOST = dict(host=os.getenv("PGHOST","localhost"), port=os.getenv("PGPORT","5432"),
            user=os.getenv("PGUSER","postgres"), password=os.getenv("PGPASSWORD","postgres"))
NAME = os.getenv("PGDATABASE","freelanceflow")

c = psycopg2.connect(dbname="postgres", **HOST); c.autocommit = True
cur = c.cursor()
cur.execute("SELECT 1 FROM pg_database WHERE datname=%s", (NAME,))
if not cur.fetchone():
    cur.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(NAME)))
c.close()

c = psycopg2.connect(dbname=NAME, **HOST); cur = c.cursor()
for f in ("db/schema.sql", "db/advanced.sql", "db/seed.sql"):
    cur.execute(open(f, encoding="utf-8").read()); print("loaded", f)
c.commit(); c.close(); print("Database ready.")
