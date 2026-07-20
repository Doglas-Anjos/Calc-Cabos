-- =====================================================================
-- Calc-Cabos — schema do banco de APLICAÇÃO (calc_cabos_app)
--
-- Guarda usuários, projetos e os circuitos/cálculos que o usuário monta
-- dentro de um projeto. É um banco separado do catálogo normativo de
-- baixa tensão (calc_cabos_bt, ver database/bt/) — não há FK entre bancos
-- (Postgres não suporta FK cross-database); colunas como
-- circuitos.tipo_circuito_id, circuitos.material_condutor_id etc. são
-- inteiros simples que referenciam IDs do catálogo bt, validados pela
-- aplicação (NestJS), não pelo banco.
--
-- "tipo_carga" (Motor/Resistiva/Iluminação/Outra) vive aqui, não no
-- catálogo bt: o catálogo (docs/adr/0005) mantém finalidade_circuito
-- deliberadamente enxuto e não modela especificidades de motor (torque de
-- partida etc.) — os campos de partida (queda de tensão/FP na partida)
-- só fazem sentido para tipo_carga = Motor.
-- =====================================================================


-- =====================================================================
-- 1. USUÁRIOS / PROJETOS
-- =====================================================================

CREATE TABLE usuarios (
    id          SERIAL PRIMARY KEY,
    nome        VARCHAR(120) NOT NULL,
    email       VARCHAR(160) NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
COMMENT ON TABLE usuarios IS 'Sem autenticação nesta fase (usuário único implícito) — a tabela já existe e projetos.usuario_id já referencia ela para não exigir migração quando login for adicionado.';

CREATE TABLE projetos (
    id          SERIAL PRIMARY KEY,
    usuario_id  INTEGER      NOT NULL REFERENCES usuarios(id),
    nome        VARCHAR(120) NOT NULL,
    descricao   TEXT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (usuario_id, nome)
);


-- =====================================================================
-- 2. LOOKUPS DE APLICAÇÃO
-- =====================================================================

CREATE TABLE tipo_carga (
    id      SERIAL PRIMARY KEY,
    nome    VARCHAR(40) NOT NULL UNIQUE
);
COMMENT ON TABLE tipo_carga IS 'Motor/Resistiva/Iluminação/Outra. Determina se os campos de partida (queda de tensão e FP na partida) do circuito se aplicam — só para Motor.';


-- =====================================================================
-- 3. CIRCUITOS (o "cálculo" dentro de um projeto)
-- =====================================================================

CREATE TABLE circuitos (
    id                              SERIAL         PRIMARY KEY,
    projeto_id                      INTEGER        NOT NULL REFERENCES projetos(id),
    nome                            VARCHAR(120)   NOT NULL,
    tipo_carga_id                   INTEGER        NOT NULL REFERENCES tipo_carga(id),

    -- Referências ao catálogo bt (calc_cabos_bt) — inteiros simples, sem FK
    -- cross-database. Validados pela aplicação antes de calcular/gravar.
    metodo_instalacao_id            INTEGER        NOT NULL,
    tipo_circuito_id                INTEGER        NOT NULL,
    categoria_cabo_id               INTEGER        NOT NULL,
    produto_comercial_id            INTEGER        NOT NULL,
    material_condutor_id            INTEGER        NOT NULL,

    -- Entradas manuais
    temperatura_ambiente_c          SMALLINT       NOT NULL,
    fator_agrupamento_tipo          VARCHAR(10)    NOT NULL CHECK (fator_agrupamento_tipo IN ('ar', 'enterrado')),
    fator_agrupamento_id            INTEGER        NOT NULL,
    comprimento_m                   NUMERIC(10,2)  NOT NULL,
    tensao_nominal_v                NUMERIC(10,2)  NOT NULL,
    corrente_a                      NUMERIC(10,2)  NOT NULL,
    fator_potencia                  NUMERIC(4,3)   NOT NULL,
    corrente_curto_circuito_a       NUMERIC(12,2)  NOT NULL,
    tempo_atuacao_curto_circuito_s  NUMERIC(8,3)   NOT NULL,
    queda_tensao_nominal_max_pct    NUMERIC(5,2)   NOT NULL,

    -- Só aplicáveis/obrigatórios quando tipo_carga = Motor — validado em código
    -- (chegar ao valor de tipo_carga_id exige join com tipo_carga; o CHECK do
    -- banco só garante a consistência entre os 3 campos de partida).
    queda_tensao_partida_max_pct    NUMERIC(5,2),
    fator_potencia_partida          NUMERIC(4,3),
    corrente_partida_a              NUMERIC(10,2),

    -- Condutores em paralelo por fase (NBR 5410 §6.2.5.7) — intervalo que o
    -- motor de cálculo pode testar (N=min, min+1, ..., max) até achar a
    -- menor seção que atenda com o menor N possível. Teto absoluto de 10
    -- fixado em código (apps/api/src/config/constants.ts).
    numero_condutores_paralelos_min SMALLINT       NOT NULL DEFAULT 1,
    numero_condutores_paralelos_max SMALLINT       NOT NULL DEFAULT 10,

    created_at                      TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at                      TIMESTAMPTZ    NOT NULL DEFAULT now(),

    UNIQUE (projeto_id, nome),
    CHECK (
        (queda_tensao_partida_max_pct IS NULL AND fator_potencia_partida IS NULL AND corrente_partida_a IS NULL)
        OR
        (queda_tensao_partida_max_pct IS NOT NULL AND fator_potencia_partida IS NOT NULL AND corrente_partida_a IS NOT NULL)
    ),
    CHECK (numero_condutores_paralelos_min >= 1 AND numero_condutores_paralelos_max >= numero_condutores_paralelos_min AND numero_condutores_paralelos_max <= 10)
);
COMMENT ON TABLE circuitos IS 'Um "cálculo" de dimensionamento de cabo de baixa tensão dentro de um projeto. Nome único por projeto. Campos de partida (queda_tensao_partida_max_pct, fator_potencia_partida, corrente_partida_a) são todos NULL ou todos preenchidos juntos — a aplicação garante que só vêm preenchidos quando tipo_carga_id aponta para "Motor".';
COMMENT ON COLUMN circuitos.metodo_instalacao_id IS 'FK lógica para calc_cabos_bt.metodo_instalacao.id — sem FK de banco (cross-database).';
COMMENT ON COLUMN circuitos.tipo_circuito_id IS 'FK lógica para calc_cabos_bt.tipo_circuito.id (sistema: 2F, 3F, 3F+sh...).';
COMMENT ON COLUMN circuitos.categoria_cabo_id IS 'FK lógica para calc_cabos_bt.categoria_cabo.id ("tipo do cabo": Condutor Isolado/Unipolar/Multipolar).';
COMMENT ON COLUMN circuitos.produto_comercial_id IS 'FK lógica para calc_cabos_bt.produto_comercial.id ("cabo": fabricante + nome comercial).';
COMMENT ON COLUMN circuitos.material_condutor_id IS 'FK lógica para calc_cabos_bt.material_condutor.id (Cobre/Alumínio).';
COMMENT ON COLUMN circuitos.fator_agrupamento_id IS 'FK lógica para calc_cabos_bt.fator_agrupamento_ar.id ou fator_agrupamento_enterrado.id, conforme fator_agrupamento_tipo.';
COMMENT ON COLUMN circuitos.tempo_atuacao_curto_circuito_s IS 'Tempo de atuação da proteção usado em S=√(I²·t)/k — não citado explicitamente pelo usuário na especificação original, adicionado como entrada manual necessária ao cálculo de curto-circuito (fator_k_curto_circuito).';
COMMENT ON COLUMN circuitos.corrente_partida_a IS 'Corrente de partida do motor, usada para calcular a queda de tensão na partida — não citada explicitamente pelo usuário, adicionada como entrada manual necessária ao cálculo (só preenchida quando tipo_carga = Motor).';

CREATE INDEX idx_circuitos_projeto ON circuitos(projeto_id);
CREATE INDEX idx_circuitos_tipo_carga ON circuitos(tipo_carga_id);


-- =====================================================================
-- 4. RESULTADOS DE CÁLCULO (histórico)
-- =====================================================================

CREATE TABLE resultados_calculo (
    id                                  SERIAL         PRIMARY KEY,
    circuito_id                         INTEGER        NOT NULL REFERENCES circuitos(id),
    secao_calculada_mm2                 NUMERIC(8,2),
    corrente_admissivel_corrigida_a     NUMERIC(10,2),
    queda_tensao_calculada_pct          NUMERIC(6,3),
    queda_tensao_partida_calculada_pct  NUMERIC(6,3),
    secao_minima_curto_circuito_mm2     NUMERIC(8,2),
    numero_condutores_paralelos_calculado SMALLINT,
    viavel                              BOOLEAN        NOT NULL,
    memoria_calculo                     JSONB          NOT NULL,
    created_at                          TIMESTAMPTZ    NOT NULL DEFAULT now()
);
COMMENT ON TABLE resultados_calculo IS 'Um registro por execução do DimensionamentoService — histórico completo (não só o resultado vigente). memoria_calculo guarda todos os valores intermediários (capacidades, R/XL, fatores aplicados) para auditoria/transparência do cálculo.';

CREATE INDEX idx_resultados_calculo_circuito ON resultados_calculo(circuito_id);


-- =====================================================================
-- 5. IMPORTAÇÃO EM MASSA (Excel, via fila BullMQ/Redis)
-- =====================================================================

CREATE TABLE import_jobs (
    id                  SERIAL       PRIMARY KEY,
    projeto_id          INTEGER      NOT NULL REFERENCES projetos(id),
    arquivo_nome        VARCHAR(255) NOT NULL,
    status               VARCHAR(20)  NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'done', 'failed')),
    total_linhas         INTEGER      NOT NULL DEFAULT 0,
    linhas_processadas   INTEGER      NOT NULL DEFAULT 0,
    linhas_erro          INTEGER      NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    finished_at         TIMESTAMPTZ
);
COMMENT ON TABLE import_jobs IS 'Um job por arquivo Excel importado. Processado assíncronamente por um worker BullMQ (fila "import-circuitos", Redis) — único fluxo do app que usa fila; criar/editar circuito manualmente é síncrono.';

CREATE TABLE import_job_itens (
    id                  SERIAL       PRIMARY KEY,
    import_job_id       INTEGER      NOT NULL REFERENCES import_jobs(id),
    linha_numero        INTEGER      NOT NULL,
    dados_originais     JSONB        NOT NULL,
    status               VARCHAR(20)  NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'done', 'failed')),
    erro_msg             TEXT,
    circuito_id          INTEGER      REFERENCES circuitos(id),
    UNIQUE (import_job_id, linha_numero)
);
COMMENT ON TABLE import_job_itens IS 'Uma linha da planilha por registro — guarda os dados originais (para diagnóstico) e o circuito criado (se a linha teve sucesso) ou o erro (se falhou), sem interromper o processamento das demais linhas do arquivo.';

CREATE INDEX idx_import_jobs_projeto ON import_jobs(projeto_id);
CREATE INDEX idx_import_job_itens_job ON import_job_itens(import_job_id);
CREATE INDEX idx_import_job_itens_circuito ON import_job_itens(circuito_id);
