# 0008 — Fator k de curto-circuito ancorado na NBR 5410, não só no guia Prysmian

## Status
Aceito.

## Contexto

O guia Prysmian apresenta o fator k de curto-circuito nas Tabelas 37-42,
separando o condutor de fase (Tabela 37) do condutor de proteção/PE
(Tabelas 38-42, uma por variante construtiva). Ao verificar a NBR 5410
diretamente (por instrução do usuário: "verifique e referencia a norma"),
confirmou-se que essas tabelas são a restatement comercial de cláusulas
normativas específicas, com nível de detalhe adicional só para o caso do
Afumex Green/LSHF.

A fórmula-mãe é §5.3.5.5.2: `∫i²dt ≤ k²·S²`, que para faltas simétricas
entre 0,1 s e 5 s se reduz a `I²·t ≤ k²·S²`. A norma tabela k por
material×isolação na sua **Tabela 30** — equivalente direto da Tabela 37
do guia. Para o condutor de proteção, a norma detalha em **§6.4.3.1** as
mesmas 5 variantes construtivas usadas pelo guia (isolado não incorporado
a um cabo multipolar, veia de cabo multipolar, condutor nu em contato com
a cobertura, armação/capa metálica usada como PE, condutor nu sem risco de
dano a materiais adjacentes) em suas **Tabelas 53 a 57**. A seção mínima
simplificada do PE (S≤16→S; 16<S≤35→16; S>35→S/2) é a **Tabela 58** da
norma, idêntica à Tabela 4 do guia.

## Decisão

Mantém-se o desenho já descrito no plano — `fator_k_curto_circuito`
(chaveado direto por `cabo_id`, ver ADR 0002) para o condutor de fase, e
`fator_k_protecao_pe` (discriminado por `cenario`, as 5 variantes
construtivas) para o PE — mas todo `COMMENT ON TABLE`/`COLUMN` passa a
citar a cláusula/tabela da NBR 5410 correspondente, não só a tabela do
guia:

- `fator_k_curto_circuito` → NBR 5410 §5.3.5.5.2, Tabela 30.
- `fator_k_protecao_pe` → NBR 5410 §6.4.3.1, Tabelas 53-57.
- `secao_minima_protecao_pe` (ADR já coberto no inventário de seções
  mínimas) → NBR 5410 Tabela 58.

## Consequências

- Qualquer dúvida futura sobre um valor de k pode ser conferida contra a
  cláusula/tabela citada no comentário da coluna, sem precisar recorrer ao
  guia Prysmian como única fonte.
- Nenhuma mudança estrutural em relação ao design já aceito — este ADR
  documenta a correspondência normativa, que era o gap identificado na
  revisão ("verifique e referencie a norma").

## Atualização (ver [0010](0010-multi-fabricante-identificacao-por-construcao.md))

A tabela `fator_k_curto_circuito` foi rechaveada de `cabo_id` para
`material_isolacao_id`. A correspondência normativa documentada aqui
(Tabela 30 da NBR 5410) não muda — o que mudou foi reconhecer que, sendo
uma tabela normativa, a chave nunca deveria ter sido o produto comercial
de um fabricante específico.
