from flask import Blueprint, render_template, abort, session, redirect, url_for, Response
from dao.db import query
from dao.logger import log_event
from bson import json_util

bp = Blueprint("main", __name__)

@bp.get("/")
def home():
    log_event("abrir_home")
    return render_template("home.html", title="IFRO_REQUEST")

@bp.get("/app")
def app_menu():

    if "user_id" not in session:
        return redirect(url_for("auth.login_page"))

    log_event("abrir_menu")
    cols, rows = query("""
        SELECT viewname
        FROM pg_views
        WHERE schemaname = 'public' AND viewname LIKE 'vw_%'
        ORDER BY viewname;
    """)
    views = [r["viewname"] for r in rows]
    return render_template("menu.html", title="IFRO_REQUEST", views=views)

@bp.get("/view/<name>")
def view_dynamic(name: str):

    if "user_id" not in session:
        return redirect(url_for("auth.login_page"))

    log_event("abrir_view", {"view": name})
    cols, rows = query(f'SELECT * FROM "{name}"')
    if not cols:
        abort(404, description=f"View {name} não encontrada")
    return render_template("view_generic.html", title=f"View {name}", viewname=name, cols=cols, rows=rows)

@bp.get("/logs")
def ver_logs():
    from dao.logger import logs
    docs = list(logs.find().sort("timestamp", -1).limit(20))
    return Response(json_util.dumps(docs, ensure_ascii=False), mimetype="application/json")
