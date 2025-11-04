-- ===============================
-- Criação das tabelas
-- ===============================

CREATE TABLE uf (
    id_uf SERIAL PRIMARY KEY,
    sigla CHAR(2) NOT NULL UNIQUE,
    nome VARCHAR(100) NOT NULL
);

CREATE TABLE municipio (
    id_municipio SERIAL PRIMARY KEY,
    cod_ibge CHAR(7) NOT NULL UNIQUE,
    nome VARCHAR(150) NOT NULL,
    id_uf INT NOT NULL REFERENCES uf(id_uf)
);

CREATE TABLE cep (
    id_cep SERIAL PRIMARY KEY,
    cep CHAR(8) NOT NULL UNIQUE CHECK (cep ~ '^[0-9]{8}$'),
    id_municipio INT NOT NULL REFERENCES municipio(id_municipio)
);

CREATE TABLE funcionario (
    id_funcionario SERIAL PRIMARY KEY,
    cpf CHAR(11) NOT NULL UNIQUE CHECK (cpf ~ '^[0-9]{11}$'),
    nome_completo VARCHAR(200) NOT NULL,
    data_nascimento DATE,
    sexo CHAR(1), -- M, F, O (ou catálogo separado)
    email_institucional VARCHAR(150) UNIQUE,
    matricula VARCHAR(50),
    data_admissao DATE,
    status_funcionario VARCHAR(20) -- ativo, inativo (ou catálogo separado)
);

CREATE TABLE auth_user (
    id_auth_user SERIAL PRIMARY KEY,
    email_login VARCHAR(150) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    mfa_secret VARCHAR(255),
    last_login TIMESTAMP,
    id_funcionario INT NOT NULL UNIQUE REFERENCES funcionario(id_funcionario)
);

CREATE TABLE tipo_telefone (
    id_tipo_telefone SERIAL PRIMARY KEY,
    descricao VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE telefone (
    id_telefone SERIAL PRIMARY KEY,
    numero_e164 VARCHAR(20) NOT NULL CHECK (numero_e164 ~ '^\+55[0-9]{10,13}$'),
    is_principal BOOLEAN NOT NULL DEFAULT FALSE,
    id_funcionario INT NOT NULL REFERENCES funcionario(id_funcionario),
    id_tipo_telefone INT NOT NULL REFERENCES tipo_telefone(id_tipo_telefone)
);

CREATE TABLE tipo_endereco (
    id_tipo_endereco SERIAL PRIMARY KEY,
    descricao VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE endereco (
    id_endereco SERIAL PRIMARY KEY,
    logradouro VARCHAR(200) NOT NULL,
    numero VARCHAR(20) NOT NULL,
    bairro VARCHAR(100) NOT NULL,
    complemento VARCHAR(150),
    is_principal BOOLEAN NOT NULL DEFAULT FALSE,
    valid_from DATE,
    valid_to DATE,
    id_funcionario INT NOT NULL REFERENCES funcionario(id_funcionario),
    id_cep INT NOT NULL REFERENCES cep(id_cep),
    id_tipo_endereco INT NOT NULL REFERENCES tipo_endereco(id_tipo_endereco),
    CONSTRAINT unico_endereco_principal UNIQUE (id_funcionario, is_principal)
        DEFERRABLE INITIALLY DEFERRED
);

-- ===============================
-- Observações:
-- 1. SERIAL cria automaticamente sequência e autoincremento
-- 2. CHECKs usados para validar formato de CPF, CEP, telefone
-- 3. Restrição única em endereco: apenas um "principal" por funcionário
-- ===============================

/* =========================================================
   NOVAS TABELAS (conforme material do prof.)
   3) cep_municipio
   4) cep_logradouro
   5) bairro
   ========================================================= */

-- 5) BAIRRO  ------------------------------------------------
-- Catálogo de bairros por município
CREATE TABLE IF NOT EXISTS bairro (
    id_bairro     SERIAL PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL,
    id_municipio  INT NOT NULL
        REFERENCES municipio(id_municipio) ON DELETE RESTRICT,
    CONSTRAINT uq_bairro UNIQUE (id_municipio, nome)
);

-- índices úteis
CREATE INDEX IF NOT EXISTS ix_bairro_nome_lower     ON bairro (LOWER(nome));
CREATE INDEX IF NOT EXISTS ix_bairro_id_municipio   ON bairro (id_municipio);


-- 3) CEP_MUNICIPIO  ----------------------------------------
-- Associação do CEP "mínimo e único" de cada município
CREATE TABLE IF NOT EXISTS cep_municipio (
    id_cep_municipio SERIAL PRIMARY KEY,
    id_municipio     INT NOT NULL
        REFERENCES municipio(id_municipio) ON DELETE RESTRICT,
    id_cep           INT NOT NULL UNIQUE
        REFERENCES cep(id_cep) ON DELETE CASCADE,
    -- garante 1 CEP principal por município
    CONSTRAINT uq_cep_municipio_unico_municipio UNIQUE (id_municipio)
);

-- índices úteis
CREATE INDEX IF NOT EXISTS ix_cep_municipio_id_municipio ON cep_municipio(id_municipio);


-- 4) CEP_LOGRADOURO  ---------------------------------------
-- Detalha logradouros com CEPs individualizados dentro do município
-- Colunas opcionais para faixa numérica e lado da via (P/I/N)
CREATE TABLE IF NOT EXISTS cep_logradouro (
    id_cep_logradouro SERIAL PRIMARY KEY,
    id_cep            INT NOT NULL
        REFERENCES cep(id_cep) ON DELETE CASCADE,
    id_municipio      INT NOT NULL
        REFERENCES municipio(id_municipio) ON DELETE RESTRICT,
    id_tipo_endereco  INT NOT NULL
        REFERENCES tipo_endereco(id_tipo_endereco) ON DELETE RESTRICT,
    id_bairro         INT NULL
        REFERENCES bairro(id_bairro) ON DELETE SET NULL,
    logradouro        VARCHAR(200) NOT NULL,
    numero_inicial    INT NULL,
    numero_final      INT NULL,
    lado              CHAR(1) NULL CHECK (lado IN ('P','I','N'))
);

-- unicidade por CEP + descrição (considerando faixa/lado se usado)
-- (índice único por expressão para evitar duplicidades com nulos)
CREATE UNIQUE INDEX IF NOT EXISTS uq_cep_logradouro_desc
    ON cep_logradouro (
        id_cep,
        LOWER(logradouro),
        COALESCE(numero_inicial, 0),
        COALESCE(numero_final,   0),
        COALESCE(lado, 'N')
    );

-- índices de apoio
CREATE INDEX IF NOT EXISTS ix_cep_logradouro_id_cep        ON cep_logradouro(id_cep);
CREATE INDEX IF NOT EXISTS ix_cep_logradouro_id_municipio  ON cep_logradouro(id_municipio);
CREATE INDEX IF NOT EXISTS ix_cep_logradouro_logradouro     ON cep_logradouro(LOWER(logradouro));
