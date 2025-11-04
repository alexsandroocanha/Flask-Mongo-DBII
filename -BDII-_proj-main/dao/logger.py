import datetime
from pymongo import MongoClient

# conecta ao Mongo local
client = MongoClient("mongodb://localhost:27017/")
db = client["ifro_request_logs"]   # banco Mongo
logs = db["user_actions"]          # coleção

def log_event(user_action: str, extra: dict | None = None):
    doc = {
        "timestamp": datetime.datetime.utcnow(),
        "action": user_action,
    }
    if extra:
        doc.update(extra)
    logs.insert_one(doc)
    print(f"[LOG] {doc}")
