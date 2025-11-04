BEGIN;
SET CONSTRAINTS ALL DEFERRED;

COPY uf (id_uf, sigla, nome)
FROM '/var/lib/postgresql/data/import/uf.csv' CSV HEADER;

COPY municipio (id_municipio, cod_ibge, nome, id_uf)
FROM '/var/lib/postgresql/data/import/municipio.csv' CSV HEADER;

COPY cep (id_cep, cep, id_municipio)
FROM '/var/lib/postgresql/data/import/cep.csv' CSV HEADER;

COPY tipo_telefone (id_tipo_telefone, descricao)
FROM '/var/lib/postgresql/data/import/tipo_telefone.csv' CSV HEADER;

COPY tipo_endereco (id_tipo_endereco, descricao)
FROM '/var/lib/postgresql/data/import/tipo_endereco.csv' CSV HEADER;

COPY funcionario (id_funcionario, cpf, nome_completo, data_nascimento, sexo, email_institucional, matricula, data_admissao, status_funcionario)
FROM '/var/lib/postgresql/data/import/funcionario.csv' CSV HEADER;

COPY auth_user (id_auth_user, email_login, password_hash, mfa_secret, last_login, id_funcionario)
FROM '/var/lib/postgresql/data/import/auth_user.csv' CSV HEADER;

COPY telefone (id_telefone, numero_e164, is_principal, id_funcionario, id_tipo_telefone)
FROM '/var/lib/postgresql/data/import/telefone.csv' CSV HEADER;

COPY endereco (id_endereco, logradouro, numero, bairro, complemento, is_principal, valid_from, valid_to, id_funcionario, id_cep, id_tipo_endereco)
FROM '/var/lib/postgresql/data/import/endereco.csv' CSV HEADER;

COMMIT;