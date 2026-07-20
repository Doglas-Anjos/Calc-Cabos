# 0007 — Queda de tensão calculada em tempo de consulta, não armazenada em V/A·km

## Status
Aceito.

## Contexto

O guia Prysmian apresenta a queda de tensão pronta em tabelas expressas em
V/A·km (Tabelas 19-27), já calculadas para fatores de potência fixos
(0,80 e 0,95). O usuário instruiu explicitamente: **não** usar esse
formato — em vez disso, guardar resistência e reatância dos cabos e
calcular a queda de tensão a partir da distância real do circuito, usando
as fórmulas da própria NBR 5410.

A norma define a metodologia em §6.2:

- Circuito monofásico/bifásico: `ΔV = 2 · (R·cosφ + XL·senφ) · I · ℓ`
- Circuito trifásico: `ΔV = √3 · (R·cosφ + XL·senφ) · I · ℓ`

onde R é a resistência em corrente alternada corrigida pela temperatura de
operação (§6.3: `R' = R₀ · [1 + α20·(θ-20)]`) e XL é a reatância indutiva —
ambas dependentes do material, seção e disposição construtiva do cabo, não
do fator de potência da carga. O fator de potência e a corrente são
propriedades da carga/circuito consultado, não do cabo — armazená-los
"congelados" numa tabela de queda de tensão pronta significa recalcular a
tabela inteira a cada combinação de FP considerada.

## Decisão

Não existe tabela `queda_tensao` no schema. A única tabela usada para esse
cálculo é `resistencia_reatancia_ca` (grupo_construtivo_id,
material_condutor_id, secao_nominal_id, numero_condutores_carregados,
arranjo_espacamento_id, `resistencia_ca_ohm_km`,
`reatancia_indutiva_ohm_km`) — os mesmos dados que o guia usa internamente
para gerar suas próprias tabelas de V/A·km, mas guardados na forma
intermediária, reutilizável para qualquer FP e qualquer distância.

`tipo_circuito.formula_queda_tensao` (ver ADR 0005) guarda apenas qual
multiplicador usar (`monofasica_bifasica` → 2, `trifasica` → √3) — o
schema não decide o valor de ΔV, só aponta a fórmula normativa correta a
aplicar.

## Consequências

- Elimina uma tabela inteira do schema (a que teria mais linhas, por
  variar por FP além de todas as outras dimensões).
- O cálculo de ΔV para uma combinação específica (FP, corrente, distância)
  vira responsabilidade de quem consome o banco — correto, porque FP e
  distância são dados da instalação concreta, não do catálogo de cabos.
- Validar esse desenho exige, na etapa de verificação, calcular à mão um
  caso de exemplo (R, XL, FP, I, ℓ, multiplicador) e conferir contra a
  NBR 5410 §6.2 — não há tabela pronta para "bater o olho" e conferir.
