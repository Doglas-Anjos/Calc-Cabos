# 0001 — Normalização de dimensões compartilhadas

## Status
Aceito.

## Contexto

O schema original guardava seção nominal e demais atributos repetidos como
texto solto (ex.: seção como string `"1,5"`, `"10"`, `"16"`). Isso quebra
ordenação numérica correta (`"10" < "1,5"` em ordenação de texto) e não
oferece um ponto único de verdade para atributos físicos associados (ex.:
coeficiente de temperatura do material do condutor).

O guia Prysmian e a NBR 5410 referenciam repetidamente as mesmas dimensões
em dezenas de tabelas: seção nominal (mm²), material do condutor (cobre/
alumínio), método de referência de instalação (A1, A2, B1, B2, C, D, E, F,
G — NBR 5410 Tabela 36) e categoria do cabo (condutor isolado / cabo
unipolar / cabo multipolar).

## Decisão

Cada uma dessas dimensões vira sua própria tabela, com PK numérica (`SERIAL`)
e uma coluna de valor com `UNIQUE`:

- `material_condutor` (id, nome, `coeficiente_temperatura_20c`, `fator_kp_proximidade`) —
  os coeficientes físicos (α20 = 0,00393 Cu / 0,00403 Al; kp = 1 Cu / 0,8 Al)
  usados no cálculo de resistência em CA (NBR 5410 §6.3) ficam junto da
  entidade, não duplicados em cada tabela de fato.
- `secao_nominal` (id, `valor_mm2 NUMERIC UNIQUE`) — permite `ORDER BY`/
  `WHERE >=` corretos; é a chave central do schema, referenciada por quase
  toda tabela de fato.
- `metodo_referencia` (id, `codigo VARCHAR(3) UNIQUE`, descricao) — os 9
  métodos de referência da NBR 5410 Tabela 36.
- `categoria_cabo` (id, nome `UNIQUE`) — Condutor Isolado / Cabo Unipolar /
  Cabo Multipolar.

Toda FK para essas tabelas ganha índice btree explícito (Postgres não cria
automaticamente índice em FK, só na PK do lado referenciado).

## Consequências

- Toda tabela de fato (ampacidade, R/XL, fator k etc.) referencia essas
  dimensões por FK numérica em vez de repetir texto — menor volume de dados
  e integridade referencial garantida pelo banco.
- Adicionar uma seção nominal nova (ex.: uma bitola que passe a existir no
  mercado) é uma linha em `secao_nominal`, não uma migração de string em
  N tabelas.
- Custo: toda consulta que hoje leria só uma tabela de fato passa a exigir
  JOINs para exibir os valores legíveis (nome do material, mm² da seção
  etc.) — aceito porque o ganho de integridade/ordenção supera o custo de
  JOIN em um dataset pequeno (dezenas a centenas de linhas por tabela).
