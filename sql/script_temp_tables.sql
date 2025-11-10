-- Loader ROBUSTO p/ FUNCIONARIO (sem travar a transação)
ROLLBACK;

BEGIN;
SET CONSTRAINTS ALL DEFERRED;

-- Tenta SEM id na frente; se falhar, tenta COM id na frente
DO $blk$
DECLARE
  ok boolean := false;
BEGIN
  BEGIN
    -- 1) Layout A: sem id na 1ª coluna
    EXECUTE $_a$
      CREATE TEMP TABLE funcionario_stage (
        cpf                 text,
        nome_completo       text,
        data_nascimento     text,
        sexo                text,
        email_institucional text,
        matricula           text,
        data_admissao       text,
        status_funcionario  text
      ) ON COMMIT DROP
    $_a$;

    EXECUTE $_a$
      COPY funcionario_stage (cpf, nome_completo, data_nascimento, sexo,
                              email_institucional, matricula, data_admissao, status_funcionario)
      FROM '/var/lib/postgresql/data/import/funcionario.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $_a$;

    ok := true;

  EXCEPTION WHEN OTHERS THEN
    -- 2) Layout B: com id na 1ª coluna
    BEGIN
      EXECUTE 'DROP TABLE IF EXISTS funcionario_stage';

      EXECUTE $_b$
        CREATE TEMP TABLE funcionario_stage (
          id_csv              text,
          cpf                 text,
          nome_completo       text,
          data_nascimento     text,
          sexo                text,
          email_institucional text,
          matricula           text,
          data_admissao       text,
          status_funcionario  text
        ) ON COMMIT DROP
      $_b$;

      EXECUTE $_b$
        COPY funcionario_stage (id_csv, cpf, nome_completo, data_nascimento, sexo,
                                email_institucional, matricula, data_admissao, status_funcionario)
        FROM '/var/lib/postgresql/data/import/funcionario.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
      $_b$;

      ok := true;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Não foi possível carregar funcionario.csv com nenhum dos dois layouts (A/B). Verifique o cabeçalho e o delimitador.';
    END;
  END;
END
$blk$;

-- Normaliza e insere (aceita datas YYYY-MM-DD ou DD/MM/YYYY)
WITH norm AS (
  SELECT
    regexp_replace(trim(cpf), '\D','','g') AS cpf11,
    trim(nome_completo) AS nome,
    CASE
      WHEN data_nascimento ~ '^\d{4}-\d{2}-\d{2}$' THEN to_date(data_nascimento, 'YYYY-MM-DD')
      WHEN data_nascimento ~ '^\d{2}/\d{2}/\d{4}$' THEN to_date(data_nascimento, 'DD/MM/YYYY')
      ELSE NULL
    END AS dt_nasc,
    CASE
      WHEN data_admissao ~ '^\d{4}-\d{2}-\d{2}$' THEN to_date(data_admissao, 'YYYY-MM-DD')
      WHEN data_admissao ~ '^\d{2}/\d{2}/\d{4}$' THEN to_date(data_admissao, 'DD/MM/YYYY')
      ELSE NULL
    END AS dt_adm,
    CASE WHEN sexo IS NULL THEN NULL ELSE upper(trim(sexo)) END AS sexo_norm,
    CASE WHEN email_institucional IS NULL THEN NULL ELSE lower(trim(email_institucional)) END AS email_norm,
    trim(matricula) AS matricula_norm,
    CASE WHEN status_funcionario IS NULL THEN NULL ELSE lower(trim(status_funcionario)) END AS status_norm
  FROM funcionario_stage
)
INSERT INTO funcionario
  (cpf, nome_completo, data_nascimento, sexo,
   email_institucional, matricula, data_admissao, status_funcionario)
SELECT
  n.cpf11, n.nome,
  n.dt_nasc,
  CASE WHEN n.sexo_norm IN ('M','F','O') THEN n.sexo_norm ELSE NULL END,
  n.email_norm, n.matricula_norm, n.dt_adm, n.status_norm
FROM norm n
WHERE n.cpf11 ~ '^\d{11}$' AND n.nome <> ''
ON CONFLICT (cpf) DO UPDATE
SET nome_completo       = EXCLUDED.nome_completo,
    data_nascimento     = EXCLUDED.data_nascimento,
    sexo                = EXCLUDED.sexo,
    email_institucional = EXCLUDED.email_institucional,
    matricula           = EXCLUDED.matricula,
    data_admissao       = COALESCE(EXCLUDED.data_admissao, funcionario.data_admissao),
    status_funcionario  = EXCLUDED.status_funcionario;

COMMIT;

-- AUTH USER
BEGIN;

DO $blk$
BEGIN
  -- tenta 3 colunas
  BEGIN
    EXECUTE $_a$
      CREATE TEMP TABLE uf_stage (
        id_csv text, sigla text, nome text
      ) ON COMMIT DROP
    $_a$;
    EXECUTE $_a$
      COPY uf_stage (id_csv, sigla, nome)
      FROM '/var/lib/postgresql/data/import/uf.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $_a$;
  EXCEPTION WHEN OTHERS THEN
    -- fallback 2 colunas
    EXECUTE 'DROP TABLE IF EXISTS uf_stage';
    EXECUTE $_b$
      CREATE TEMP TABLE uf_stage (
        id_csv text, sigla text
      ) ON COMMIT DROP
    $_b$;
    EXECUTE $_b$
      COPY uf_stage (id_csv, sigla)
      FROM '/var/lib/postgresql/data/import/uf.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $_b$;
  END;
END
$blk$;

INSERT INTO uf (sigla, nome)
SELECT UPPER(TRIM(sigla)) AS sigla,
       COALESCE(NULLIF(TRIM(nome),''), UPPER(TRIM(sigla))) AS nome  -- se não veio nome, usa a sigla só pra cumprir NOT NULL
FROM uf_stage
WHERE TRIM(COALESCE(sigla,'')) <> ''
ON CONFLICT (sigla) DO UPDATE SET nome = EXCLUDED.nome;

COMMIT;

-- MUNICIPIO
BEGIN;

DROP TABLE IF EXISTS municipio_stage;
CREATE TEMP TABLE municipio_stage (
  id_csv   text,
  cod_ibge text,
  nome     text,
  id_uf    int
) ON COMMIT DROP;

COPY municipio_stage (id_csv, cod_ibge, nome, id_uf)
FROM '/var/lib/postgresql/data/import/municipio.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

INSERT INTO municipio (cod_ibge, nome, id_uf)
SELECT regexp_replace(TRIM(cod_ibge), '\D','','g') AS cod_ibge7,
       TRIM(nome),
       id_uf
FROM municipio_stage
WHERE TRIM(nome) <> ''
  AND regexp_replace(TRIM(cod_ibge), '\D','','g') ~ '^[0-9]{7}$'
  AND id_uf IS NOT NULL
  AND EXISTS (SELECT 1 FROM uf u WHERE u.id_uf = municipio_stage.id_uf)  -- garante FK
ON CONFLICT (cod_ibge) DO UPDATE
SET nome = EXCLUDED.nome, id_uf = EXCLUDED.id_uf;

COMMIT;

-- CEP
BEGIN;

-- Stage com colunas para os dois formatos
DROP TABLE IF EXISTS cep_stage;
CREATE TEMP TABLE cep_stage (
  id_csv         text,
  cep            text,
  id_municipio   int,
  nome_municipio text,
  sigla_uf       text
) ON COMMIT DROP;

DO $do$
BEGIN
  BEGIN
    -- formato 1: id,cep,id_municipio
    EXECUTE $sql$
      COPY cep_stage (id_csv, cep, id_municipio)
      FROM '/var/lib/postgresql/data/import/cep.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $sql$;
  EXCEPTION WHEN OTHERS THEN
    -- formato 2: id,cep,nome_municipio,sigla_uf
    EXECUTE 'TRUNCATE cep_stage';
    EXECUTE $sql$
      COPY cep_stage (id_csv, cep, nome_municipio, sigla_uf)
      FROM '/var/lib/postgresql/data/import/cep.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $sql$;
  END;
END
$do$;

WITH norm AS (
  SELECT
    regexp_replace(cep,'\D','','g') AS cep8,
    id_municipio,
    TRIM(nome_municipio) AS nm,
    UPPER(TRIM(sigla_uf)) AS uf
  FROM cep_stage
),
resolvido AS (
  SELECT
    n.cep8,
    COALESCE(
      n.id_municipio,
      (SELECT m.id_municipio
         FROM municipio m
         JOIN uf u ON u.id_uf = m.id_uf
        WHERE LOWER(TRIM(m.nome)) = LOWER(n.nm) AND u.sigla = n.uf
        LIMIT 1)
    ) AS id_municipio
  FROM norm n
)
INSERT INTO cep (cep, id_municipio)
SELECT cep8, id_municipio
FROM resolvido
WHERE cep8 ~ '^[0-9]{8}$' AND id_municipio IS NOT NULL
ON CONFLICT (cep) DO NOTHING;

COMMIT;

--TIPO_TELEFONE

BEGIN;

DROP TABLE IF EXISTS tipo_telefone_stage;
CREATE TEMP TABLE tipo_telefone_stage (id_csv text, descricao text) ON COMMIT DROP;

DO $do$
BEGIN
  BEGIN
    EXECUTE $sql$
      COPY tipo_telefone_stage (id_csv, descricao)
      FROM '/var/lib/postgresql/data/import/tipo_telefone.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $sql$;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'TRUNCATE tipo_telefone_stage';
    EXECUTE $sql$
      COPY tipo_telefone_stage (descricao)
      FROM '/var/lib/postgresql/data/import/tipo_telefone.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $sql$;
  END;
END
$do$;

INSERT INTO tipo_telefone (descricao)
SELECT DISTINCT INITCAP(LOWER(TRIM(descricao)))
FROM tipo_telefone_stage
WHERE TRIM(COALESCE(descricao,'')) <> ''
ON CONFLICT (descricao) DO NOTHING;

COMMIT;


-- TIPO_ENDERECO

BEGIN;

DROP TABLE IF EXISTS tipo_endereco_stage;
CREATE TEMP TABLE tipo_endereco_stage (id_csv text, descricao text) ON COMMIT DROP;

DO $do$
BEGIN
  BEGIN
    EXECUTE $sql$
      COPY tipo_endereco_stage (id_csv, descricao)
      FROM '/var/lib/postgresql/data/import/tipo_endereco.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $sql$;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'TRUNCATE tipo_endereco_stage';
    EXECUTE $sql$
      COPY tipo_endereco_stage (descricao)
      FROM '/var/lib/postgresql/data/import/tipo_endereco.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $sql$;
  END;
END
$do$;

INSERT INTO tipo_endereco (descricao)
SELECT DISTINCT INITCAP(LOWER(TRIM(descricao)))
FROM tipo_endereco_stage
WHERE TRIM(COALESCE(descricao,'')) <> ''
ON CONFLICT (descricao) DO NOTHING;

COMMIT;

-- AUTH_USER: habilita pgcrypto (para crypt/gen_salt), carrega CSV em formatos comuns
CREATE EXTENSION IF NOT EXISTS pgcrypto;

BEGIN;

-- stage “superconjunto” para caber em vários layouts
DROP TABLE IF EXISTS auth_user_stage;
CREATE TEMP TABLE auth_user_stage (
  id_csv          text,
  cpf_funcionario text,
  email_login     text,
  password_hash   text,
  mfa_secret      text,
  last_login      timestamptz,
  id_funcionario  int
) ON COMMIT DROP;

DO $do$
BEGIN
  BEGIN
    -- F1) id,email,password_hash,mfa,last_login,id_funcionario
    EXECUTE $sql$
      COPY auth_user_stage (id_csv, email_login, password_hash, mfa_secret, last_login, id_funcionario)
      FROM '/var/lib/postgresql/data/import/auth_user.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $sql$;
  EXCEPTION WHEN OTHERS THEN
    BEGIN
      -- F2) email,password_hash,mfa,last_login,id_funcionario
      EXECUTE 'TRUNCATE auth_user_stage';
      EXECUTE $sql$
        COPY auth_user_stage (email_login, password_hash, mfa_secret, last_login, id_funcionario)
        FROM '/var/lib/postgresql/data/import/auth_user.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
      $sql$;
    EXCEPTION WHEN OTHERS THEN
      BEGIN
        -- F3) cpf_funcionario,email,last_login  (seu caso)
        EXECUTE 'TRUNCATE auth_user_stage';
        EXECUTE $sql$
          COPY auth_user_stage (cpf_funcionario, email_login, last_login)
          FROM '/var/lib/postgresql/data/import/auth_user.csv'
          WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
        $sql$;
      EXCEPTION WHEN OTHERS THEN
        -- F4) id,cpf_funcionario,email,last_login
        EXECUTE 'TRUNCATE auth_user_stage';
        EXECUTE $sql$
          COPY auth_user_stage (id_csv, cpf_funcionario, email_login, last_login)
          FROM '/var/lib/postgresql/data/import/auth_user.csv'
          WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
        $sql$;
      END;
    END;
  END;
END
$do$;

-- Resolve id_funcionario via CPF quando não veio; gera hash se não veio
WITH norm AS (
  SELECT
    lower(trim(email_login)) AS email_norm,
    -- se não vier hash no CSV, gera um com bcrypt
    COALESCE(NULLIF(password_hash,''), crypt('Temp@123', gen_salt('bf'))) AS pwd_norm,
    NULLIF(mfa_secret,'') AS mfa_norm,
    last_login,
    COALESCE(
      id_funcionario,
      (SELECT f.id_funcionario
         FROM funcionario f
        WHERE f.cpf = regexp_replace(trim(auth_user_stage.cpf_funcionario), '\D','','g')
        LIMIT 1)
    ) AS id_func_resolvido
  FROM auth_user_stage
)
INSERT INTO auth_user (email_login, password_hash, mfa_secret, last_login, id_funcionario)
SELECT
  email_norm, pwd_norm, mfa_norm, last_login, id_func_resolvido
FROM norm
WHERE email_norm IS NOT NULL AND email_norm <> '' AND id_func_resolvido IS NOT NULL
ON CONFLICT (email_login) DO UPDATE
SET id_funcionario = EXCLUDED.id_funcionario,
    -- se o novo hash vier vazio, mantém o antigo
    password_hash   = COALESCE(NULLIF(EXCLUDED.password_hash,''), auth_user.password_hash),
    last_login      = COALESCE(EXCLUDED.last_login, auth_user.last_login);

COMMIT;

-- sincroniza a sequência
SELECT setval(pg_get_serial_sequence('auth_user','id_auth_user'),
              COALESCE((SELECT MAX(id_auth_user) FROM auth_user), 0), true);

-- TELEFONE
BEGIN;

DROP TABLE IF EXISTS telefone_stage;
CREATE TEMP TABLE telefone_stage (
  -- Formato A
  id_csv           text,
  numero_e164      text,
  is_principal     boolean,
  id_funcionario   int,
  id_tipo_telefone int,
  -- Formato B
  cpf_funcionario  text,
  telefone_raw     text,
  tipo_telefone_tx text
) ON COMMIT DROP;

DO $do$
BEGIN
  BEGIN
    -- Formato A
    EXECUTE $sql$
      COPY telefone_stage (id_csv, numero_e164, is_principal, id_funcionario, id_tipo_telefone)
      FROM '/var/lib/postgresql/data/import/telefone.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $sql$;
  EXCEPTION WHEN OTHERS THEN
    -- Formato B
    EXECUTE 'TRUNCATE telefone_stage';
    EXECUTE $sql$
      COPY telefone_stage (cpf_funcionario, telefone_raw, tipo_telefone_tx)
      FROM '/var/lib/postgresql/data/import/telefone.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $sql$;
  END;
END
$do$;

-- Inserção para Formato A (direto)
INSERT INTO telefone (numero_e164, is_principal, id_funcionario, id_tipo_telefone)
SELECT TRIM(numero_e164), COALESCE(is_principal,false), id_funcionario, id_tipo_telefone
FROM telefone_stage
WHERE numero_e164 IS NOT NULL AND TRIM(numero_e164) <> ''
  AND id_funcionario IS NOT NULL AND id_tipo_telefone IS NOT NULL
ON CONFLICT DO NOTHING;

-- Inserção para Formato B (mapeando CPF e tipo_telefone)
WITH norm AS (
  SELECT
    f.id_funcionario,
    '+55' || regexp_replace(TRIM(t.telefone_raw), '\D','','g') AS e164,
    INITCAP(LOWER(TRIM(t.tipo_telefone_tx))) AS tipo_norm
  FROM telefone_stage t
  JOIN funcionario f ON f.cpf = regexp_replace(TRIM(t.cpf_funcionario), '\D','','g')
  WHERE t.telefone_raw IS NOT NULL
),
com_tipo AS (
  SELECT
    n.id_funcionario, n.e164, tt.id_tipo_telefone,
    ROW_NUMBER() OVER (PARTITION BY n.id_funcionario ORDER BY n.id_funcionario) = 1 AS is_principal_flag
  FROM norm n
  JOIN tipo_telefone tt ON LOWER(tt.descricao) = LOWER(n.tipo_norm)
)
INSERT INTO telefone (numero_e164, is_principal, id_funcionario, id_tipo_telefone)
SELECT e164, is_principal_flag, id_funcionario, id_tipo_telefone
FROM com_tipo
WHERE e164 ~ '^\+55[0-9]{10,13}$'
ON CONFLICT DO NOTHING;

COMMIT;

-- ENDERECO
BEGIN;

DROP TABLE IF EXISTS endereco_stage;
CREATE TEMP TABLE endereco_stage (
  -- Formato A
  id_csv           text,
  logradouro       text,
  numero           text,
  bairro           text,
  complemento      text,
  is_principal     boolean,
  valid_from       date,
  valid_to         date,
  id_funcionario   int,
  id_cep           int,
  id_tipo_endereco int,
  -- Formato B
  cpf_funcionario  text,
  cep_tx           text,
  tipo_endereco_tx text
) ON COMMIT DROP;

DO $do$
BEGIN
  BEGIN
    -- Formato A
    EXECUTE $sql$
      COPY endereco_stage (id_csv, logradouro, numero, bairro, complemento, is_principal,
                           valid_from, valid_to, id_funcionario, id_cep, id_tipo_endereco)
      FROM '/var/lib/postgresql/data/import/endereco.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $sql$;
  EXCEPTION WHEN OTHERS THEN
    -- Formato B
    EXECUTE 'TRUNCATE endereco_stage';
    EXECUTE $sql$
      COPY endereco_stage (cpf_funcionario, cep_tx, logradouro, numero, complemento, bairro, tipo_endereco_tx, is_principal)
      FROM '/var/lib/postgresql/data/import/endereco.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $sql$;
  END;
END
$do$;

-- ===== Inserção para Formato A (sem ON CONFLICT; usando NOT EXISTS) =====
INSERT INTO endereco (
  logradouro, numero, bairro, complemento, is_principal,
  valid_from, valid_to, id_funcionario, id_cep, id_tipo_endereco
)
SELECT
  TRIM(logradouro) AS logradouro,
  TRIM(numero)     AS numero,
  TRIM(bairro)     AS bairro,
  NULLIF(TRIM(complemento),'') AS complemento,
  COALESCE(is_principal,false),
  valid_from, valid_to,
  id_funcionario, id_cep, id_tipo_endereco
FROM endereco_stage es
WHERE es.id_funcionario IS NOT NULL
  AND es.id_cep         IS NOT NULL
  AND es.id_tipo_endereco IS NOT NULL
  AND TRIM(COALESCE(es.logradouro,'')) <> ''
  AND TRIM(COALESCE(es.numero,''))     <> ''
  AND TRIM(COALESCE(es.bairro,''))     <> ''
  AND NOT EXISTS (
        SELECT 1
        FROM endereco e
        WHERE e.id_funcionario   = es.id_funcionario
          AND e.id_cep           = es.id_cep
          AND e.id_tipo_endereco = es.id_tipo_endereco
          AND e.logradouro       = TRIM(es.logradouro)
          AND e.numero           = TRIM(es.numero)
          AND e.bairro           = TRIM(es.bairro)
  );

-- ===== Inserção para Formato B (mapeando CPF/CEP/Tipo; sem ON CONFLICT) =====
WITH res AS (
  SELECT
    f.id_funcionario,
    c.id_cep,
    TRIM(e.logradouro) AS logradouro,
    TRIM(e.numero)     AS numero,
    NULLIF(TRIM(e.complemento),'') AS complemento,
    TRIM(e.bairro)     AS bairro,
    te.id_tipo_endereco,
    CASE WHEN COALESCE(e.is_principal::text,'') ILIKE ANY(ARRAY['true','t','1','yes','y'])
         THEN TRUE ELSE FALSE END AS is_principal
  FROM endereco_stage e
  JOIN funcionario f ON f.cpf = regexp_replace(TRIM(e.cpf_funcionario), '\D','','g')
  JOIN cep         c ON c.cep = regexp_replace(TRIM(e.cep_tx), '\D','','g')
  JOIN tipo_endereco te
    ON LOWER(TRIM(te.descricao)) = LOWER(TRIM(e.tipo_endereco_tx))
)
INSERT INTO endereco (
  logradouro, numero, bairro, complemento, is_principal,
  id_funcionario, id_cep, id_tipo_endereco
)
SELECT
  r.logradouro, r.numero, r.bairro, r.complemento, r.is_principal,
  r.id_funcionario, r.id_cep, r.id_tipo_endereco
FROM res r
WHERE r.logradouro <> '' AND r.numero <> '' AND r.bairro <> ''
  AND NOT EXISTS (
        SELECT 1
        FROM endereco e
        WHERE e.id_funcionario   = r.id_funcionario
          AND e.id_cep           = r.id_cep
          AND e.id_tipo_endereco = r.id_tipo_endereco
          AND e.logradouro       = r.logradouro
          AND e.numero           = r.numero
          AND e.bairro           = r.bairro
  );

COMMIT;


-- AQUI ESTÁ BAIRRO
BEGIN;

-- recria o stage aceitando opcionalmente a 1ª coluna "id_*"
DROP TABLE IF EXISTS bairro_stage;
CREATE TEMP TABLE bairro_stage (
  id_csv        text,   -- opcional; se o CSV não tiver, o loader faz fallback
  nome          text,
  id_municipio  int
) ON COMMIT DROP;

DO $do$
BEGIN
  BEGIN
    -- Tenta: id_bairro,nome,id_municipio
    EXECUTE $sql$
      COPY bairro_stage (id_csv, nome, id_municipio)
      FROM '/var/lib/postgresql/data/import/bairro.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $sql$;
  EXCEPTION WHEN OTHERS THEN
    -- Fallback: nome,id_municipio
    EXECUTE 'TRUNCATE bairro_stage';
    EXECUTE $sql$
      COPY bairro_stage (nome, id_municipio)
      FROM '/var/lib/postgresql/data/import/bairro.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $sql$;
  END;
END
$do$;

INSERT INTO bairro (nome, id_municipio)
SELECT DISTINCT TRIM(nome), id_municipio
FROM bairro_stage s
WHERE TRIM(COALESCE(nome,'')) <> ''
  AND id_municipio IS NOT NULL
  AND EXISTS (SELECT 1 FROM municipio m WHERE m.id_municipio = s.id_municipio)
ON CONFLICT (nome, id_municipio) DO NOTHING;

COMMIT;

-- checagem
SELECT COUNT(*) AS total_bairros FROM bairro;


-- AQUI AS INFOS DE CEP_MUNICIPIO
BEGIN;

-- stage tolerante a formatos diferentes
DROP TABLE IF EXISTS cep_municipio_stage;
CREATE TEMP TABLE cep_municipio_stage (
  id_csv        text,
  id_municipio  int,
  id_cep        int,
  cep_txt       text   -- quando vier o CEP em texto
) ON COMMIT DROP;

DO $do$
BEGIN
  BEGIN
    -- Formato A: id, id_municipio, id_cep
    EXECUTE $sql$
      COPY cep_municipio_stage (id_csv, id_municipio, id_cep)
      FROM '/var/lib/postgresql/data/import/cep_municipio.csv'
      WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
    $sql$;
  EXCEPTION WHEN OTHERS THEN
    BEGIN
      -- Formato B: cep_txt, id_municipio
      EXECUTE 'TRUNCATE cep_municipio_stage';
      EXECUTE $sql$
        COPY cep_municipio_stage (cep_txt, id_municipio)
        FROM '/var/lib/postgresql/data/import/cep_municipio.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
      $sql$;
    EXCEPTION WHEN OTHERS THEN
      -- Formato C: id_municipio, cep_txt
      EXECUTE 'TRUNCATE cep_municipio_stage';
      EXECUTE $sql$
        COPY cep_municipio_stage (id_municipio, cep_txt)
        FROM '/var/lib/postgresql/data/import/cep_municipio.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8')
      $sql$;
    END;
  END;
END
$do$;

-- normaliza e resolve o id_cep quando veio só o texto do CEP
WITH norm AS (
  SELECT
    cms.id_municipio,
    COALESCE(
      cms.id_cep,
      (
        SELECT c.id_cep
        FROM cep c
        WHERE c.cep = regexp_replace(cms.cep_txt, '\D', '', 'g')
        LIMIT 1
      )
    ) AS id_cep_resolvido
  FROM cep_municipio_stage cms
)
-- insere só pares válidos e que ainda não existem
INSERT INTO cep_municipio (id_municipio, id_cep)
SELECT DISTINCT n.id_municipio, n.id_cep_resolvido
FROM norm n
WHERE n.id_municipio IS NOT NULL
  AND n.id_cep_resolvido IS NOT NULL
  AND EXISTS (SELECT 1 FROM municipio m WHERE m.id_municipio = n.id_municipio)
  AND EXISTS (SELECT 1 FROM cep c WHERE c.id_cep = n.id_cep_resolvido)
  AND NOT EXISTS (
        SELECT 1
        FROM cep_municipio cm
        WHERE cm.id_municipio = n.id_municipio
          AND cm.id_cep       = n.id_cep_resolvido
  );

COMMIT;

-- checagem rápida
SELECT COUNT(*) AS total_cep_municipio FROM cep_municipio;

-- AQUI AS INFOS DE CEP_LOGRADOURO
BEGIN;

-- Stage com o layout do CSV
DROP TABLE IF EXISTS cep_logradouro_stage;
CREATE TEMP TABLE cep_logradouro_stage (
  id_csv           int,
  id_cep           int,
  id_municipio     int,
  id_tipo_endereco int,
  id_bairro        int,
  logradouro       text,
  numero_inicial   int,
  numero_final     int,
  lado             text
) ON COMMIT DROP;

COPY cep_logradouro_stage
  (id_csv, id_cep, id_municipio, id_tipo_endereco, id_bairro,
   logradouro, numero_inicial, numero_final, lado)
FROM '/var/lib/postgresql/data/import/cep_logradouro.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

WITH idmap AS (
  SELECT
    (SELECT id_tipo_endereco FROM tipo_endereco WHERE descricao ILIKE 'Comercial'      LIMIT 1) AS id_comercial,
    (SELECT id_tipo_endereco FROM tipo_endereco WHERE descricao ILIKE 'Cobra%'         LIMIT 1) AS id_cobranca,
    (SELECT id_tipo_endereco FROM tipo_endereco WHERE descricao ILIKE 'Residenc%'      LIMIT 1) AS id_residencial,
    (SELECT id_tipo_endereco FROM tipo_endereco WHERE descricao ILIKE 'Correspond%'    LIMIT 1) AS id_correspond
),
resolvido AS (
  SELECT
    s.id_cep,
    s.id_municipio,
    COALESCE(
      (SELECT te.id_tipo_endereco FROM tipo_endereco te
        WHERE te.id_tipo_endereco = s.id_tipo_endereco),
      CASE s.id_tipo_endereco
        WHEN 1 THEN (SELECT id_comercial   FROM idmap)
        WHEN 2 THEN (SELECT id_cobranca    FROM idmap)
        WHEN 3 THEN (SELECT id_residencial FROM idmap)
        WHEN 4 THEN (SELECT id_correspond  FROM idmap)
        ELSE NULL
      END
    ) AS id_tipo_endereco_ok,
    s.id_bairro,
    trim(s.logradouro) AS logradouro,
    s.numero_inicial,
    s.numero_final,
    CASE
      WHEN upper(coalesce(s.lado,'')) IN ('P','I','N') THEN upper(s.lado) ELSE 'N'
    END AS lado_ok
  FROM cep_logradouro_stage s
)
INSERT INTO cep_logradouro
  (id_cep, id_municipio, id_tipo_endereco, id_bairro,
   logradouro, numero_inicial, numero_final, lado)
SELECT
  r.id_cep, r.id_municipio, r.id_tipo_endereco_ok, r.id_bairro,
  r.logradouro, r.numero_inicial, r.numero_final, r.lado_ok
FROM resolvido r
WHERE r.id_cep IS NOT NULL
  AND r.id_municipio IS NOT NULL
  AND r.id_tipo_endereco_ok IS NOT NULL
  AND r.id_bairro IS NOT NULL
  AND r.logradouro <> ''
  AND r.numero_inicial IS NOT NULL
  AND r.numero_final  IS NOT NULL
  AND NOT EXISTS (
        SELECT 1
        FROM cep_logradouro x
        WHERE x.id_cep           = r.id_cep
          AND x.id_municipio     = r.id_municipio
          AND x.id_tipo_endereco = r.id_tipo_endereco_ok
          AND x.id_bairro        = r.id_bairro
          AND x.logradouro       = r.logradouro
          AND x.numero_inicial   = r.numero_inicial
          AND x.numero_final     = r.numero_final
          AND x.lado             = r.lado_ok
  );

COMMIT;

-- Checagem rápida (não usa a temp)
SELECT COUNT(*) AS qtd_cep_logradouro FROM cep_logradouro;
