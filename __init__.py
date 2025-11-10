from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from pymongo import MongoClient

db = SQLAlchemy()

def create_app():
    app = Flask(__name__)

    # PostgreSQL
    app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://usuario:senha@localhost:5432/seu_banco'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    db.init_app(app)

    # MongoDB
    mongo_client = MongoClient("mongodb://localhost:27017/")
    mongo_db = mongo_client["logs_db"]  # nome do banco de logs
    app.mongo_logs = mongo_db.logs_auditoria  # coleção

    return app
