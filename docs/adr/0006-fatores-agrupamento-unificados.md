# 0006 — Fatores de agrupamento unificados (Tabelas 13-17 do guia colapsam em 2 tabelas)

## Status
Aceito.

## Contexto

O guia Prysmian apresenta os fatores de agrupamento em 5 tabelas separadas
(Tabelas 13 a 17), quase-duplicadas entre si, variando por cenário: camada
única ao ar, multicamada ao ar, agrupamento direto no solo, agrupamento em
duto multipolar, agrupamento em duto unipolar. A estrutura de colunas
(número de circuitos → fator) é idêntica em todas — só o cenário muda.

Modelar 5 tabelas quase-idênticas obrigaria qualquer consulta a decidir
"qual das 5 tabelas" antes de saber "qual fator" — uma coluna
discriminadora resolve isso com uma única tabela por domínio (ar vs.
enterrado).

## Decisão

Duas tabelas, cada uma com uma coluna `cenario` discriminando a variante:

- `fator_agrupamento_ar` — `cenario CHECK IN ('camada_unica','multicamada')`,
  mais `circuitos_min`, `circuitos_max`, `camadas_min`/`camadas_max`
  (nuláveis, só relevantes para `multicamada`), `metodo_instalacao_grupo`
  (nulável), `fator`.
- `fator_agrupamento_enterrado` — `cenario CHECK IN ('direto',
  'duto_multipolar','duto_unipolar')`, mais `numero_circuitos`,
  `distancia_desc`, `fator`.

Os cenários "ao ar" (camada única, multicamada) e "enterrado" (direto,
duto multipolar, duto unipolar) permanecem em tabelas separadas entre si —
não colapsados numa tabela única — porque as colunas relevantes realmente
diferem (multicamada precisa de `camadas_min/max`; enterrado precisa de
`distancia_desc`), então uma tabela unificada exigiria colunas nulas
demais sem ganho real.

## Consequências

- 2 tabelas em vez de 5 — menos schema para manter, sem perda de
  informação (o cenário vira dado, não estrutura).
- Toda consulta de fator de agrupamento filtra por `cenario` explicitamente
  — comportamento equivalente a "escolher a tabela certa" no guia original,
  só que como predicado SQL em vez de escolha de tabela.
- Adicionar um cenário novo dentro do mesmo domínio (ex.: uma variante nova
  de agrupamento ao ar) é uma linha no `CHECK` + dados, não uma tabela
  nova.
