-- =====================================================================
-- Calc-Cabos — schema de dimensionamento de cabos de baixa tensão
-- Base normativa: ABNT NBR 5410:2004. Onde aplicável, cada tabela cita
-- a cláusula/tabela da norma no COMMENT correspondente. O "Guia de
-- Dimensionamento de Cabos para Baixa Tensão" (Prysmian) é usado como
-- fonte prática dos valores numéricos, mas a norma é a referência
-- primária.
--
-- Escopo deste schema: ampacidade (capacidade de condução de corrente),
-- queda de tensão (calculada a partir de resistência/reatância, não
-- armazenada pronta em V/A.km) e suportabilidade ao curto-circuito.
-- Sem views/queries de dimensionamento — só tabelas, constraints e
-- índices; a lógica de cálculo fica para a aplicação.
-- =====================================================================


-- =====================================================================
-- 1. DIMENSÕES / LOOKUPS
-- =====================================================================

CREATE TABLE material_condutor (
    id                          SERIAL PRIMARY KEY,
    nome                        VARCHAR(20)   NOT NULL UNIQUE,
    coeficiente_temperatura_20c NUMERIC(8,6)  NOT NULL,
    fator_kp_proximidade        NUMERIC(3,2)  NOT NULL
);
COMMENT ON TABLE material_condutor IS 'NBR 5410:2004 §6.3 — cobre/alumínio e suas constantes físicas usadas no cálculo de R em CA (coeficiente de temperatura a 20°C: 0,00393 Cu / 0,00403 Al; kp para efeito de proximidade: 1 Cu / 0,8 Al).';
COMMENT ON COLUMN material_condutor.coeficiente_temperatura_20c IS 'α20 da fórmula R'' = Ro·[1+α20·(θ-20)], NBR 5410 §6.3.';
COMMENT ON COLUMN material_condutor.fator_kp_proximidade IS 'kp da fórmula do argumento de Bessel xp² para efeito de proximidade, NBR 5410 §6.3.';

CREATE TABLE secao_nominal (
    id          SERIAL PRIMARY KEY,
    valor_mm2   NUMERIC(8,2) NOT NULL UNIQUE
);
COMMENT ON TABLE secao_nominal IS 'Seções nominais padronizadas de condutores (mm²). Tabela central do schema — normalizada como NUMERIC para permitir ORDER BY/comparação numérica correta (texto tipo "1,5" ordenaria errado).';

CREATE TABLE metodo_referencia (
    id          SERIAL PRIMARY KEY,
    codigo      VARCHAR(3)  NOT NULL UNIQUE,
    descricao   TEXT
);
COMMENT ON TABLE metodo_referencia IS 'NBR 5410:2004 Tabela 33 / §6.2.5.1.2 — métodos de referência A1, A2, B1, B2, C, D, E, F, G usados nas tabelas de capacidade de condução de corrente.';

CREATE TABLE categoria_cabo (
    id      SERIAL PRIMARY KEY,
    nome    VARCHAR(30) NOT NULL UNIQUE
);
COMMENT ON TABLE categoria_cabo IS 'Condutor Isolado / Cabo Unipolar / Cabo Multipolar — categorias usadas na Tabela 33 da NBR 5410 para determinar o método de referência aplicável.';

CREATE TABLE grupo_termico (
    id                  SERIAL PRIMARY KEY,
    nome                VARCHAR(60)   NOT NULL UNIQUE,
    temp_operacao_c     SMALLINT      NOT NULL,
    temp_sobrecarga_c   SMALLINT      NOT NULL
);
COMMENT ON TABLE grupo_termico IS 'Agrupa MATERIAIS de isolação por classe de temperatura (termoplástico/PVC a 70°C vs termofixo/EPR-XLPE-HEPR a 90°C — NBR 5410 Tabela 35). As tabelas de ampacidade (NBR 5410 Tabelas 36-39) só distinguem essas 2 classes, não o material de isolação específico nem o fabricante — confirmado comparando o guia Prysmian com catálogos Nexans, que reproduzem os mesmos valores da norma para materiais diferentes (HEPR e XLPE) dentro da mesma classe. temp_sobrecarga_c também cobre a Tabela 35 (temperatura limite de sobrecarga).';

CREATE TABLE fabricante (
    id      SERIAL PRIMARY KEY,
    nome    VARCHAR(60) NOT NULL UNIQUE
);
COMMENT ON TABLE fabricante IS 'Fabricantes de cabo cujos catálogos alimentam cabos (Prysmian, Nexans, Alubar Coppertec, Induscabos...). Existe para permitir múltiplos fabricantes com produtos equivalentes na mesma especificação técnica (material_isolacao/material_cobertura/grupo_construtivo) sem que o nome comercial de um deles vire chave de cálculo em nenhuma tabela de fato — ver docs/adr/0010.';

CREATE TABLE material_isolacao (
    id                      SERIAL      PRIMARY KEY,
    nome                    VARCHAR(20) NOT NULL UNIQUE,
    grupo_termico_id        INTEGER     NOT NULL REFERENCES grupo_termico(id),
    temp_curto_circuito_c   SMALLINT    NOT NULL
);
COMMENT ON TABLE material_isolacao IS 'Material de isolação do cabo (PVC, LSHF-A/SHF1, EPR, XLPE, HEPR...) — identidade técnica independente de fabricante ou nome comercial, per docs/adr/0010. grupo_termico_id aponta para o bucket de ampacidade compartilhado (ex.: PVC e LSHF-A dividem o mesmo grupo térmico 70°C). temp_curto_circuito_c existe à parte de grupo_termico porque a temperatura final admissível em curto-circuito (NBR 5410 Tabela 30) varia por material mesmo dentro do mesmo grupo térmico (ex.: LSHF-A tem limite diferente de PVC comum, apesar de ambos operarem a 70°C) — é a chave usada por fator_k_curto_circuito.';

CREATE TABLE material_cobertura (
    id      SERIAL      PRIMARY KEY,
    nome    VARCHAR(20) NOT NULL UNIQUE
);
COMMENT ON TABLE material_cobertura IS 'Material da cobertura/capa externa do cabo (PVC ST1/ST2, SHF1...). Inclui a linha sentinela ''Nenhuma'' para condutores isolados sem cobertura — cabos.material_cobertura_id é NOT NULL (em vez de nulável) exatamente para que essa coluna participe do UNIQUE de identidade de cabos sem o problema de NULLs nunca serem iguais entre si em constraints UNIQUE.';

CREATE TABLE grupo_construtivo (
    id      SERIAL PRIMARY KEY,
    nome    VARCHAR(60) NOT NULL UNIQUE
);
COMMENT ON TABLE grupo_construtivo IS 'Agrupa cabos que compartilham a mesma tabela de resistência/reatância (varia pela construção do cabo, não só pela temperatura de isolação — ex.: Superastic Flex e Afumex Green compartilham tabela; Sintenax tem tabela própria).';

CREATE TABLE arranjo_ampacidade (
    id          SERIAL PRIMARY KEY,
    codigo      VARCHAR(40) NOT NULL UNIQUE,
    descricao   TEXT
);
COMMENT ON TABLE arranjo_ampacidade IS 'NBR 5410:2004 Tabelas 38-39 — arranjos físicos/topológicos dos condutores (multipolar justaposto, unipolar em trifólio, unipolares espaçados na horizontal/vertical etc.), independente da distância de espaçamento (ver arranjo_espacamento). Usada tanto por capacidade_conducao_corrente (métodos E/F/G) quanto por resistencia_reatancia_ca — ver docs/adr/0012, que também documenta a inclusão do código unipolar_justaposto_par (faltante na modelagem original) e explica por que multipolar_justaposto/unipolar_justaposto_trifolio têm valores de Rca/XL diferentes mesmo ambos sendo fisicamente "encostados".';

CREATE TABLE arranjo_espacamento (
    id          SERIAL PRIMARY KEY,
    codigo      VARCHAR(20) NOT NULL UNIQUE,
    descricao   TEXT
);
COMMENT ON TABLE arranjo_espacamento IS 'Espaçamentos entre condutores (encostados/s=2D, s=13cm, s=20cm) usados nas tabelas de resistência/reatância em corrente alternada — afetam yp (efeito de proximidade, NBR 5410 §6.3) e a reatância indutiva (§6.4).';

CREATE TABLE classe_encordoamento (
    id      SERIAL PRIMARY KEY,
    nome    VARCHAR(40) NOT NULL UNIQUE
);
COMMENT ON TABLE classe_encordoamento IS 'Classe 2 (compactado ou não) / Classe 5 (flexível) — usada na tabela de resistência em corrente contínua a 20°C (guia Prysmian Tabela 18) e como parte da identidade genérica de cabos (distingue variantes rígida/flexível que, de outro modo, teriam o mesmo material de isolação, cobertura e tensão — ex.: Sintenax vs Sintenax Flex).';

CREATE TABLE tipo_circuito (
    id                              SERIAL PRIMARY KEY,
    codigo                          VARCHAR(10)   NOT NULL UNIQUE,
    tipo_corrente                   VARCHAR(2)    NOT NULL DEFAULT 'CA' CHECK (tipo_corrente IN ('CA', 'CC')),
    numero_fases                    SMALLINT      CHECK (numero_fases IN (1, 2, 3)),
    tem_neutro                      BOOLEAN       NOT NULL DEFAULT FALSE,
    tem_protecao_pe                 BOOLEAN       NOT NULL DEFAULT FALSE,
    tem_blindagem                   BOOLEAN       NOT NULL DEFAULT FALSE,
    numero_condutores_carregados    SMALLINT      NOT NULL CHECK (numero_condutores_carregados IN (2, 3)),
    permite_quarto_condutor         BOOLEAN       NOT NULL DEFAULT FALSE,
    fator_correcao_neutro_carregado NUMERIC(4,3),
    formula_queda_tensao            VARCHAR(20)   NOT NULL CHECK (formula_queda_tensao IN ('monofasica_bifasica', 'trifasica')),
    CHECK (fator_correcao_neutro_carregado IS NULL OR permite_quarto_condutor),
    CHECK ((tipo_corrente = 'CA' AND numero_fases IS NOT NULL) OR (tipo_corrente = 'CC' AND numero_fases IS NULL)),
    UNIQUE (tipo_corrente, numero_fases, tem_neutro, tem_protecao_pe, tem_blindagem)
);
COMMENT ON TABLE tipo_circuito IS 'NBR 5410:2004 §6.2.5.6.1, Tabela 46 — número de condutores carregados por esquema de condutores vivos, decomposto em campos ortogonais (tipo_corrente, numero_fases, tem_neutro) em vez de um enum fechado de esquemas, para representar também combinações reais de projeto que a Tabela 46 não nomeia diretamente (com/sem PE, com/sem blindagem). tem_protecao_pe e tem_blindagem são informativos/identificadores do circuito — NUNCA entram no cálculo de numero_condutores_carregados: PE e blindagem não são "condutores vivos" (Tabela 46 só classifica condutores vivos; confirmado também em restricao_material_condutor/§6.2.3).';
COMMENT ON COLUMN tipo_circuito.tipo_corrente IS 'CA (default) ou CC. Corrente contínua usa numero_fases NULO — a Tabela 46 trata CC à parte (corrente contínua a dois/três condutores), não como um caso de "fases".';
COMMENT ON COLUMN tipo_circuito.numero_fases IS '1 (monofásico/F), 2 (bifásico/2F) ou 3 (trifásico/3F). NULO quando tipo_corrente = CC (ver CHECK da tabela).';
COMMENT ON COLUMN tipo_circuito.tem_neutro IS 'Presença de condutor neutro. Em CC, equivale ao "terceiro condutor" central de uma linha CC a três condutores (mesma lógica da Tabela 46 para monofásico a 3 condutores).';
COMMENT ON COLUMN tipo_circuito.tem_protecao_pe IS 'Presença de condutor de proteção (terra) no circuito — ex.: F+N+T, 3F+N+T. Não é "condutor vivo" (NBR 5410 Tabela 46) e por isso nunca altera numero_condutores_carregados.';
COMMENT ON COLUMN tipo_circuito.tem_blindagem IS 'Presença de blindagem/tela (shield) — ex.: "3F+sh", comum em cabos para inversores de frequência/automação industrial. Característica construtiva do cabo, não um condutor vivo; nunca altera numero_condutores_carregados.';
COMMENT ON COLUMN tipo_circuito.permite_quarto_condutor IS 'Verdadeiro só para trifásico com neutro: NBR 5410 §6.2.5.6.1 — se a 3ª harmônica e múltiplos no neutro passar de 15%, o neutro conta como condutor carregado (circuito vira "4 condutores carregados") e aplica-se fator_correcao_neutro_carregado sobre a capacidade de 3 condutores.';
COMMENT ON COLUMN tipo_circuito.fator_correcao_neutro_carregado IS 'Fator 0,86 do §6.2.5.6.1. NULO em toda linha onde permite_quarto_condutor for FALSE — o fator só existe conceitualmente para o esquema trifásico com neutro (não há "4º condutor" possível em F+N, 2F, CC etc., então não faz sentido a coluna ter valor ali). O CHECK da tabela impõe essa regra no banco, não só na convenção.';
COMMENT ON COLUMN tipo_circuito.formula_queda_tensao IS 'Qual multiplicador usar na fórmula de queda de tensão da NBR 5410 §6.2: monofásico/bifásico = 2·(R·cosφ+XL·senφ)·I·ℓ; trifásico = √3·(R·cosφ+XL·senφ)·I·ℓ.';

CREATE TABLE finalidade_circuito (
    id      SERIAL PRIMARY KEY,
    nome    VARCHAR(60) NOT NULL UNIQUE
);
COMMENT ON TABLE finalidade_circuito IS 'NBR 5410:2004 Tabela 47 (seção mínima) — Iluminação, Força, Sinalização e Controle, Extrabaixa Tensão. Deliberadamente enxuta e extensível: linhas de "Motor" (ou tabela futura de parâmetros de motor) devem encaixar aqui sem alterar o schema.';

CREATE TABLE restricao_material_condutor (
    id                  SERIAL PRIMARY KEY,
    material_condutor_id INTEGER     NOT NULL REFERENCES material_condutor(id),
    contexto            VARCHAR(20)  NOT NULL CHECK (contexto IN ('industrial', 'comercial', 'residencial', 'bd4')),
    secao_minima_mm2     NUMERIC(8,2),
    permitido            BOOLEAN     NOT NULL,
    condicao_desc        TEXT,
    UNIQUE (material_condutor_id, contexto)
);
COMMENT ON TABLE restricao_material_condutor IS 'NBR 5410:2004 §6.2.3.7/6.2.3.8 — condutor de alumínio é proibido em instalações residenciais e em locais BD4; permitido em industrial (seção ≥16 mm², alimentação própria/subestação dedicada, manutenção qualificada) e em comercial (seção ≥50 mm², local exclusivamente BD1, manutenção qualificada). Consultada antes de oferecer alumínio como opção de material.';


-- =====================================================================
-- 2. CABOS E MÉTODOS DE INSTALAÇÃO
-- =====================================================================

CREATE TABLE cabos (
    id                          SERIAL PRIMARY KEY,
    norma_abnt                  VARCHAR(20)  NOT NULL,
    tensao_isolamento           VARCHAR(20)  NOT NULL,
    material_isolacao_id        INTEGER      NOT NULL REFERENCES material_isolacao(id),
    material_cobertura_id       INTEGER      NOT NULL REFERENCES material_cobertura(id),
    classe_encordoamento_id     INTEGER      NOT NULL REFERENCES classe_encordoamento(id),
    grupo_construtivo_id        INTEGER      NOT NULL REFERENCES grupo_construtivo(id),
    UNIQUE (material_isolacao_id, material_cobertura_id, tensao_isolamento, classe_encordoamento_id)
);
COMMENT ON TABLE cabos IS 'Especificação técnica genérica de cabo — identificada por material de isolação, material de cobertura, tensão de isolamento e classe de encordoamento (rígido/flexível), NUNCA por fabricante ou nome comercial (ver docs/adr/0010 e 0011). Produtos equivalentes de fabricantes diferentes (ex.: GSette Easy da Prysmian e HEPR-PVC 0,6/1kV da Nexans) resolvem para a MESMA linha aqui — essa é a propriedade central do desenho: nenhuma tabela de fato (ampacidade, R/XL, curto-circuito) precisa de dado duplicado por fabricante. Rastreabilidade de qual fabricante/nome comercial corresponde a cada linha fica em produto_comercial, fora do caminho de cálculo. grupo_termico e temp_max_curto_circuito não são colunas aqui — são derivados de material_isolacao_id (fonte única).';

CREATE TABLE produto_comercial (
    id              SERIAL      PRIMARY KEY,
    fabricante_id   INTEGER     NOT NULL REFERENCES fabricante(id),
    nome_comercial  VARCHAR(50) NOT NULL,
    cabo_id         INTEGER     NOT NULL REFERENCES cabos(id),
    UNIQUE (fabricante_id, nome_comercial)
);
COMMENT ON TABLE produto_comercial IS 'Tabela periférica de referência cruzada (fabricante, nome comercial) → especificação técnica genérica em cabos. Existe só para rastreabilidade/orçamento (ex.: "Sintenax é o nome comercial da Prysmian para este cabo genérico") — nenhuma tabela de fato (ampacidade, resistencia_reatancia_ca, fator_k_curto_circuito) referencia produto_comercial_id no cálculo, exceto o override opcional em resistencia_reatancia_ca quando um fabricante específico publica valor próprio. Ver docs/adr/0011.';

CREATE TABLE cabo_numero_condutores (
    id                  SERIAL PRIMARY KEY,
    cabo_id             INTEGER     NOT NULL REFERENCES cabos(id),
    numero_condutores   SMALLINT    NOT NULL,
    categoria_cabo_id   INTEGER     NOT NULL REFERENCES categoria_cabo(id),
    UNIQUE (cabo_id, numero_condutores)
);
COMMENT ON TABLE cabo_numero_condutores IS 'Normaliza cabos.numero_condutores (antes texto tipo "1,2,3,4 e 5"). categoria_cabo_id fica aqui, não em cabos, porque a categoria depende do nº de condutores: o guia Prysmian Tabela 6 lista os mesmos produtos (Sintenax, GSette Easy...) como "Cabo Unipolar" quando numero_condutores=1 e "Cabo Multipolar" quando 2-5.';

CREATE TABLE metodo_instalacao (
    id                      SERIAL      PRIMARY KEY,
    tipo_linha_eletrica     TEXT        NOT NULL
);
COMMENT ON TABLE metodo_instalacao IS 'NBR 5410:2004 Tabela 33 (coluna "Tipo de linha elétrica"). numero_metodo e as 3 colunas ref_condutor_isolado/ref_cabo_unipolar/ref_cabo_multipolar saíram daqui — normalizadas em metodo_instalacao_numero e metodo_instalacao_referencia.';

CREATE TABLE metodo_instalacao_numero (
    id                      SERIAL      PRIMARY KEY,
    metodo_instalacao_id    INTEGER     NOT NULL REFERENCES metodo_instalacao(id),
    codigo                  VARCHAR(10) NOT NULL,
    UNIQUE (metodo_instalacao_id, codigo)
);
COMMENT ON TABLE metodo_instalacao_numero IS 'Normaliza metodo_instalacao.numero_metodo (antes texto tipo "31/31A/32/32A/35/36") em 1 linha por código individual da Tabela 33 da NBR 5410.';

CREATE TABLE metodo_instalacao_referencia (
    id                      SERIAL      PRIMARY KEY,
    metodo_instalacao_id    INTEGER     NOT NULL REFERENCES metodo_instalacao(id),
    categoria_cabo_id       INTEGER     NOT NULL REFERENCES categoria_cabo(id),
    metodo_referencia_id    INTEGER     NOT NULL REFERENCES metodo_referencia(id),
    UNIQUE (metodo_instalacao_id, categoria_cabo_id)
);
COMMENT ON TABLE metodo_instalacao_referencia IS 'Normaliza as 3 colunas nuláveis ref_condutor_isolado/ref_cabo_unipolar/ref_cabo_multipolar de metodo_instalacao (NBR 5410 Tabela 33) em uma tabela ponte (método de instalação × categoria de cabo → método de referência). Permite juntar direto com capacidade_conducao_corrente. Também substitui a antiga tabela cabos_metodo_instalacao: quais métodos um cabo específico suporta é 100% derivável via cabos → cabo_numero_condutores → categoria_cabo_id → metodo_instalacao_referencia, sem precisar de junção própria por cabo (ver docs/adr/0010) — verificado linha a linha contra os dados originais antes de remover a tabela.';


-- =====================================================================
-- 3. SEÇÕES MÍNIMAS (NBR 5410:2004 §6.2.6, Tabelas 47/48/58)
-- =====================================================================

CREATE TABLE tipo_linha_secao_minima (
    id      SERIAL      PRIMARY KEY,
    nome    VARCHAR(60) NOT NULL UNIQUE
);
COMMENT ON TABLE tipo_linha_secao_minima IS 'NBR 5410:2004 §6.2.6.1, Tabela 47 — a norma discrimina a seção mínima por 3 categorias de linha, não só por finalidade: condutores e cabos isolados (instalação fixa), condutores nus e linhas flexíveis com cabos isolados. Normalizado em tabela própria (não texto livre) por ser uma dimensão pequena e reutilizável, na mesma linha do restante do schema (ADR 0001).';

CREATE TABLE secao_minima_condutor (
    id                          SERIAL       PRIMARY KEY,
    finalidade_circuito_id      INTEGER      NOT NULL REFERENCES finalidade_circuito(id),
    tipo_linha_secao_minima_id  INTEGER      NOT NULL REFERENCES tipo_linha_secao_minima(id),
    material_condutor_id        INTEGER      NOT NULL REFERENCES material_condutor(id),
    secao_minima_mm2            NUMERIC(8,2) NOT NULL,
    observacao                  TEXT,
    UNIQUE (finalidade_circuito_id, tipo_linha_secao_minima_id, material_condutor_id)
);
COMMENT ON TABLE secao_minima_condutor IS 'NBR 5410:2004 §6.2.6.1, Tabela 47 — seção mínima por (finalidade do circuito × tipo de linha × material). A norma NÃO tabela alumínio para todas as combinações: não há valor de alumínio para "circuitos de sinalização e controle" (nem em condutores isolados, nem em condutores nus) — só para iluminação e força. Isso é consistente com §6.2.3.7/6.2.3.8 (restricao_material_condutor): as seções desses circuitos (0,5 mm² Cu isolado / 4 mm² Cu nu) são muito inferiores aos mínimos de 16 mm²/50 mm² exigidos para alumínio, então alumínio nunca atenderia simultaneamente aos dois critérios nesses circuitos.';

CREATE TABLE secao_minima_neutro (
    id              SERIAL   PRIMARY KEY,
    secao_fase_id   INTEGER  NOT NULL UNIQUE REFERENCES secao_nominal(id),
    secao_neutro_id INTEGER  NOT NULL REFERENCES secao_nominal(id)
);
COMMENT ON TABLE secao_minima_neutro IS 'NBR 5410:2004 §6.2.6.2.6, Tabela 48 — seção reduzida do condutor neutro em circuito trifásico equilibrado, condutores de fase e neutro do mesmo metal, neutro protegido contra sobrecorrentes.';

CREATE TABLE secao_minima_protecao_pe (
    id                  SERIAL       PRIMARY KEY,
    secao_fase_min_mm2  NUMERIC(8,2) NOT NULL,
    secao_fase_max_mm2  NUMERIC(8,2),
    formula_desc        VARCHAR(20)  NOT NULL,
    secao_fixa_mm2       NUMERIC(8,2)
);
COMMENT ON TABLE secao_minima_protecao_pe IS 'NBR 5410:2004 §6.4.3.1.3, Tabela 58 — método simplificado da seção mínima do condutor de proteção (PE) em função da seção de fase: S≤16→S, 16<S≤35→16, S>35→S/2.';


-- =====================================================================
-- 4. AMPACIDADE (NBR 5410:2004 §6.2.5, Tabelas 36-39)
-- =====================================================================

CREATE TABLE capacidade_conducao_corrente (
    id                              SERIAL         PRIMARY KEY,
    grupo_termico_id                INTEGER        NOT NULL REFERENCES grupo_termico(id),
    material_condutor_id            INTEGER        NOT NULL REFERENCES material_condutor(id),
    metodo_referencia_id            INTEGER        NOT NULL REFERENCES metodo_referencia(id),
    numero_condutores_carregados    SMALLINT       NOT NULL CHECK (numero_condutores_carregados IN (2, 3)),
    arranjo_ampacidade_id           INTEGER        REFERENCES arranjo_ampacidade(id),
    secao_nominal_id                INTEGER        NOT NULL REFERENCES secao_nominal(id),
    corrente_admissivel_a           NUMERIC(10,2)  NOT NULL,
    UNIQUE (grupo_termico_id, material_condutor_id, metodo_referencia_id, numero_condutores_carregados, arranjo_ampacidade_id, secao_nominal_id)
);
COMMENT ON TABLE capacidade_conducao_corrente IS 'NBR 5410:2004 §6.2.5.2, Tabelas 36-39 — capacidade de condução de corrente. arranjo_ampacidade_id é NULO para os métodos A1/A2/B1/B2/C/D (Tabelas 36-37, sem distinção de arranjo) e obrigatório para E/F/G (Tabelas 38-39). Para 4 condutores carregados, aplicar tipo_circuito.fator_correcao_neutro_carregado (0,86) sobre o valor de 3 condutores — NBR 5410 §6.2.5.6.1, não existe linha própria para 4.';


-- =====================================================================
-- 5. FATORES DE CORREÇÃO (NBR 5410:2004 §6.2.5.3-6.2.5.5, Tabelas 40-45)
-- =====================================================================

CREATE TABLE fator_correcao_temperatura (
    id                  SERIAL       PRIMARY KEY,
    tipo_instalacao     VARCHAR(10)  NOT NULL CHECK (tipo_instalacao IN ('ambiente', 'solo')),
    grupo_termico_id    INTEGER      NOT NULL REFERENCES grupo_termico(id),
    temperatura_c       SMALLINT     NOT NULL,
    fator               NUMERIC(4,2) NOT NULL,
    UNIQUE (tipo_instalacao, grupo_termico_id, temperatura_c)
);
COMMENT ON TABLE fator_correcao_temperatura IS 'NBR 5410:2004 §6.2.5.3, Tabela 40 — fator de correção para temperatura ambiente/solo diferente da referência (30°C ar / 20°C solo), por grupo térmico (isolação PVC/LSHF vs EPR/XLPE).';

CREATE TABLE fator_correcao_resistividade_solo (
    id                              SERIAL        PRIMARY KEY,
    resistividade_km_w              NUMERIC(6,2)  NOT NULL UNIQUE,
    fator_duto_enterrado            NUMERIC(4,2)  NOT NULL,
    fator_diretamente_enterrado     NUMERIC(4,2)  NOT NULL
);
COMMENT ON TABLE fator_correcao_resistividade_solo IS 'NBR 5410:2004 §6.2.5.4, Tabela 41 — fator de correção para linhas subterrâneas em solo com resistividade térmica diferente de 2,5 K.m/W.';

CREATE TABLE fator_agrupamento_ar (
    id                      SERIAL       PRIMARY KEY,
    cenario                 VARCHAR(20)  NOT NULL CHECK (cenario IN ('camada_unica', 'multicamada')),
    circuitos_min           SMALLINT     NOT NULL,
    circuitos_max           SMALLINT,
    camadas_min             SMALLINT,
    camadas_max             SMALLINT,
    metodo_instalacao_grupo VARCHAR(20),
    fator                   NUMERIC(4,2) NOT NULL
);
COMMENT ON TABLE fator_agrupamento_ar IS 'NBR 5410:2004 §6.2.5.5, Tabelas 42-43 — fator de agrupamento para condutores/cabos ao ar livre, embutidos ou em conduto fechado. cenario=camada_unica cobre a Tabela 42 (feixe e camada única sobre parede/piso/teto/bandeja/leito); cenario=multicamada cobre a Tabela 43 (mais de uma camada). Colapsadas em 1 tabela em vez de 2 quase-duplicadas.';

CREATE TABLE fator_agrupamento_enterrado (
    id                  SERIAL       PRIMARY KEY,
    cenario             VARCHAR(20)  NOT NULL CHECK (cenario IN ('direto', 'duto_multipolar', 'duto_unipolar')),
    numero_circuitos    SMALLINT     NOT NULL,
    distancia_desc      VARCHAR(30)  NOT NULL,
    fator                NUMERIC(4,2) NOT NULL,
    UNIQUE (cenario, numero_circuitos, distancia_desc)
);
COMMENT ON TABLE fator_agrupamento_enterrado IS 'NBR 5410:2004 §6.2.5.5, Tabelas 44-45 — fator de agrupamento para cabos diretamente enterrados (cenario=direto) ou em eletrodutos enterrados, cabo multipolar (duto_multipolar) ou cabos unipolares (duto_unipolar) por eletroduto individual. Colapsadas em 1 tabela em vez de 3 quase-duplicadas.';


-- =====================================================================
-- 6. RESISTÊNCIA / REATÂNCIA — base do cálculo de queda de tensão
--    (NBR 5410:2004 §6.2.3-6.2.4 dão a metodologia; a norma não tabela
--    R/XL prontos por produto, quem tabela é o guia Prysmian)
-- =====================================================================

CREATE TABLE resistencia_dc_20c (
    id                      SERIAL         PRIMARY KEY,
    classe_encordoamento_id INTEGER        NOT NULL REFERENCES classe_encordoamento(id),
    material_condutor_id    INTEGER        NOT NULL REFERENCES material_condutor(id),
    secao_nominal_id        INTEGER        NOT NULL REFERENCES secao_nominal(id),
    resistencia_ohm_km      NUMERIC(10,5)  NOT NULL,
    UNIQUE (classe_encordoamento_id, material_condutor_id, secao_nominal_id)
);
COMMENT ON TABLE resistencia_dc_20c IS 'Resistência elétrica em corrente contínua a 20°C (Ro da fórmula R'' = Ro·[1+α20·(θ-20)], NBR 5410 §6.3). Ponto de partida do cálculo de queda de tensão quando não se usa direto a tabela de R/XL em CA já corrigida.';

CREATE TABLE resistencia_reatancia_ca (
    id                              SERIAL         PRIMARY KEY,
    grupo_construtivo_id            INTEGER        NOT NULL REFERENCES grupo_construtivo(id),
    produto_comercial_id            INTEGER        REFERENCES produto_comercial(id),
    material_condutor_id            INTEGER        NOT NULL REFERENCES material_condutor(id),
    secao_nominal_id                INTEGER        NOT NULL REFERENCES secao_nominal(id),
    numero_condutores_carregados    SMALLINT       NOT NULL CHECK (numero_condutores_carregados IN (2, 3)),
    arranjo_ampacidade_id           INTEGER        NOT NULL REFERENCES arranjo_ampacidade(id),
    arranjo_espacamento_id          INTEGER        NOT NULL REFERENCES arranjo_espacamento(id),
    resistencia_ca_ohm_km           NUMERIC(10,5)  NOT NULL,
    reatancia_indutiva_ohm_km       NUMERIC(10,5)  NOT NULL
);
COMMENT ON TABLE resistencia_reatancia_ca IS 'Resistência em CA (R, já com efeito pelicular e de proximidade — NBR 5410 §6.3) e reatância indutiva (XL — §6.4), por grupo construtivo/material/seção/arranjo. ÚNICA tabela usada para calcular queda de tensão: ΔV é calculado pelo consumidor do banco com R, XL, cosφ, I, ℓ e o multiplicador de tipo_circuito.formula_queda_tensao (NBR 5410 §6.2) — não existe tabela de queda de tensão pronta em V/A.km neste schema. produto_comercial_id é NULO nas linhas "valor base" (fallback por grupo_construtivo, tipicamente a partir do guia Prysmian — nem todo fabricante publica R/XL em catálogo, ex.: Nexans) e preenchido só quando um PRODUTO COMERCIAL específico (não a especificação genérica em cabos, que pode ser compartilhada por vários fabricantes) publica valor próprio que deve prevalecer sobre o base. Consumidor resolve: buscar linha pelo produto_comercial_id do produto sendo usado; se não achar, cair para a linha produto_comercial_id IS NULL do mesmo grupo_construtivo. Ver docs/adr/0010 e 0011. arranjo_ampacidade_id foi adicionado (docs/adr/0012) porque arranjo_espacamento sozinho não distingue topologias que têm Rca/XL diferentes apesar de ambas serem "encostado" (ex.: 3 unipolares no mesmo plano encostados vs. 3 unipolares em trifólio vs. cabo multipolar de 3 núcleos) — os dois discriminadores juntos (topologia + distância) reproduzem exatamente as colunas do guia Prysmian (Tabelas 28-36). Nem toda família de produto (grupo_construtivo) usa todos os códigos: Superastic/Superastic Flex só têm variante unipolar (9 combinações por seção); Sintenax/Sintenax Flex/GSette Easy/Voltenax/Voltalene também têm cabo multipolar de 2/3 núcleos e arranjo em quadrado (12 combinações) — ver docs/adr/0012.';
COMMENT ON COLUMN resistencia_reatancia_ca.produto_comercial_id IS 'NULO = valor base do grupo construtivo (fallback). Preenchido = valor específico daquele produto comercial de um fabricante, que prevalece sobre o base na resolução. Referencia produto_comercial (não cabos) porque o override é uma característica do fabricante/produto, não da especificação técnica genérica compartilhada.';
COMMENT ON COLUMN resistencia_reatancia_ca.arranjo_ampacidade_id IS 'Topologia dos condutores (mesma dimensão usada por capacidade_conducao_corrente). Para numero_condutores_carregados=2: unipolar_justaposto_par (4 distâncias) ou multipolar_justaposto (cabo de 2 núcleos, só arranjo_espacamento=encostado). Para 3: unipolar_justaposto_plano (4 distâncias), unipolar_justaposto_trifolio (só encostado), unipolar_espacado_quadrado (só s_20cm) ou multipolar_justaposto (cabo de 3 núcleos, só encostado). Ver docs/adr/0012.';

CREATE UNIQUE INDEX uq_resistencia_reatancia_ca_base
    ON resistencia_reatancia_ca (grupo_construtivo_id, material_condutor_id, secao_nominal_id, numero_condutores_carregados, arranjo_ampacidade_id, arranjo_espacamento_id)
    WHERE produto_comercial_id IS NULL;
CREATE UNIQUE INDEX uq_resistencia_reatancia_ca_override
    ON resistencia_reatancia_ca (produto_comercial_id, secao_nominal_id, numero_condutores_carregados, arranjo_ampacidade_id, arranjo_espacamento_id)
    WHERE produto_comercial_id IS NOT NULL;
COMMENT ON INDEX uq_resistencia_reatancia_ca_base IS 'Garante 1 valor base por (grupo_construtivo, material, seção, nº condutores, topologia, espaçamento) — regime produto_comercial_id IS NULL.';
COMMENT ON INDEX uq_resistencia_reatancia_ca_override IS 'Garante 1 override por (produto comercial específico, seção, nº condutores, topologia, espaçamento) — regime produto_comercial_id IS NOT NULL.';


-- =====================================================================
-- 7. CURTO-CIRCUITO (NBR 5410:2004 §5.3.5.5, Tabela 30; §6.4.3.1, Tabelas 53-58)
-- =====================================================================

CREATE TABLE fator_k_curto_circuito (
    id                      SERIAL        PRIMARY KEY,
    material_isolacao_id    INTEGER       NOT NULL REFERENCES material_isolacao(id),
    material_condutor_id    INTEGER       NOT NULL REFERENCES material_condutor(id),
    secao_max_mm2           NUMERIC(8,2),
    fator_k                 NUMERIC(6,2)  NOT NULL,
    temp_inicial_c          SMALLINT      NOT NULL,
    temp_final_c            SMALLINT      NOT NULL,
    UNIQUE (material_isolacao_id, material_condutor_id, secao_max_mm2)
);
COMMENT ON TABLE fator_k_curto_circuito IS 'NBR 5410:2004 §5.3.5.5.2, Tabela 30 — fator k do condutor de fase para a fórmula S=√(I²·t)/k (suportabilidade ao curto-circuito). Referencia material_isolacao_id (não cabo_id nem grupo_termico): é uma tabela normativa da NBR 5410, sempre igual entre fabricantes para o mesmo material de isolação, e material_isolacao já distingue casos como LSHF-A (temp_curto_circuito_c própria) de PVC comum mesmo os dois dividindo o mesmo grupo_termico 70°C. Revisado em docs/adr/0010 — antes referenciava cabo_id (nome comercial Prysmian), o que quebraria ao cadastrar produtos equivalentes de outros fabricantes.';

CREATE TABLE fator_k_protecao_pe (
    id                          SERIAL        PRIMARY KEY,
    cenario                     VARCHAR(40)   NOT NULL CHECK (cenario IN (
                                    'isolado_nao_incorporado',
                                    'nu_contato_cobertura',
                                    'veia_cabo_multipolar',
                                    'armacao_capa_metalica',
                                    'nu_sem_risco'
                                )),
    material_condutor_id        INTEGER       NOT NULL REFERENCES material_condutor(id),
    isolacao_cobertura_desc     VARCHAR(20)   NOT NULL,
    secao_max_mm2               NUMERIC(8,2),
    fator_k                     NUMERIC(6,2)  NOT NULL,
    condicao_desc                TEXT
);
COMMENT ON TABLE fator_k_protecao_pe IS 'NBR 5410:2004 §6.4.3.1, Tabelas 53-57 — fator k do condutor de proteção (PE) por variante construtiva: isolado não incorporado a cabo multipolar (Tabela 53), nu em contato com a cobertura do cabo (Tabela 54), veia de cabo multipolar ou enfeixado (Tabela 55), armação/capa metálica/condutor concêntrico (Tabela 56), nu sem risco a material adjacente (Tabela 57 — condicao_desc distingue visível/condições normais/risco de incêndio). Corresponde às Tabelas 38-42 do guia Prysmian.';


-- =====================================================================
-- 8. ÍNDICES EXPLÍCITOS EM COLUNAS DE FK
--    (Postgres não indexa FK automaticamente, só PK/UNIQUE). Quando a
--    FK já é a coluna líder de um UNIQUE composto da própria tabela, o
--    índice desse UNIQUE já serve a busca por ela sozinha (regra do
--    prefixo mais à esquerda do B-tree) — não se cria índice duplicado
--    nesses casos, só nas colunas de FK não cobertas.
-- =====================================================================

-- restricao_material_condutor: material_condutor_id já é líder de UNIQUE(material_condutor_id, contexto)

CREATE INDEX idx_material_isolacao_grupo_termico ON material_isolacao(grupo_termico_id);

-- cabos: material_isolacao_id já é líder de UNIQUE(material_isolacao_id, material_cobertura_id, tensao_isolamento, classe_encordoamento_id)
CREATE INDEX idx_cabos_material_cobertura ON cabos(material_cobertura_id);
CREATE INDEX idx_cabos_classe_encordoamento ON cabos(classe_encordoamento_id);
CREATE INDEX idx_cabos_grupo_construtivo ON cabos(grupo_construtivo_id);

-- produto_comercial: fabricante_id já é líder de UNIQUE(fabricante_id, nome_comercial)
CREATE INDEX idx_produto_comercial_cabo ON produto_comercial(cabo_id);

-- cabo_numero_condutores: cabo_id já é líder de UNIQUE(cabo_id, numero_condutores)
CREATE INDEX idx_cabo_numero_condutores_categoria ON cabo_numero_condutores(categoria_cabo_id);

-- metodo_instalacao_numero: metodo_instalacao_id já é líder de UNIQUE(metodo_instalacao_id, codigo)

-- metodo_instalacao_referencia: metodo_instalacao_id já é líder de UNIQUE(metodo_instalacao_id, categoria_cabo_id)
CREATE INDEX idx_metodo_instalacao_referencia_categoria ON metodo_instalacao_referencia(categoria_cabo_id);
CREATE INDEX idx_metodo_instalacao_referencia_ref ON metodo_instalacao_referencia(metodo_referencia_id);

-- secao_minima_condutor: finalidade_circuito_id já é líder de UNIQUE(finalidade_circuito_id, tipo_linha_secao_minima_id, material_condutor_id)
CREATE INDEX idx_secao_minima_condutor_tipo_linha ON secao_minima_condutor(tipo_linha_secao_minima_id);
CREATE INDEX idx_secao_minima_condutor_material ON secao_minima_condutor(material_condutor_id);

CREATE INDEX idx_secao_minima_neutro_neutro ON secao_minima_neutro(secao_neutro_id);

-- capacidade_conducao_corrente: grupo_termico_id já é líder do UNIQUE composto (ver criação da tabela)
CREATE INDEX idx_capacidade_conducao_corrente_material ON capacidade_conducao_corrente(material_condutor_id);
CREATE INDEX idx_capacidade_conducao_corrente_metodo_ref ON capacidade_conducao_corrente(metodo_referencia_id);
CREATE INDEX idx_capacidade_conducao_corrente_arranjo ON capacidade_conducao_corrente(arranjo_ampacidade_id);
CREATE INDEX idx_capacidade_conducao_corrente_secao ON capacidade_conducao_corrente(secao_nominal_id);

CREATE INDEX idx_fator_correcao_temperatura_grupo_termico ON fator_correcao_temperatura(grupo_termico_id);

-- resistencia_dc_20c: classe_encordoamento_id já é líder de UNIQUE(classe_encordoamento_id, material_condutor_id, secao_nominal_id)
CREATE INDEX idx_resistencia_dc_20c_material ON resistencia_dc_20c(material_condutor_id);
CREATE INDEX idx_resistencia_dc_20c_secao ON resistencia_dc_20c(secao_nominal_id);

-- resistencia_reatancia_ca: grupo_construtivo_id já é líder do índice único parcial "base"
--   (uq_resistencia_reatancia_ca_base); produto_comercial_id já é líder do índice único parcial
--   "override" (uq_resistencia_reatancia_ca_override) — ver criação da tabela.
CREATE INDEX idx_resistencia_reatancia_ca_material ON resistencia_reatancia_ca(material_condutor_id);
CREATE INDEX idx_resistencia_reatancia_ca_secao ON resistencia_reatancia_ca(secao_nominal_id);
CREATE INDEX idx_resistencia_reatancia_ca_arranjo ON resistencia_reatancia_ca(arranjo_espacamento_id);

-- fator_k_curto_circuito: material_isolacao_id já é líder de UNIQUE(material_isolacao_id, material_condutor_id, secao_max_mm2)
CREATE INDEX idx_fator_k_curto_circuito_material ON fator_k_curto_circuito(material_condutor_id);

CREATE INDEX idx_fator_k_protecao_pe_material ON fator_k_protecao_pe(material_condutor_id);
