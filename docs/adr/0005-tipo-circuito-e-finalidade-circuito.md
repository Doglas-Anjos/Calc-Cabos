# 0005 — Tipo de circuito (NBR 5410 Tabela 46) e finalidade de circuito (extensível)

## Status
Aceito.

## Contexto

O usuário pediu explicitamente para o schema selecionar o **tipo de
circuito** (3F, 3F+N, 3F+N+PE etc.) e uma informação de **finalidade do
circuito** (pensando também em um documento futuro sobre motores). O risco
óbvio aqui era inventar uma classificação própria, não rastreável a
nenhuma fonte normativa.

Ao revisar a NBR 5410:2004 §6.2.5.6.1 (motivada também pelo aviso já
existente em `readme.txt`: *"verificar o item 6.2.5.6 que fala a respeito
do condutor neutro"*), confirmou-se que a norma já define exatamente esse
conceito na sua **Tabela 46** — "esquemas de condutores vivos" — com o
número de condutores carregados correspondente:

| Esquema | Nº condutores carregados |
|---|---|
| Monofásico a 2 condutores | 2 |
| Monofásico a 3 condutores | 2 |
| Duas fases sem neutro | 2 |
| Duas fases com neutro | 3 |
| Trifásico sem neutro | 3 |
| Trifásico com neutro | 3 ou 4 |

O caso "3 ou 4" é o cerne do item 6.2.5.6.1: se a 3ª harmônica e múltiplos
dela no neutro ultrapassarem 15% (típico de cargas não-lineares —
retificadores, reatores eletrônicos), o **neutro conta como condutor
carregado** e aplica-se um **fator de correção de 0,86** sobre a
capacidade de condução válida para 3 condutores carregados. Não existe uma
coluna separada "para 4 condutores" nas tabelas de ampacidade da norma —
o efeito é sempre modelado como uma correção sobre o valor de 3 condutores.

## Decisão

`tipo_circuito` é modelado como restatement direto da Tabela 46, não como
invenção do schema:

```
tipo_circuito (
  id,
  codigo,                              -- ex.: 'F', 'F+N', '3F', '3F+N'
  esquema_condutores_vivos,            -- nome do esquema, Tabela 46
  numero_condutores_carregados SMALLINT CHECK IN (2,3),  -- valor-base
  permite_quarto_condutor BOOLEAN DEFAULT FALSE,          -- só TRUE p/ trifásico c/ neutro
  fator_correcao_neutro_carregado NUMERIC DEFAULT 0.86,   -- §6.2.5.6.1
  formula_queda_tensao CHECK IN ('monofasica_bifasica','trifasica')
)
```

A decisão de **aplicar ou não** o fator de correção (se o THD medido/
estimado do neutro passa de 15%) fica para quem consome o banco — o schema
só guarda o fator normativo, não decide a condição de aplicação.

`finalidade_circuito` (Iluminação, Força, Sinalização e Controle,
Extrabaixa Tensão) é mantida **enxuta e extensível de propósito**: é a
base usada por `secao_minima_condutor` (Tabela 47 da norma) hoje, e o
design deliberadamente não antecipa a estrutura de um circuito de motor
(torque de partida, categoria de utilização etc.) — isso fica para quando
o documento sobre motores for incorporado, evitando sobre-projetar em cima
de um requisito ainda não especificado.

## Consequências

- `tipo_circuito` é populado com todas as linhas da Tabela 46 de uma vez
  (é uma lookup normativa pequena e fixa, não um dado a importar aos
  poucos) — ver `database/insert_data.sql`.
- Qualquer cálculo de ampacidade/queda de tensão que precise saber "2 ou 3
  condutores carregados" consulta `tipo_circuito`, não reimplementa a
  tabela em código de aplicação.
- `finalidade_circuito` ganhará linhas novas (motor, por categoria de
  utilização) sem exigir migração de schema quando o documento de motores
  chegar — é só uma tabela de lookup, adicionar linha não quebra FK
  existente.

## Atualização — `fator_correcao_neutro_carregado` nulável + Anexo F (harmônicas)

Revisão apontou uma inconsistência na primeira versão desta tabela: a
coluna `fator_correcao_neutro_carregado` estava `NOT NULL DEFAULT 0.86`,
ou seja, **toda** linha (inclusive F, F+N, 2F, CC etc.) recebia o valor
0,86, mesmo em esquemas onde o conceito de "4º condutor" nem existe. O
fator só tem sentido para o esquema trifásico com neutro
(`permite_quarto_condutor = TRUE`) — é a única linha da Tabela 46 em que a
norma prevê o neutro contando como condutor carregado adicional.

Correção aplicada em `database/create_table.sql`:
- `fator_correcao_neutro_carregado` passou a ser **nulável** (sem
  `DEFAULT`).
- Adicionado `CHECK (fator_correcao_neutro_carregado IS NULL OR
  permite_quarto_condutor)` na tabela, impondo no banco — não só por
  convenção — que o fator só pode estar preenchido quando
  `permite_quarto_condutor = TRUE`.
- `database/insert_data.sql` foi ajustado: só a linha `'3F+N'` recebe
  `0.86`; as demais 7 linhas recebem `NULL`.

### Harmônicas e dimensionamento do neutro (Anexo F, informativo)

Ponto relacionado, levantado ao revisar esta tabela: além do fator 0,86 de
§6.2.5.6.1 (que trata do neutro *contando* como condutor carregado), a
NBR 5410:2004 tem um mecanismo separado para quando as harmônicas de
ordem 3 (e múltiplos) são altas o suficiente para exigir que o **neutro
tenha seção maior que a fase**: §6.2.6.2.3 a 6.2.6.2.5, com a tabela do
**Anexo F (informativo)** dando o fator `fh` por faixa de conteúdo
harmônico, aplicado como `IN = fh × IB` sobre a corrente de projeto do
circuito.

Esse mecanismo **não é modelado como tabela/dado no schema**, pela mesma
razão do ADR 0007 (queda de tensão não armazenada pronta): é um cálculo de
tempo de consumo, não um valor de catálogo. Diferente do fator 0,86 (que é
uma linha fixa da Tabela 46, por isso vive em `tipo_circuito`), o fator
`fh` do Anexo F depende de uma medição/estimativa de conteúdo harmônico do
circuito específico — não há chave normativa fixa para armazenar como
linha de tabela. Quem for calcular a seção do neutro em cargas não-lineares
(iluminação eletrônica, retificadores, UPS, etc.) precisa aplicar essa
fórmula em código de aplicação, consultando `secao_nominal` para arredondar
para a bitola comercial imediatamente superior — igual já acontece hoje
com a fórmula de queda de tensão.

## Atualização — `tipo_circuito` decomposto em campos ortogonais

A lista real de tipos de circuito usada na prática (`F+N`, `F+N+T`, `2F`,
`2F+N`, `2F+T`, `2F+N+T`, `3F`, `3F+N`, `3F+T`, `3F+N+T`, `3F+sh`, `CC`) é
mais rica do que os 6 "esquemas de condutores vivos" nomeados pela Tabela
46 — a norma não nomeia formalmente a presença ou ausência de condutor de
proteção (PE) nem de blindagem, porque a Tabela 46 é estritamente sobre
condutores vivos (o PE nunca é "condutor vivo"; ver também
`restricao_material_condutor` e o ADR sobre alumínio/§6.2.3). Modelar
cada combinação como uma linha independente do enum anterior
(`esquema_condutores_vivos` texto livre) não escalaria para `F+N+T`,
`2F+T`, `3F+sh` etc.

`tipo_circuito` foi reestruturada para identidade por **campos
ortogonais** em vez de um enum fechado:

```
tipo_circuito (
  id,
  codigo,                           -- 'F', 'F+N+T', '3F+sh', 'CC-2'...
  tipo_corrente        CHECK IN ('CA','CC'),
  numero_fases          SMALLINT CHECK IN (1,2,3),  -- NULO quando CC
  tem_neutro            BOOLEAN,
  tem_protecao_pe       BOOLEAN,
  tem_blindagem         BOOLEAN,
  numero_condutores_carregados SMALLINT CHECK IN (2,3),  -- Tabela 46, inalterado
  permite_quarto_condutor BOOLEAN,
  fator_correcao_neutro_carregado NUMERIC,
  formula_queda_tensao  CHECK IN ('monofasica_bifasica','trifasica'),
  UNIQUE (tipo_corrente, numero_fases, tem_neutro, tem_protecao_pe, tem_blindagem)
)
```

Pontos-chave:

- `tem_protecao_pe` e `tem_blindagem` são **puramente identificadores** —
  nunca entram no cálculo de `numero_condutores_carregados` nem de
  `permite_quarto_condutor`/`fator_correcao_neutro_carregado`, porque
  nenhum dos dois é condutor vivo pela Tabela 46. `3F+T` tem exatamente o
  mesmo comportamento elétrico de `3F` (carregados=3); `3F+N+T` tem
  exatamente o mesmo de `3F+N` (carregados=3, `permite_quarto_condutor`,
  fator 0,86).
- `3F+sh` (fase + blindagem/shield): "sh" é blindagem, comum em cabos para
  inversores de frequência e automação industrial. Eletricamente
  equivalente a `3F` puro.
- `CC` continua com duas variantes (`CC-2`/`CC-3`), preservando a distinção
  original da Tabela 46 entre corrente contínua a dois e a três
  condutores — modelada com `tem_neutro` fazendo o papel do "condutor
  central" em `CC-3`, pela mesma lógica do monofásico a 3 condutores.
- `esquema_condutores_vivos` (coluna de texto livre) foi removida — a
  identidade do esquema agora é 100% derivável dos campos ortogonais, sem
  duplicar a mesma informação em dois formatos (mesmo princípio já usado
  para remover `cabos_metodo_instalacao`, ADR 0010).

Nenhuma tabela de fato referencia `tipo_circuito_id` ainda, então esta
reestruturação não exigiu migração de dados dependentes.
