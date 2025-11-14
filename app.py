# app.py
from flask import Flask
from controllers.login_controller import bp as main_bp
from controllers.auth_controller import bp_auth
from config import Config

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)
    app.register_blueprint(main_bp)
    app.register_blueprint(bp_auth)
    return app

if __name__ == "__main__":
    app = create_app()
    app.run(debug=True, host="0.0.0.0", port=5000)