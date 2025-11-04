IFRO Request — Flask + PostgreSQL (com Login Padrão)

Aplicação Flask simples para consultar views do PostgreSQL e exibir resultados em páginas HTML.
Inclui tela de login sem banco (usuário/senha fixos via .env), organização por blueprints e estilo básico.

✨ Destaques

Flask 3 + SQLAlchemy (engine) + psycopg3

Login padrão via .env (sem persistência)

Acesso a views do Postgres (public.vw_*)

Estrutura limpa: controllers, dao, templates, static

Pronta para subir no GitHub (com .gitignore)

(Opcional) docker-compose para Postgres + pgAdmin

🗂️ Estrutura de Pastas
.
├── controllers/
│   ├── auth_controller.py        # rotas de login/logout (padrão via .env)
│   └── login_controller.py       # rotas principais (home, menu, view dinâmica, logs)
├── dao/
│   ├── db.py                     # conexão e helper de query (SQLAlchemy engine)
│   └── logger.py                 # (seu logger atual, se houver)
├── model/
│   └── user_model.py             # (opcional)
├── static/
│   └── style.css                 # estilos do site
├── templates/
│   ├── base.html                 # layout base com navbar/flash
│   ├── home.html                 # página inicial
│   ├── login.html                # tela de login
│   ├── menu.html                 # lista de views (vw_*)
│   └── view_generic.html         # tabela genérica para qualquer view
├── app.py
├── config.py
├── requirements.txt
├── .env                          # (NÃO VERSIONAR)
└── README.md

⚙️ Requisitos

Python 3.10+

(Opcional) Docker e Docker Compose

PostgreSQL acessível (local ou container)

🔧 Configuração

Crie e ative uma venv

python -m venv .venv
# Linux/macOS
source .venv/bin/activate
# Windows PowerShell
# .venv\Scripts\Activate.ps1


Instale dependências

pip install -r requirements.txt


Crie o arquivo .env (não será versionado)

# Flask
SECRET_KEY=sua-chave-super-secreta

# Login padrão (sem banco)
APP_USER=admin
APP_PASS=1234

# Postgres
PGUSER=admin
PGPASSWORD=admin123
PGDATABASE=ifro_request
PGHOST=localhost
PGPORT=5432


APP_USER e APP_PASS controlam o login fixo.
SECRET_KEY é usada pela sessão do Flask.

▶️ Executar
python app.py


Acesse: http://localhost:5000/login

Entre com o usuário/senha definidos no .env.
Após logado, acesse /app e navegue pelas views.

🔐 Login Padrão (sem banco)

Credenciais lidas do .env via Config: APP_USER e APP_PASS.

Sessão grava user_id e user_name (cookie de sessão).

Rotas protegidas redirecionam para /login se não houver sessão.

Arquivos envolvidos:

controllers/auth_controller.py

templates/login.html

Proteções em controllers/login_controller.py nas rotas /app e /view/<name>.

🗄️ Banco de Dados

Conexão ao Postgres por SQLAlchemy sem ORM, usando create_engine.

Helper de consulta: dao/db.py → query(sql: str, params: dict | None) -> (cols, rows)

Menu lista as views públicas que começam com vw_:

SELECT viewname
FROM pg_views
WHERE schemaname = 'public' AND viewname LIKE 'vw_%'
ORDER BY viewname;


/view/<name> executa SELECT * FROM "<name>" e exibe em tabela.

Garanta que existam views no schema public com prefixo vw_.

🧪 Rotas

GET / — home

GET /login — formulário de login

POST /login — autenticação (APP_USER/APP_PASS)

GET /logout — encerra a sessão

GET /app — lista de views (protegida)

GET /view/<name> — dados de uma view (protegida)

GET /logs — logs (JSON), se dao.logger estiver disponível

🎨 UI

CSS em static/style.css

base.html com navbar (Entrar/Sair) e flash messages

view_generic.html mostra qualquer conjunto de colunas de forma responsiva