-- ==========================================
-- VIEWS - ATIVIDADES PRÁTICAS (IFRO_REQUEST)
-- ==========================================

/* 1) nome completo e e-mail institucional de todos os funcionários ativos */
DROP VIEW IF EXISTS vw_funcionarios_ativos_email;
CREATE VIEW vw_funcionarios_ativos_email AS
SELECT
  f.id_funcionario,
  f.nome_completo,
  f.email_institucional
FROM public.funcionario f
WHERE LOWER(f.status_funcionario) = 'ativo'
ORDER BY f.id_funcionario;

/* 2) funcionários e seus respectivos logins (AuthUser) */
DROP VIEW IF EXISTS vw_funcionarios_auth;
CREATE VIEW vw_funcionarios_auth AS
SELECT
  f.id_funcionario,
  f.nome_completo,
  a.email_login,
  a.last_login
FROM public.funcionario f
LEFT JOIN public.auth_user a
       ON a.id_funcionario = f.id_funcionario
ORDER BY f.id_funcionario;

/* 3) endereços completos (logradouro, número, bairro, CEP, município e UF) de cada funcionário
      → usa endereço PRINCIPAL para 1x1 por funcionário */
DROP VIEW IF EXISTS vw_enderecos_completos_funcionario;
CREATE VIEW vw_enderecos_completos_funcionario AS
SELECT
  f.id_funcionario,
  f.nome_completo,
  e.logradouro,
  e.numero,
  e.bairro,
  c.cep,
  m.nome  AS municipio,
  u.sigla AS uf
FROM public.funcionario f
LEFT JOIN public.endereco e
       ON e.id_funcionario = f.id_funcionario AND e.is_principal = TRUE
LEFT JOIN public.cep c
       ON c.id_cep = e.id_cep
LEFT JOIN public.municipio m
       ON m.id_municipio = c.id_municipio
LEFT JOIN public.uf u
       ON u.id_uf = m.id_uf
ORDER BY f.id_funcionario;

/* 4) funcionários de uma UF específica (ex.: "RO")
      → como VIEW não recebe parâmetro, criamos fixo para RO */
DROP VIEW IF EXISTS vw_funcionarios_uf_ro;
CREATE VIEW vw_funcionarios_uf_ro AS
SELECT
  f.id_funcionario,
  f.nome_completo,
  u.sigla AS uf
FROM public.funcionario f
LEFT JOIN public.endereco e
       ON e.id_funcionario = f.id_funcionario AND e.is_principal = TRUE
LEFT JOIN public.cep c
       ON c.id_cep = e.id_cep
LEFT JOIN public.municipio m
       ON m.id_municipio = c.id_municipio
LEFT JOIN public.uf u
       ON u.id_uf = m.id_uf
WHERE u.sigla = 'RO'
ORDER BY f.id_funcionario;

/* 5) funcionários e seus telefones PRINCIPAIS */
DROP VIEW IF EXISTS vw_funcionarios_telefones_principais;
CREATE VIEW vw_funcionarios_telefones_principais AS
SELECT
  f.id_funcionario,
  f.nome_completo,
  t.numero_e164 AS telefone_principal,
  tp.descricao  AS tipo_telefone
FROM public.funcionario f
LEFT JOIN public.telefone t
       ON t.id_funcionario = f.id_funcionario AND t.is_principal = TRUE
LEFT JOIN public.tipo_telefone tp
       ON tp.id_tipo_telefone = t.id_tipo_telefone
ORDER BY f.id_funcionario;

/* 6) funcionários admitidos após 01/01/2020 */
DROP VIEW IF EXISTS vw_funcionarios_admitidos_pos_2020;
CREATE VIEW vw_funcionarios_admitidos_pos_2020 AS
SELECT
  f.id_funcionario,
  f.nome_completo,
  f.data_admissao
FROM public.funcionario f
WHERE f.data_admissao > DATE '2020-01-01'
ORDER BY f.data_admissao, f.id_funcionario;

/* 7) quantos funcionários existem por bairro / setor
      → conta por BAIRRO considerando endereço PRINCIPAL */
DROP VIEW IF EXISTS vw_qtde_funcionarios_por_bairro;
CREATE VIEW vw_qtde_funcionarios_por_bairro AS
SELECT
  e.bairro,
  COUNT(DISTINCT f.id_funcionario) AS qtde_funcionarios
FROM public.funcionario f
JOIN public.endereco e
  ON e.id_funcionario = f.id_funcionario AND e.is_principal = TRUE
GROUP BY e.bairro
ORDER BY qtde_funcionarios DESC, e.bairro;

/* 8) quais bairros / setor NÃO possuem funcionários cadastrados
      Observação: como não existe tabela de "bairros" de referência no seu modelo,
      vamos interpretar como "bairros sem ENDEREÇO PRINCIPAL" (aparecem só como não-principal).
      Resultado: bairros presentes na tabela endereco, mas sem nenhum registro principal. */
DROP VIEW IF EXISTS vw_bairros_sem_endereco_principal;
CREATE VIEW vw_bairros_sem_endereco_principal AS
WITH todos_bairros AS (
  SELECT DISTINCT bairro FROM public.endereco WHERE bairro IS NOT NULL
),
bairros_principais AS (
  SELECT DISTINCT bairro FROM public.endereco WHERE is_principal = TRUE AND bairro IS NOT NULL
)
SELECT tb.bairro
FROM todos_bairros tb
LEFT JOIN bairros_principais bp ON bp.bairro = tb.bairro
WHERE bp.bairro IS NULL
ORDER BY tb.bairro;

/* 9) funcionários INATIVOS e seus últimos logins */
DROP VIEW IF EXISTS vw_funcionarios_inativos_ultimos_logins;
CREATE VIEW vw_funcionarios_inativos_ultimos_logins AS
SELECT
  f.id_funcionario,
  f.nome_completo,
  f.status_funcionario,
  a.last_login
FROM public.funcionario f
LEFT JOIN public.auth_user a
       ON a.id_funcionario = f.id_funcionario
WHERE LOWER(f.status_funcionario) = 'inativo'
ORDER BY a.last_login NULLS LAST, f.id_funcionario;

/* 10) tipos de telefone mais usados pelos funcionários */
DROP VIEW IF EXISTS vw_tipos_telefone_mais_usados;
CREATE VIEW vw_tipos_telefone_mais_usados AS
SELECT
  tp.descricao AS tipo_telefone,
  COUNT(*)     AS total
FROM public.telefone t
JOIN public.tipo_telefone tp
  ON tp.id_tipo_telefone = t.id_tipo_telefone
GROUP BY tp.descricao
ORDER BY total DESC, tp.descricao;

/* 11) juntar Funcionario, Endereco (principal) e AuthUser, mostrando login junto ao endereço */
DROP VIEW IF EXISTS vw_func_endereco_auth;
CREATE VIEW vw_func_endereco_auth AS
SELECT
  f.id_funcionario,
  f.nome_completo,
  a.email_login,
  e.logradouro,
  e.numero,
  e.bairro,
  c.cep,
  m.nome  AS municipio,
  u.sigla AS uf
FROM public.funcionario f
LEFT JOIN public.auth_user a
       ON a.id_funcionario = f.id_funcionario
LEFT JOIN public.endereco e
       ON e.id_funcionario = f.id_funcionario AND e.is_principal = TRUE
LEFT JOIN public.cep c
       ON c.id_cep = e.id_cep
LEFT JOIN public.municipio m
       ON m.id_municipio = c.id_municipio
LEFT JOIN public.uf u
       ON u.id_uf = m.id_uf
ORDER BY f.id_funcionario;

/* 12) funcionários SEM endereço principal cadastrado */
DROP VIEW IF EXISTS vw_funcionarios_sem_endereco_principal;
CREATE VIEW vw_funcionarios_sem_endereco_principal AS
SELECT
  f.id_funcionario,
  f.nome_completo
FROM public.funcionario f
LEFT JOIN public.endereco e
       ON e.id_funcionario = f.id_funcionario AND e.is_principal = TRUE
WHERE e.id_endereco IS NULL
ORDER BY f.id_funcionario;

/* 13) todos os CPFs duplicados (auditoria de integridade)
       → se sua tabela tem UNIQUE(cpf), isso normalmente retornará vazio */
DROP VIEW IF EXISTS vw_cpfs_duplicados;
CREATE VIEW vw_cpfs_duplicados AS
SELECT
  cpf,
  COUNT(*) AS total
FROM public.funcionario
GROUP BY cpf
HAVING COUNT(*) > 1
ORDER BY total DESC, cpf;

/* 14) funcionários por status (ativo/inativo) AGRUPADOS */
DROP VIEW IF EXISTS vw_funcionarios_por_status;
CREATE VIEW vw_funcionarios_por_status AS
SELECT
  LOWER(COALESCE(status_funcionario,'desconhecido')) AS status,
  COUNT(*) AS total
FROM public.funcionario
GROUP BY LOWER(COALESCE(status_funcionario,'desconhecido'))
ORDER BY total DESC, status;

/* 15) unir Funcionario, CEP, Municipio e UF (distribuição geográfica)
       → 1 linha por funcionário (usa endereço principal) */
DROP VIEW IF EXISTS vw_distribuicao_geografica;
CREATE VIEW vw_distribuicao_geografica AS
SELECT
  f.id_funcionario,
  f.nome_completo,
  c.cep,
  m.nome  AS municipio,
  u.sigla AS uf
FROM public.funcionario f
LEFT JOIN public.endereco e
       ON e.id_funcionario = f.id_funcionario AND e.is_principal = TRUE
LEFT JOIN public.cep c
       ON c.id_cep = e.id_cep
LEFT JOIN public.municipio m
       ON m.id_municipio = c.id_municipio
LEFT JOIN public.uf u
       ON u.id_uf = m.id_uf
ORDER BY u.sigla NULLS LAST, m.nome NULLS LAST, f.id_funcionario;