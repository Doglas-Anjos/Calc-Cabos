-- =====================================================================
-- Calc-Cabos — carga de dados
--
-- Duas categorias de dados neste arquivo:
--   1) Migração integral dos dados já existentes no repositório (9 cabos
--      Prysmian, 32 métodos de instalação da Tabela 33 da NBR 5410, e os
--      pares cabo×método) para o novo formato normalizado.
--   2) Dados de referência das novas dimensões (material, seção, método
--      de referência, tipo de circuito etc.) e 1-2 INSERTs de exemplo
--      por tabela de fato nova — só para validar o formato das colunas.
--      A carga completa das tabelas numéricas do guia (centenas de
--      linhas por tabela) fica para uma etapa futura de importação via
--      CSV, fora do escopo deste arquivo.
-- =====================================================================


-- =====================================================================
-- 1. DIMENSÕES / LOOKUPS
-- =====================================================================

INSERT INTO material_condutor (nome, coeficiente_temperatura_20c, fator_kp_proximidade) VALUES
    ('Cobre',    0.00393, 1.0),
    ('Alumínio', 0.00403, 0.8);

INSERT INTO secao_nominal (valor_mm2) VALUES
    (0.5), (0.75), (1), (1.5), (2.5), (4), (6), (10), (16), (25), (35), (50),
    (70), (95), (120), (150), (185), (240), (300), (400), (500), (630), (800), (1000);

INSERT INTO metodo_referencia (codigo, descricao) VALUES
    ('A1', 'Condutores isolados em eletroduto de seção circular embutido em parede termicamente isolante'),
    ('A2', 'Cabo multipolar em eletroduto de seção circular embutido em parede termicamente isolante'),
    ('B1', 'Condutores isolados em eletroduto sobre parede ou espaçado desta'),
    ('B2', 'Cabo multipolar em eletroduto sobre parede ou espaçado desta'),
    ('C',  'Cabos unipolares ou cabo multipolar sobre parede ou espaçado desta'),
    ('D',  'Cabo em eletroduto enterrado no solo'),
    ('E',  'Cabo multipolar ao ar livre'),
    ('F',  'Cabos unipolares justapostos (horizontal, vertical ou trifólio) ao ar livre'),
    ('G',  'Cabos unipolares espaçados ao ar livre');

INSERT INTO categoria_cabo (nome) VALUES
    ('Condutor Isolado'),
    ('Cabo Unipolar'),
    ('Cabo Multipolar');

INSERT INTO grupo_termico (nome, temp_operacao_c, temp_sobrecarga_c) VALUES
    ('70°C',  70, 100),
    ('90°C',  90, 130);

-- Fabricantes cujos catálogos alimentam (ou vão alimentar) o schema — ver docs/adr/0010.
-- Só Prysmian tem produtos carregados neste arquivo; os demais existem como
-- referência para quando seus catálogos forem transcritos.
INSERT INTO fabricante (nome) VALUES
    ('Prysmian'),
    ('Nexans'),
    ('Alubar Coppertec'),
    ('Induscabos');

-- Material de isolação: identidade técnica independente de fabricante (docs/adr/0010).
-- temp_curto_circuito_c é o valor "padrão" da NBR 5410 Tabela 35 para o material;
-- exceções por faixa de seção (ex.: PVC >300mm² = 140°C) ficam em fator_k_curto_circuito.
INSERT INTO material_isolacao (nome, grupo_termico_id, temp_curto_circuito_c)
SELECT v.nome, gt.id, v.temp_curto_circuito_c
FROM (VALUES
    ('PVC',    '70°C', 160),
    ('LSHF-A', '70°C', 160),
    ('EPR',    '90°C', 250),
    ('XLPE',   '90°C', 250),
    ('HEPR',   '90°C', 250)
) AS v(nome, grupo_termico_nome, temp_curto_circuito_c)
JOIN grupo_termico gt ON gt.nome = v.grupo_termico_nome;

-- 'Nenhuma' é sentinela para condutor isolado sem cobertura — material_cobertura_id
-- em cabos é NOT NULL justamente para poder participar do UNIQUE de identidade
-- (NULL nunca é igual a NULL numa constraint UNIQUE, o que quebraria a dedup).
INSERT INTO material_cobertura (nome) VALUES
    ('PVC'),
    ('SHF1'),
    ('Nenhuma');

INSERT INTO grupo_construtivo (nome) VALUES
    ('Superastic'),
    ('Superastic Flex / Afumex Green'),
    ('Sintenax'),
    ('Sintenax Flex'),
    ('GSette Easy / Afumex Flex'),
    ('Voltenax / Voltalene');

-- unipolar_justaposto_par cobre o caso de 2 condutores carregados (2 cabos unipolares
-- lado a lado) e unipolar_espacado_quadrado cobre o arranjo em quadrado (3 unipolares,
-- s=20cm nos dois eixos) das Tabelas 30-33/35-36 do guia — faltavam na modelagem
-- original; ver docs/adr/0012.
INSERT INTO arranjo_ampacidade (codigo, descricao) VALUES
    ('multipolar_justaposto',            'Cabo multipolar, condutores carregados justapostos (método E; também usado por resistencia_reatancia_ca para o cabo multipolar de 2 ou 3 núcleos das Tabelas 28-36)'),
    ('unipolar_justaposto_par',          'Dois cabos unipolares carregados, justapostos lado a lado (método F, 2 condutores carregados)'),
    ('unipolar_justaposto_trifolio',     'Cabos unipolares justapostos, dispostos em trifólio (método F)'),
    ('unipolar_justaposto_plano',        'Cabos unipolares justapostos, no mesmo plano (método F)'),
    ('unipolar_espacado_horizontal',     'Cabos unipolares espaçados, dispostos na horizontal (método G)'),
    ('unipolar_espacado_vertical',       'Cabos unipolares espaçados, dispostos na vertical (método G)'),
    ('unipolar_espacado_quadrado',       'Três cabos unipolares carregados, dispostos em arranjo quadrado (s=20cm nos dois eixos) — só usado por resistencia_reatancia_ca (Tabelas 30-33/35-36 do guia)');

INSERT INTO arranjo_espacamento (codigo, descricao) VALUES
    ('encostado', 'Condutores/cabos encostados (sem espaçamento)'),
    ('s_2d',      'Espaçamento s = 2 x diâmetro do condutor (D)'),
    ('s_13cm',    'Espaçamento s = 13 cm entre eixos'),
    ('s_20cm',    'Espaçamento s = 20 cm entre eixos');

INSERT INTO classe_encordoamento (nome) VALUES
    ('Classe 2 (compactado ou não)'),
    ('Classe 5 (flexível)');

-- NBR 5410:2004 §6.2.5.6.1, Tabela 46
INSERT INTO tipo_circuito (codigo, tipo_corrente, numero_fases, tem_neutro, tem_protecao_pe, tem_blindagem, numero_condutores_carregados, permite_quarto_condutor, fator_correcao_neutro_carregado, formula_queda_tensao) VALUES
    ('F',       'CA', 1,    FALSE, FALSE, FALSE, 2, FALSE, NULL, 'monofasica_bifasica'),
    ('F+N',     'CA', 1,    TRUE,  FALSE, FALSE, 2, FALSE, NULL, 'monofasica_bifasica'),
    ('F+N+T',   'CA', 1,    TRUE,  TRUE,  FALSE, 2, FALSE, NULL, 'monofasica_bifasica'),
    ('2F',      'CA', 2,    FALSE, FALSE, FALSE, 2, FALSE, NULL, 'monofasica_bifasica'),
    ('2F+N',    'CA', 2,    TRUE,  FALSE, FALSE, 3, FALSE, NULL, 'monofasica_bifasica'),
    ('2F+T',    'CA', 2,    FALSE, TRUE,  FALSE, 2, FALSE, NULL, 'monofasica_bifasica'),
    ('2F+N+T',  'CA', 2,    TRUE,  TRUE,  FALSE, 3, FALSE, NULL, 'monofasica_bifasica'),
    ('3F',      'CA', 3,    FALSE, FALSE, FALSE, 3, FALSE, NULL, 'trifasica'),
    ('3F+N',    'CA', 3,    TRUE,  FALSE, FALSE, 3, TRUE,  0.86, 'trifasica'),
    ('3F+T',    'CA', 3,    FALSE, TRUE,  FALSE, 3, FALSE, NULL, 'trifasica'),
    ('3F+N+T',  'CA', 3,    TRUE,  TRUE,  FALSE, 3, TRUE,  0.86, 'trifasica'),
    ('3F+sh',   'CA', 3,    FALSE, FALSE, TRUE,  3, FALSE, NULL, 'trifasica'),
    ('CC-2',    'CC', NULL, FALSE, FALSE, FALSE, 2, FALSE, NULL, 'monofasica_bifasica'),
    ('CC-3',    'CC', NULL, TRUE,  FALSE, FALSE, 3, FALSE, NULL, 'monofasica_bifasica');
COMMENT ON TABLE tipo_circuito IS 'Ver comentário na criação da tabela. Dados: NBR 5410:2004 Tabela 46, decomposta em campos ortogonais (tipo_corrente, numero_fases, tem_neutro, tem_protecao_pe, tem_blindagem) para cobrir também variantes de projeto reais (com PE, com blindagem/"sh") que a Tabela 46 não nomeia. "3F+N" e "3F+N+T" são os únicos com permite_quarto_condutor=TRUE e fator_correcao_neutro_carregado preenchido (THD do neutro > 15%, §6.2.5.6.1) — tem_protecao_pe/tem_blindagem nunca mudam numero_condutores_carregados, por não serem condutores vivos.';

-- NBR 5410:2004 Tabela 47
INSERT INTO finalidade_circuito (nome) VALUES
    ('Iluminação'),
    ('Força'),
    ('Sinalização e Controle'),
    ('Extrabaixa Tensão para Aplicações Especiais');

-- NBR 5410:2004 §6.2.3.7/6.2.3.8 — restrições ao uso de condutor de alumínio
INSERT INTO restricao_material_condutor (material_condutor_id, contexto, secao_minima_mm2, permitido, condicao_desc)
SELECT m.id, v.contexto, v.secao_minima_mm2, v.permitido, v.condicao_desc
FROM (VALUES
    ('industrial',  16::numeric, TRUE,  'Alimentação direta por subestação/transformador próprio (rede de AT) ou fonte própria; instalação e manutenção por pessoal qualificado (§6.2.3.8.1)'),
    ('comercial',   50::numeric, TRUE,  'Locais exclusivamente BD1 (baixa densidade de ocupação, percurso de fuga breve, altura < 28 m); instalação e manutenção por pessoal qualificado (§6.2.3.8.2)'),
    ('residencial', NULL::numeric, FALSE, 'Proibido em qualquer hipótese (§6.2.3.7 / guia Prysmian §2.3)'),
    ('bd4',         NULL::numeric, FALSE, 'Locais de alta densidade de ocupação e percurso de fuga longo — proibido em nenhuma circunstância (§6.2.3.8.3)')
) AS v(contexto, secao_minima_mm2, permitido, condicao_desc)
JOIN material_condutor m ON m.nome = 'Alumínio';


-- =====================================================================
-- 2. CABOS E MÉTODOS DE INSTALAÇÃO — migração dos dados já existentes
-- =====================================================================

-- cabos é especificação técnica genérica: material_isolacao + material_cobertura +
-- tensao_isolamento + classe_encordoamento identificam a linha, NUNCA fabricante ou
-- nome comercial (ver docs/adr/0011). GSette Easy (Prysmian) e HEPR-PVC 0,6/1kV
-- (Nexans) são a MESMA especificação (HEPR/PVC/0,6-1kV/Classe 5) — geram 1 única
-- linha aqui; a distinção "quem vende com qual nome" fica em produto_comercial.
INSERT INTO cabos (norma_abnt, tensao_isolamento, material_isolacao_id, material_cobertura_id, classe_encordoamento_id, grupo_construtivo_id)
SELECT v.norma_abnt, v.tensao_isolamento, mi.id, mc.id, ce.id, gc.id
FROM (VALUES
    ('NBR NM 247-3', '450/750 V', 'PVC',    'Nenhuma', 'Classe 2 (compactado ou não)', 'Superastic'),
    ('NBR NM 247-3', '450/750 V', 'PVC',    'Nenhuma', 'Classe 5 (flexível)',          'Superastic Flex / Afumex Green'),
    ('NBR 13248',    '450/750 V', 'LSHF-A', 'Nenhuma', 'Classe 5 (flexível)',          'Superastic Flex / Afumex Green'),
    ('NBR 7288',     '0,6/1 kV',  'PVC',    'PVC',     'Classe 2 (compactado ou não)', 'Sintenax'),
    ('NBR 7288',     '0,6/1 kV',  'PVC',    'PVC',     'Classe 5 (flexível)',          'Sintenax Flex'),
    ('NBR 7286',     '0,6/1 kV',  'HEPR',   'PVC',     'Classe 5 (flexível)',          'GSette Easy / Afumex Flex'),
    ('NBR 7285',     '0,6/1 kV',  'XLPE',   'Nenhuma', 'Classe 2 (compactado ou não)', 'Voltenax / Voltalene'),
    ('NBR 7287',     '0,6/1 kV',  'XLPE',   'PVC',     'Classe 2 (compactado ou não)', 'Voltenax / Voltalene'),
    ('NBR 13248',    '0,6/1 kV',  'HEPR',   'SHF1',    'Classe 5 (flexível)',          'GSette Easy / Afumex Flex')
) AS v(norma_abnt, tensao_isolamento, material_isolacao_nome, material_cobertura_nome, classe_encordoamento_nome, grupo_construtivo_nome)
JOIN material_isolacao mi ON mi.nome = v.material_isolacao_nome
JOIN material_cobertura mc ON mc.nome = v.material_cobertura_nome
JOIN classe_encordoamento ce ON ce.nome = v.classe_encordoamento_nome
JOIN grupo_construtivo gc ON gc.nome = v.grupo_construtivo_nome;

-- Rastreabilidade de fabricante/nome comercial, fora do caminho de cálculo (ADR 0011).
-- Nexans/'HEPR-PVC 0,6/1kV' resolve para a MESMA linha de cabos que Prysmian/'GSette Easy'.
INSERT INTO produto_comercial (fabricante_id, nome_comercial, cabo_id)
SELECT f.id, v.nome_comercial, c.id
FROM (VALUES
    ('Prysmian', 'Superastic',        'PVC',    'Nenhuma', 'Classe 2 (compactado ou não)', '450/750 V'),
    ('Prysmian', 'Superastic Flex',   'PVC',    'Nenhuma', 'Classe 5 (flexível)',          '450/750 V'),
    ('Prysmian', 'Afumex Green',      'LSHF-A', 'Nenhuma', 'Classe 5 (flexível)',          '450/750 V'),
    ('Prysmian', 'Sintenax',          'PVC',    'PVC',     'Classe 2 (compactado ou não)', '0,6/1 kV'),
    ('Prysmian', 'Sintenax Flex',     'PVC',    'PVC',     'Classe 5 (flexível)',          '0,6/1 kV'),
    ('Prysmian', 'GSette Easy',       'HEPR',   'PVC',     'Classe 5 (flexível)',          '0,6/1 kV'),
    ('Prysmian', 'Voltalene',         'XLPE',   'Nenhuma', 'Classe 2 (compactado ou não)', '0,6/1 kV'),
    ('Prysmian', 'Voltenax',          'XLPE',   'PVC',     'Classe 2 (compactado ou não)', '0,6/1 kV'),
    ('Prysmian', 'Afumex Flex',       'HEPR',   'SHF1',    'Classe 5 (flexível)',          '0,6/1 kV'),
    ('Nexans',   'HEPR-PVC 0,6/1kV',  'HEPR',   'PVC',     'Classe 5 (flexível)',          '0,6/1 kV')
) AS v(fabricante_nome, nome_comercial, material_isolacao_nome, material_cobertura_nome, classe_encordoamento_nome, tensao_isolamento)
JOIN fabricante f ON f.nome = v.fabricante_nome
JOIN material_isolacao mi ON mi.nome = v.material_isolacao_nome
JOIN material_cobertura mc ON mc.nome = v.material_cobertura_nome
JOIN classe_encordoamento ce ON ce.nome = v.classe_encordoamento_nome
JOIN cabos c ON c.material_isolacao_id = mi.id AND c.material_cobertura_id = mc.id
    AND c.classe_encordoamento_id = ce.id AND c.tensao_isolamento = v.tensao_isolamento;

-- Normaliza cabos.numero_condutores (texto) em 1 linha por variante, com a
-- categoria correta (guia Prysmian Tabela 6): numero_condutores=1 é sempre
-- "Condutor Isolado" para a família 450/750V (Superastic/Superastic Flex/
-- Afumex Green), e "Cabo Unipolar" para as demais (0,6/1kV); numero_condutores>1
-- é sempre "Cabo Multipolar". Referencia cabos pela tupla genérica, não por
-- tipo_cabo/fabricante (ver docs/adr/0011) — por isso GSette Easy e o HEPR-PVC
-- da Nexans resolvem para a mesma linha (HEPR, PVC, 0,6/1kV, Classe 5) sem
-- duplicar os 5 INSERTs correspondentes.
INSERT INTO cabo_numero_condutores (cabo_id, numero_condutores, categoria_cabo_id)
SELECT c.id, v.numero_condutores, cat.id
FROM (VALUES
    ('PVC',    'Nenhuma', 'Classe 2 (compactado ou não)', '450/750 V', 1),
    ('PVC',    'Nenhuma', 'Classe 5 (flexível)',          '450/750 V', 1),
    ('LSHF-A', 'Nenhuma', 'Classe 5 (flexível)',          '450/750 V', 1),
    ('PVC',    'PVC',     'Classe 2 (compactado ou não)', '0,6/1 kV',  1),
    ('PVC',    'PVC',     'Classe 2 (compactado ou não)', '0,6/1 kV',  2),
    ('PVC',    'PVC',     'Classe 2 (compactado ou não)', '0,6/1 kV',  3),
    ('PVC',    'PVC',     'Classe 2 (compactado ou não)', '0,6/1 kV',  4),
    ('PVC',    'PVC',     'Classe 2 (compactado ou não)', '0,6/1 kV',  5),
    ('PVC',    'PVC',     'Classe 5 (flexível)',          '0,6/1 kV',  1),
    ('PVC',    'PVC',     'Classe 5 (flexível)',          '0,6/1 kV',  2),
    ('PVC',    'PVC',     'Classe 5 (flexível)',          '0,6/1 kV',  3),
    ('PVC',    'PVC',     'Classe 5 (flexível)',          '0,6/1 kV',  4),
    ('PVC',    'PVC',     'Classe 5 (flexível)',          '0,6/1 kV',  5),
    ('HEPR',   'PVC',     'Classe 5 (flexível)',          '0,6/1 kV',  1),
    ('HEPR',   'PVC',     'Classe 5 (flexível)',          '0,6/1 kV',  2),
    ('HEPR',   'PVC',     'Classe 5 (flexível)',          '0,6/1 kV',  3),
    ('HEPR',   'PVC',     'Classe 5 (flexível)',          '0,6/1 kV',  4),
    ('HEPR',   'PVC',     'Classe 5 (flexível)',          '0,6/1 kV',  5),
    ('XLPE',   'Nenhuma', 'Classe 2 (compactado ou não)', '0,6/1 kV',  1),
    ('XLPE',   'Nenhuma', 'Classe 2 (compactado ou não)', '0,6/1 kV',  3),
    ('XLPE',   'PVC',     'Classe 2 (compactado ou não)', '0,6/1 kV',  1),
    ('XLPE',   'PVC',     'Classe 2 (compactado ou não)', '0,6/1 kV',  2),
    ('XLPE',   'PVC',     'Classe 2 (compactado ou não)', '0,6/1 kV',  3),
    ('XLPE',   'PVC',     'Classe 2 (compactado ou não)', '0,6/1 kV',  4),
    ('XLPE',   'PVC',     'Classe 2 (compactado ou não)', '0,6/1 kV',  5),
    ('HEPR',   'SHF1',    'Classe 5 (flexível)',          '0,6/1 kV',  1),
    ('HEPR',   'SHF1',    'Classe 5 (flexível)',          '0,6/1 kV',  2),
    ('HEPR',   'SHF1',    'Classe 5 (flexível)',          '0,6/1 kV',  3),
    ('HEPR',   'SHF1',    'Classe 5 (flexível)',          '0,6/1 kV',  4),
    ('HEPR',   'SHF1',    'Classe 5 (flexível)',          '0,6/1 kV',  5)
) AS v(material_isolacao_nome, material_cobertura_nome, classe_encordoamento_nome, tensao_isolamento, numero_condutores)
JOIN material_isolacao mi ON mi.nome = v.material_isolacao_nome
JOIN material_cobertura mc ON mc.nome = v.material_cobertura_nome
JOIN classe_encordoamento ce ON ce.nome = v.classe_encordoamento_nome
JOIN cabos c ON c.material_isolacao_id = mi.id AND c.material_cobertura_id = mc.id
    AND c.classe_encordoamento_id = ce.id AND c.tensao_isolamento = v.tensao_isolamento
JOIN categoria_cabo cat ON cat.nome = CASE
    WHEN v.tensao_isolamento = '450/750 V' THEN 'Condutor Isolado'
    WHEN v.numero_condutores = 1 THEN 'Cabo Unipolar'
    ELSE 'Cabo Multipolar'
END;

INSERT INTO metodo_instalacao (tipo_linha_eletrica) VALUES
    ('Eletroduto embutido em parede isolante'),
    ('Embutimento direto em parede isolante'),
    ('Moldura'),
    ('Eletroduto embutido em caixilho de porta ou janela'),
    ('Embutimento direto em caixilho de porta ou janela'),
    ('Eletroduto aparente'),
    ('Eletroduto embutido em alvenaria'),
    ('Diretamente em espaço de construção - 1,5De ≤ V < 5De'),
    ('Diretamente em espaço de construção - 5De ≤ V < 50De'),
    ('Eletroduto em espaço de construção - 1,5De ≤ V < 5De'),
    ('Eletroduto em espaço de construção - V ≥ 20De'),
    ('Eletroduto em espaço de construção'),
    ('Eletroduto de seção não circular embutido em alvenaria - 1,5De ≤ V < 5De'),
    ('Eletroduto de seção não circular embutido em alvenaria - 5De ≤ V < 50De'),
    ('Eletroduto de seção não circular embutido em alvenaria'),
    ('Forro falso ou piso elevado - 1,5De ≤ V < 5De'),
    ('Forro falso ou piso elevado - 5De ≤ V < 50De'),
    ('Eletrocalha'),
    ('Canaleta fechada no piso, solo ou parede'),
    ('Eletroduto em canaleta fechada - 1,5De ≤ V < 20De'),
    ('Eletroduto em canaleta fechada - V ≥ 20De'),
    ('Eletroduto em canaleta ventilada no piso ou solo'),
    ('Canaleta ventilada no piso ou solo'),
    ('Fixação direta à parede ou teto'),
    ('Bandejas não perfuradas ou prateleiras'),
    ('Embutimento direto em alvenaria'),
    ('Eletroduto enterrado no solo ou canaleta não ventilada no solo'),
    ('Diretamente enterrado'),
    ('Bandejas perfuradas (horizontal ou vertical)'),
    ('Leitos, suportes horizontais ou telas'),
    ('Afastado da parede ou suspenso por cabo de suporte'),
    ('Sobre isoladores');

-- Normaliza metodo_instalacao.numero_metodo (texto, ex. '31/31A/32/32A/35/36')
-- em 1 linha por código individual da Tabela 33 da NBR 5410.
INSERT INTO metodo_instalacao_numero (metodo_instalacao_id, codigo)
SELECT mi.id, unnest(string_to_array(v.numeros, '/'))
FROM (VALUES
    ('Eletroduto embutido em parede isolante',                                          '1/2'),
    ('Embutimento direto em parede isolante',                                           '51'),
    ('Moldura',                                                                         '71'),
    ('Eletroduto embutido em caixilho de porta ou janela',                              '73/74'),
    ('Embutimento direto em caixilho de porta ou janela',                               '73/74'),
    ('Eletroduto aparente',                                                             '3/4/5/6'),
    ('Eletroduto embutido em alvenaria',                                                '7/8'),
    ('Diretamente em espaço de construção - 1,5De ≤ V < 5De',                          '21'),
    ('Diretamente em espaço de construção - 5De ≤ V < 50De',                           '21'),
    ('Eletroduto em espaço de construção - 1,5De ≤ V < 5De',                           '22/24'),
    ('Eletroduto em espaço de construção - V ≥ 20De',                                  '22/24'),
    ('Eletroduto em espaço de construção',                                              '23/25'),
    ('Eletroduto de seção não circular embutido em alvenaria - 1,5De ≤ V < 5De',       '26'),
    ('Eletroduto de seção não circular embutido em alvenaria - 5De ≤ V < 50De',        '26'),
    ('Eletroduto de seção não circular embutido em alvenaria',                          '27'),
    ('Forro falso ou piso elevado - 1,5De ≤ V < 5De',                                  '28'),
    ('Forro falso ou piso elevado - 5De ≤ V < 50De',                                   '28'),
    ('Eletrocalha',                                                                     '31/31A/32/32A/35/36'),
    ('Canaleta fechada no piso, solo ou parede',                                        '33/34/72/72A/75/75A'),
    ('Eletroduto em canaleta fechada - 1,5De ≤ V < 20De',                              '41'),
    ('Eletroduto em canaleta fechada - V ≥ 20De',                                      '41'),
    ('Eletroduto em canaleta ventilada no piso ou solo',                                '42'),
    ('Canaleta ventilada no piso ou solo',                                              '43'),
    ('Fixação direta à parede ou teto',                                                 '11/11A/11B'),
    ('Bandejas não perfuradas ou prateleiras',                                          '12'),
    ('Embutimento direto em alvenaria',                                                 '52/53'),
    ('Eletroduto enterrado no solo ou canaleta não ventilada no solo',                  '61/61A'),
    ('Diretamente enterrado',                                                           '63'),
    ('Bandejas perfuradas (horizontal ou vertical)',                                    '13'),
    ('Leitos, suportes horizontais ou telas',                                           '14/16'),
    ('Afastado da parede ou suspenso por cabo de suporte',                              '15/17'),
    ('Sobre isoladores',                                                                '18')
) AS v(tipo_linha_eletrica, numeros)
JOIN metodo_instalacao mi ON mi.tipo_linha_eletrica = v.tipo_linha_eletrica;

-- Normaliza as 3 colunas ref_condutor_isolado/ref_cabo_unipolar/ref_cabo_multipolar
-- (Tabela 33 da NBR 5410) em (método de instalação, categoria de cabo, método de referência).
INSERT INTO metodo_instalacao_referencia (metodo_instalacao_id, categoria_cabo_id, metodo_referencia_id)
SELECT mi.id, cat.id, mr.id
FROM (VALUES
    ('Eletroduto embutido em parede isolante',                                          'Condutor Isolado',  'A1'),
    ('Eletroduto embutido em parede isolante',                                          'Cabo Unipolar',     'A1'),
    ('Eletroduto embutido em parede isolante',                                          'Cabo Multipolar',   'A2'),
    ('Embutimento direto em parede isolante',                                           'Cabo Multipolar',   'A1'),
    ('Moldura',                                                                         'Condutor Isolado',  'A1'),
    ('Moldura',                                                                         'Cabo Unipolar',     'A1'),
    ('Eletroduto embutido em caixilho de porta ou janela',                              'Condutor Isolado',  'A1'),
    ('Embutimento direto em caixilho de porta ou janela',                               'Cabo Unipolar',     'A1'),
    ('Embutimento direto em caixilho de porta ou janela',                               'Cabo Multipolar',   'A1'),
    ('Eletroduto aparente',                                                             'Condutor Isolado',  'B1'),
    ('Eletroduto aparente',                                                             'Cabo Unipolar',     'B1'),
    ('Eletroduto aparente',                                                             'Cabo Multipolar',   'B2'),
    ('Eletroduto embutido em alvenaria',                                                'Condutor Isolado',  'B1'),
    ('Eletroduto embutido em alvenaria',                                                'Cabo Unipolar',     'B1'),
    ('Eletroduto embutido em alvenaria',                                                'Cabo Multipolar',   'B2'),
    ('Diretamente em espaço de construção - 1,5De ≤ V < 5De',                          'Cabo Unipolar',     'B2'),
    ('Diretamente em espaço de construção - 1,5De ≤ V < 5De',                          'Cabo Multipolar',   'B2'),
    ('Diretamente em espaço de construção - 5De ≤ V < 50De',                           'Cabo Unipolar',     'B1'),
    ('Diretamente em espaço de construção - 5De ≤ V < 50De',                           'Cabo Multipolar',   'B1'),
    ('Eletroduto em espaço de construção - 1,5De ≤ V < 5De',                           'Condutor Isolado',  'B2'),
    ('Eletroduto em espaço de construção - V ≥ 20De',                                  'Condutor Isolado',  'B1'),
    ('Eletroduto em espaço de construção',                                              'Cabo Unipolar',     'B2'),
    ('Eletroduto em espaço de construção',                                              'Cabo Multipolar',   'B2'),
    ('Eletroduto de seção não circular embutido em alvenaria - 1,5De ≤ V < 5De',       'Condutor Isolado',  'B2'),
    ('Eletroduto de seção não circular embutido em alvenaria - 5De ≤ V < 50De',        'Condutor Isolado',  'B1'),
    ('Eletroduto de seção não circular embutido em alvenaria',                          'Cabo Unipolar',     'B2'),
    ('Eletroduto de seção não circular embutido em alvenaria',                          'Cabo Multipolar',   'B2'),
    ('Forro falso ou piso elevado - 1,5De ≤ V < 5De',                                  'Cabo Unipolar',     'B2'),
    ('Forro falso ou piso elevado - 1,5De ≤ V < 5De',                                  'Cabo Multipolar',   'B2'),
    ('Forro falso ou piso elevado - 5De ≤ V < 50De',                                   'Cabo Unipolar',     'B1'),
    ('Forro falso ou piso elevado - 5De ≤ V < 50De',                                   'Cabo Multipolar',   'B1'),
    ('Eletrocalha',                                                                     'Condutor Isolado',  'B1'),
    ('Eletrocalha',                                                                     'Cabo Unipolar',     'B1'),
    ('Eletrocalha',                                                                     'Cabo Multipolar',   'B2'),
    ('Canaleta fechada no piso, solo ou parede',                                        'Condutor Isolado',  'B1'),
    ('Canaleta fechada no piso, solo ou parede',                                        'Cabo Unipolar',     'B1'),
    ('Canaleta fechada no piso, solo ou parede',                                        'Cabo Multipolar',   'B2'),
    ('Eletroduto em canaleta fechada - 1,5De ≤ V < 20De',                              'Condutor Isolado',  'B2'),
    ('Eletroduto em canaleta fechada - 1,5De ≤ V < 20De',                              'Cabo Unipolar',     'B2'),
    ('Eletroduto em canaleta fechada - V ≥ 20De',                                      'Condutor Isolado',  'B1'),
    ('Eletroduto em canaleta fechada - V ≥ 20De',                                      'Cabo Unipolar',     'B1'),
    ('Eletroduto em canaleta ventilada no piso ou solo',                                'Condutor Isolado',  'B1'),
    ('Canaleta ventilada no piso ou solo',                                              'Cabo Unipolar',     'B1'),
    ('Canaleta ventilada no piso ou solo',                                              'Cabo Multipolar',   'B1'),
    ('Fixação direta à parede ou teto',                                                 'Cabo Unipolar',     'C'),
    ('Fixação direta à parede ou teto',                                                 'Cabo Multipolar',   'C'),
    ('Bandejas não perfuradas ou prateleiras',                                          'Cabo Unipolar',     'C'),
    ('Bandejas não perfuradas ou prateleiras',                                          'Cabo Multipolar',   'C'),
    ('Embutimento direto em alvenaria',                                                 'Cabo Unipolar',     'C'),
    ('Embutimento direto em alvenaria',                                                 'Cabo Multipolar',   'C'),
    ('Eletroduto enterrado no solo ou canaleta não ventilada no solo',                  'Cabo Unipolar',     'D'),
    ('Eletroduto enterrado no solo ou canaleta não ventilada no solo',                  'Cabo Multipolar',   'D'),
    ('Diretamente enterrado',                                                           'Cabo Unipolar',     'D'),
    ('Diretamente enterrado',                                                           'Cabo Multipolar',   'D'),
    ('Bandejas perfuradas (horizontal ou vertical)',                                    'Cabo Unipolar',     'F'),
    ('Bandejas perfuradas (horizontal ou vertical)',                                    'Cabo Multipolar',   'E'),
    ('Leitos, suportes horizontais ou telas',                                           'Cabo Unipolar',     'F'),
    ('Leitos, suportes horizontais ou telas',                                           'Cabo Multipolar',   'E'),
    ('Afastado da parede ou suspenso por cabo de suporte',                              'Cabo Unipolar',     'F'),
    ('Afastado da parede ou suspenso por cabo de suporte',                              'Cabo Multipolar',   'E'),
    ('Sobre isoladores',                                                                'Condutor Isolado',  'G'),
    ('Sobre isoladores',                                                                'Cabo Unipolar',     'G')
) AS v(tipo_linha_eletrica, categoria_nome, metodo_ref_codigo)
JOIN metodo_instalacao mi ON mi.tipo_linha_eletrica = v.tipo_linha_eletrica
JOIN categoria_cabo cat ON cat.nome = v.categoria_nome
JOIN metodo_referencia mr ON mr.codigo = v.metodo_ref_codigo;

-- ============================================================
-- cabos_metodo_instalacao NÃO EXISTE MAIS (ver docs/adr/0010).
-- Quais métodos de instalação um cabo específico suporta é 100%
-- derivável a partir de categoria_cabo (que já é genérica, independente
-- de fabricante) — verificado linha a linha contra os dados que existiam
-- aqui antes da remoção (ex.: os 15 pares do Superastic batiam exatamente
-- com os 15 métodos de "Condutor Isolado" abaixo). Exemplo de consulta
-- equivalente para o Sintenax (Prysmian), variante de 3 condutores:
--
-- SELECT DISTINCT mi.tipo_linha_eletrica
-- FROM produto_comercial pc
-- JOIN cabo_numero_condutores cnc ON cnc.cabo_id = pc.cabo_id AND cnc.numero_condutores = 3
-- JOIN metodo_instalacao_referencia mir ON mir.categoria_cabo_id = cnc.categoria_cabo_id
-- JOIN metodo_instalacao mi ON mi.id = mir.metodo_instalacao_id
-- WHERE pc.nome_comercial = 'Sintenax';
-- ============================================================


-- =====================================================================
-- 3. SEÇÕES MÍNIMAS — exemplos (NBR 5410 Tabelas 47/48/58)
-- =====================================================================

-- NBR 5410:2004 Tabela 47 discrimina 3 categorias de linha (ver tipo_linha_secao_minima).
-- A norma só tabela alumínio para iluminação e força — não há valor de alumínio para
-- sinalização e controle, nem em condutores isolados nem em condutores nus (consistente
-- com restricao_material_condutor: as seções desses circuitos são muito inferiores aos
-- mínimos de 16/50 mm² exigidos para alumínio em §6.2.3.7/6.2.3.8).
INSERT INTO tipo_linha_secao_minima (nome) VALUES
    ('Condutores e cabos isolados'),
    ('Condutores nus'),
    ('Linhas flexíveis com cabos isolados');

INSERT INTO secao_minima_condutor (finalidade_circuito_id, tipo_linha_secao_minima_id, material_condutor_id, secao_minima_mm2, observacao)
SELECT fc.id, tl.id, mc.id, v.secao_minima_mm2, v.observacao
FROM (VALUES
    ('Iluminação',              'Condutores e cabos isolados', 'Cobre',    1.5, NULL),
    ('Iluminação',              'Condutores e cabos isolados', 'Alumínio', 16,  NULL),
    ('Força',                   'Condutores e cabos isolados', 'Cobre',    2.5, 'Circuitos de tomadas de corrente são considerados circuitos de força'),
    ('Força',                   'Condutores e cabos isolados', 'Alumínio', 16,  'Circuitos de tomadas de corrente são considerados circuitos de força'),
    ('Sinalização e Controle',  'Condutores e cabos isolados', 'Cobre',    0.5, 'Admite-se 0,1 mm² para equipamentos eletrônicos'),
    ('Força',                   'Condutores nus',               'Cobre',    10,  NULL),
    ('Força',                   'Condutores nus',               'Alumínio', 16,  NULL),
    ('Sinalização e Controle',  'Condutores nus',               'Cobre',    4,   NULL)
) AS v(finalidade_nome, tipo_linha_nome, material_nome, secao_minima_mm2, observacao)
JOIN finalidade_circuito fc ON fc.nome = v.finalidade_nome
JOIN tipo_linha_secao_minima tl ON tl.nome = v.tipo_linha_nome
JOIN material_condutor mc ON mc.nome = v.material_nome;

INSERT INTO secao_minima_neutro (secao_fase_id, secao_neutro_id)
SELECT sf.id, sn.id
FROM (VALUES (35, 25), (50, 25), (70, 35)) AS v(fase_mm2, neutro_mm2)
JOIN secao_nominal sf ON sf.valor_mm2 = v.fase_mm2
JOIN secao_nominal sn ON sn.valor_mm2 = v.neutro_mm2;

INSERT INTO secao_minima_protecao_pe (secao_fase_min_mm2, secao_fase_max_mm2, formula_desc, secao_fixa_mm2) VALUES
    (0,  16,   'S',    NULL),
    (16, 35,   '16',   16),
    (35, NULL, 'S/2',  NULL);


-- =====================================================================
-- 4. AMPACIDADE (NBR 5410 Tabelas 36-39)
-- Carga completa das Tabelas 7-10 do guia Prysmian: ver
-- database/insert_data_ampacidade.sql (executar depois deste arquivo).
-- =====================================================================


-- =====================================================================
-- 5. FATORES DE CORREÇÃO — exemplos (NBR 5410 Tabelas 40-45)
-- =====================================================================

INSERT INTO fator_correcao_temperatura (tipo_instalacao, grupo_termico_id, temperatura_c, fator)
SELECT v.tipo_instalacao, gt.id, v.temperatura_c, v.fator
FROM (VALUES
    ('ambiente', '70°C', 35, 0.94),
    ('ambiente', '90°C', 35, 0.96),
    ('solo',     '70°C', 30, 0.89),
    ('solo',     '90°C', 30, 0.93)
) AS v(tipo_instalacao, grupo_termico_nome, temperatura_c, fator)
JOIN grupo_termico gt ON gt.nome = v.grupo_termico_nome;

INSERT INTO fator_correcao_resistividade_solo (resistividade_km_w, fator_duto_enterrado, fator_diretamente_enterrado) VALUES
    (1,   1.18, 1.50),
    (1.5, 1.10, 1.28),
    (2,   1.05, 1.12),
    (2.5, 1.00, 1.00),
    (3,   0.96, 0.90);

INSERT INTO fator_agrupamento_ar (cenario, circuitos_min, circuitos_max, camadas_min, camadas_max, metodo_instalacao_grupo, fator) VALUES
    ('camada_unica', 1, 1, NULL, NULL, 'A-F',  1.00),
    ('camada_unica', 2, 2, NULL, NULL, 'A-F',  0.80),
    ('camada_unica', 3, 3, NULL, NULL, 'A-F',  0.70),
    ('multicamada',  2, 2, 2, 2, NULL,          0.68),
    ('multicamada',  3, 3, 3, 3, NULL,          0.57);

INSERT INTO fator_agrupamento_enterrado (cenario, numero_circuitos, distancia_desc, fator) VALUES
    ('direto',           2, 'nula (cabos em contato)', 0.75),
    ('direto',           2, '0,25 m',                  0.90),
    ('duto_multipolar',  2, 'nula',                     0.85),
    ('duto_unipolar',    2, 'nula',                     0.80);


-- =====================================================================
-- 6. RESISTÊNCIA / REATÂNCIA (guia Prysmian Tabelas 18, 28-36)
-- Carga completa (resistencia_dc_20c e resistencia_reatancia_ca): ver
-- database/insert_data_resistencia.sql (executar depois deste arquivo).
-- Nota sobre produto_comercial_id: fica NULO (default) para os valores "base"
-- por grupo_construtivo (fonte: guia Prysmian). O produto_comercial
-- Nexans/'HEPR-PVC 0,6/1kV', por exemplo, não tem override (seu catálogo não
-- publica R/XL) e cai no grupo_construtivo 'GSette Easy / Afumex Flex' — o
-- mesmo da linha genérica que compartilha com Prysmian/'GSette Easy'. Ver
-- docs/adr/0010 e 0011.
-- =====================================================================


-- =====================================================================
-- 7. CURTO-CIRCUITO — exemplos (NBR 5410 §5.3.5.5, Tabela 30; §6.4.3.1, Tabelas 53-58)
-- =====================================================================

-- Chaveado por material_isolacao (não por cabo/fabricante): NBR 5410 Tabela 30
-- é normativa, mesmo valor para qualquer fabricante que use o mesmo material
-- de isolação (ver docs/adr/0010).
INSERT INTO fator_k_curto_circuito (material_isolacao_id, material_condutor_id, secao_max_mm2, fator_k, temp_inicial_c, temp_final_c)
SELECT mi.id, mc.id, v.secao_max_mm2, v.fator_k, v.temp_inicial_c, v.temp_final_c
FROM (VALUES
    ('PVC',  'Cobre',    300,  115, 70, 160),
    ('PVC',  'Cobre',    NULL, 103, 70, 140),
    ('HEPR', 'Cobre',    NULL, 143, 90, 250),
    ('HEPR', 'Alumínio', NULL, 94,  90, 250)
) AS v(material_isolacao_nome, material_nome, secao_max_mm2, fator_k, temp_inicial_c, temp_final_c)
JOIN material_isolacao mi ON mi.nome = v.material_isolacao_nome
JOIN material_condutor mc ON mc.nome = v.material_nome;

INSERT INTO fator_k_protecao_pe (cenario, material_condutor_id, isolacao_cobertura_desc, secao_max_mm2, fator_k, condicao_desc)
SELECT v.cenario, mc.id, v.isolacao_desc, v.secao_max_mm2, v.fator_k, v.condicao_desc
FROM (VALUES
    ('isolado_nao_incorporado', 'Cobre', 'PVC ≤300mm²', 300,  143, NULL),
    ('veia_cabo_multipolar',    'Cobre', 'PVC ≤300mm²', 300,  115, NULL),
    ('nu_sem_risco',            'Cobre', 'Nu',          NULL, 228, 'Visível e em áreas restritas')
) AS v(cenario, material_nome, isolacao_desc, secao_max_mm2, fator_k, condicao_desc)
JOIN material_condutor mc ON mc.nome = v.material_nome;
