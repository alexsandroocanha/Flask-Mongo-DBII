from typing import Tuple, List, Dict, Any
from sqlalchemy import create_engine, text
from config import Config

_engine = create_engine(Config.SQLALCHEMY_DATABASE_URL, pool_pre_ping=True)

def query(sql: str, params: dict | None = None) -> Tuple[List[str], List[Dict[str, Any]]]:
    """
    Executa SELECT e retorna (cols, rows) sem pandas.
    cols: lista de nomes de colunas
    rows: lista de dicts (cada linha)
    """
    with _engine.begin() as conn:
        result = conn.execute(text(sql), params or {})
        cols = list(result.keys())
        rows = [dict(row._mapping) for row in result]
        return cols, rows
