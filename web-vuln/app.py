import json
import os
import sqlite3
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import jwt
from flask import Flask, Response, jsonify, make_response, redirect, render_template, request, url_for
from markupsafe import Markup

APP_DIR = Path(__file__).resolve().parent
DATA_DIR = APP_DIR / "data"
LOG_DIR = APP_DIR / "logs"
FILES_DIR = APP_DIR / "files"
DB_PATH = DATA_DIR / "lab.db"
ACCESS_LOG = LOG_DIR / "access.jsonl"
COLLECTOR_LOG = LOG_DIR / "collector.log"
JWT_SECRET = os.getenv("JWT_SECRET", "ukk-jwt-secret-2026")
FLASK_SECRET = os.getenv("FLASK_SECRET", "ukk-flask-session-2026")

DATA_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)

app = Flask(__name__)
app.secret_key = FLASK_SECRET


def db_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = db_conn()
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL,
            full_name TEXT NOT NULL,
            email TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS comments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            author TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS products (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT NOT NULL
        );
        """
    )
    if conn.execute("SELECT COUNT(*) FROM users").fetchone()[0] == 0:
        conn.executemany(
            "INSERT INTO users(id, username, password, role, full_name, email) VALUES(?,?,?,?,?,?)",
            [
                (1, "admin", "admin123", "admin", "Administrator Lab", "admin@lab.local"),
                (2, "siswa", "siswa123", "user", "Siswa UKK", "siswa@lab.local"),
                (3, "auditor", "audit2026", "auditor", "Auditor Internal", "auditor@lab.local"),
            ],
        )
    if conn.execute("SELECT COUNT(*) FROM products").fetchone()[0] == 0:
        conn.executemany(
            "INSERT INTO products(id, name, description) VALUES(?,?,?)",
            [
                (1, "Router Security Gateway", "MikroTik gateway untuk segmentasi dan firewall."),
                (2, "Ubuntu Docker Host", "Host dua aplikasi simulasi UKK."),
                (3, "Splunk SOC", "Platform analisis log dan korelasi event."),
            ],
        )
    conn.commit()
    conn.close()


init_db()


@app.before_request
def start_timer():
    request._started_at = time.perf_counter()


@app.after_request
def log_request(response):
    event = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "app": "ukk-web-vuln",
        "src_ip": request.headers.get("X-Forwarded-For", request.remote_addr),
        "method": request.method,
        "path": request.path,
        "query": request.query_string.decode("utf-8", "replace"),
        "status": response.status_code,
        "user_agent": request.headers.get("User-Agent", ""),
        "host": request.host,
        "duration_ms": round((time.perf_counter() - getattr(request, "_started_at", time.perf_counter())) * 1000, 2),
    }
    try:
        with ACCESS_LOG.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(event, ensure_ascii=False) + "\n")
    except OSError:
        pass
    # Sengaja tidak menambahkan security header pada Web Lab.
    return response


@app.get("/health")
def health():
    return Response("OK", mimetype="text/plain")


@app.get("/robots.txt")
def robots():
    return Response(
        "User-agent: *\nDisallow: /static/backup/\nDisallow: /admin/collector\nDisallow: /api/admin\n",
        mimetype="text/plain",
    )


@app.get("/")
def index():
    return render_template("index.html")


@app.route("/login", methods=["GET", "POST"])
def login():
    error = None
    if request.method == "POST":
        username = request.form.get("username", "")
        password = request.form.get("password", "")

        # VULNERABILITY LAB: SQL Injection melalui string interpolation.
        query = (
            "SELECT id, username, role, full_name FROM users "
            f"WHERE username = '{username}' AND password = '{password}'"
        )
        conn = db_conn()
        try:
            row = conn.execute(query).fetchone()
        except sqlite3.Error as exc:
            error = f"Database error: {exc}"
            row = None
        finally:
            conn.close()

        if row:
            response = make_response(redirect(url_for("dashboard", user=row["username"], role=row["role"])))
            # VULNERABILITY LAB: cookie sengaja tidak HttpOnly untuk demonstrasi XSS.
            response.set_cookie(
                "lab_session",
                f"user={row['username']}&role={row['role']}",
                httponly=False,
                secure=False,
                samesite="Lax",
            )
            return response
        if error is None:
            error = "Username atau password salah."
    return render_template("login.html", error=error)


@app.get("/dashboard")
def dashboard():
    return render_template(
        "dashboard.html",
        user=request.args.get("user", "guest"),
        role=request.args.get("role", "user"),
    )


@app.get("/search")
def search():
    q = request.args.get("q", "")
    conn = db_conn()
    products = []
    if q:
        products = conn.execute(
            "SELECT id, name, description FROM products WHERE name LIKE ? OR description LIKE ?",
            (f"%{q}%", f"%{q}%"),
        ).fetchall()
    conn.close()
    # VULNERABILITY LAB: input sengaja dirender sebagai Markup tanpa escaping.
    return render_template("search.html", q=Markup(q), products=products)


@app.route("/comments", methods=["GET", "POST"])
def comments():
    conn = db_conn()
    if request.method == "POST":
        author = request.form.get("author", "anonymous")
        content = request.form.get("content", "")
        conn.execute(
            "INSERT INTO comments(author, content, created_at) VALUES(?,?,?)",
            (author, content, datetime.now(timezone.utc).isoformat()),
        )
        conn.commit()
        conn.close()
        return redirect(url_for("comments"))
    rows = conn.execute(
        "SELECT id, author, content, created_at FROM comments ORDER BY id DESC"
    ).fetchall()
    conn.close()
    # VULNERABILITY LAB: stored comment sengaja dianggap aman.
    rendered = [dict(row) | {"content": Markup(row["content"])} for row in rows]
    return render_template("comments.html", comments=rendered)


@app.get("/collector")
def collector():
    data = request.args.get("c", request.args.get("data", ""))
    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "src_ip": request.headers.get("X-Forwarded-For", request.remote_addr),
        "data": data,
        "user_agent": request.headers.get("User-Agent", ""),
    }
    with COLLECTOR_LOG.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")
    return Response(status=204)


@app.get("/admin/collector")
def collector_view():
    entries = []
    if COLLECTOR_LOG.exists():
        for line in COLLECTOR_LOG.read_text(encoding="utf-8", errors="replace").splitlines()[-50:]:
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                entries.append({"raw": line})
    return render_template("collector.html", entries=entries)


@app.post("/api/login")
def api_login():
    payload = request.get_json(silent=True) or {}
    username = payload.get("username", "")
    password = payload.get("password", "")
    conn = db_conn()
    row = conn.execute(
        "SELECT id, username, role FROM users WHERE username=? AND password=?",
        (username, password),
    ).fetchone()
    conn.close()
    if not row:
        return jsonify({"error": "invalid credentials"}), 401
    token = jwt.encode(
        {
            "sub": str(row["id"]),
            "username": row["username"],
            "role": row["role"],
            "exp": datetime.now(timezone.utc) + timedelta(hours=2),
        },
        JWT_SECRET,
        algorithm="HS256",
    )
    return jsonify({"token": token, "storage": "localStorage", "note": "lab only"})


@app.get("/api/admin")
def api_admin():
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return jsonify({"error": "missing bearer token"}), 401
    token = auth.split(" ", 1)[1]
    try:
        claims = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    except jwt.PyJWTError as exc:
        return jsonify({"error": str(exc)}), 401
    if claims.get("role") != "admin":
        return jsonify({"error": "admin role required", "claims": claims}), 403
    return jsonify({"status": "admin access granted", "flag": "UKK{JWT_ROLE_VALIDATED}", "claims": claims})


@app.get("/api/profile/<int:user_id>")
def profile(user_id):
    # VULNERABILITY LAB: IDOR, tanpa autentikasi/otorisasi.
    conn = db_conn()
    row = conn.execute(
        "SELECT id, username, role, full_name, email FROM users WHERE id=?", (user_id,)
    ).fetchone()
    conn.close()
    if not row:
        return jsonify({"error": "not found"}), 404
    return jsonify(dict(row))


@app.get("/download")
def download():
    filename = request.args.get("file", "readme.txt")
    # VULNERABILITY LAB: path traversal karena tidak menggunakan safe_join.
    target = os.path.join(str(FILES_DIR), filename)
    try:
        data = Path(target).read_bytes()
    except OSError as exc:
        return Response(f"File error: {exc}\n", status=404, mimetype="text/plain")
    return Response(data, mimetype="text/plain")


@app.errorhandler(404)
def not_found(error):
    return render_template("404.html", error=error), 404
