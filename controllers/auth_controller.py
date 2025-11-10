from flask import Blueprint, render_template, request, redirect, url_for, session, flash, current_app

bp_auth = Blueprint("auth", __name__)

@bp_auth.get("/login")
def login_page():
    return render_template("login.html", title="Login")

@bp_auth.post("/login")
def login_post():
    
    user_ok = current_app.config.get("APP_USER", "admin")
    pass_ok = current_app.config.get("APP_PASS", "1234")

    username = request.form.get("username", "").strip()
    password = request.form.get("password", "")

    if username == user_ok and password == pass_ok:
        session["user_id"] = 1
        session["user_name"] = username
        flash(f"Bem-vindo, {username}!", "success")
        return redirect(url_for("main.app_menu"))
    else:
        flash("Usuário ou senha incorretos.", "error")
        return redirect(url_for("auth.login_page"))

@bp_auth.get("/logout")
def logout():
    session.clear()
    flash("Sessão encerrada.", "info")
    return redirect(url_for("auth.login_page"))
