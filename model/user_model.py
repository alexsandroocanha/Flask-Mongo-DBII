from dataclasses import dataclass
from datetime import datetime

@dataclass
class UserView:
    id_funcionario: int
    nome_completo: str
    email_login: str
    last_login: datetime | None
