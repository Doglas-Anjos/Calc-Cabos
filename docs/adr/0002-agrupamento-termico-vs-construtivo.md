# 0002 — Agrupamento térmico vs. construtivo (e o caso do fator k, que não usa nenhum dos dois)

## Status
Aceito.

## Contexto

As tabelas numéricas do guia Prysmian não são uma por cabo — vários dos 9
produtos (Superastic, Superastic Flex, Afumex Green, Sintenax, Sintenax
Flex, GSette Easy, Voltalene, Voltenax, Afumex Flex) compartilham
integralmente a mesma tabela de ampacidade e/ou a mesma tabela de
resistência/reatância. Sem um conceito de agrupamento, os mesmos milhares
de valores numéricos seriam duplicados 4-5 vezes — uma vez por cabo — só
porque o schema amarra a tabela de fato direto ao `cabo_id`.

Só que os agrupamentos **não são o mesmo** para ampacidade e para R/XL:
- Ampacidade (NBR 5410 Tabelas 36-42) depende da classe de temperatura de
  isolação do cabo: PVC/LSHF a 70 °C vs. EPR/XLPE a 90 °C. Isso agrupa
  {Superastic, Superastic Flex, Afumex Green, Sintenax, Sintenax Flex} de
  um lado e {GSette Easy, Voltalene, Voltenax, Afumex Flex} de outro.
- Resistência/reatância (queda de tensão) depende da construção física do
  cabo (unipolar vs. multipolar, presença de cobertura), não só da classe
  térmica: Superastic Flex e Afumex Green compartilham tabela entre si, mas
  Sintenax tem tabela própria, mesmo estando no mesmo grupo térmico.

E o fator k de curto-circuito (NBR 5410 Tabela 30) tem seu próprio
agrupamento diferente dos outros dois (ex.: Afumex Green isolado do resto
do seu grupo térmico) — mas essa tabela é pequena (~20-30 linhas), então
inventar um terceiro conceito de agrupamento só para economizar algumas
linhas duplicadas não compensa a complexidade adicional.

## Decisão

Dois conceitos de agrupamento distintos, cada um com sua própria tabela de
dimensão:

- `grupo_termico` (id, nome, `temp_operacao_c`, `temp_sobrecarga_c`) —
  referenciado por `cabos.grupo_termico_id` e por
  `capacidade_conducao_corrente.grupo_termico_id`.
- `grupo_construtivo` (id, nome) — referenciado por `cabos.grupo_construtivo_id`
  e por `resistencia_reatancia_ca.grupo_construtivo_id`.

Para o fator k de curto-circuito, `fator_k_curto_circuito.cabo_id`
referencia `cabos` diretamente — sem agrupamento intermediário. Duplicação
aceita explicitamente aqui: a tabela é pequena e não repete os cabos que já
compartilham grupo térmico/construtivo (cada cabo tem sua própria linha,
mas o valor de k pode coincidir entre eles sem que isso justifique uma
terceira tabela de agrupamento).

## Consequências

- Duas tabelas de dimensão (`grupo_termico`, `grupo_construtivo`) em vez de
  uma genérica "grupo" — mais explícito sobre o que cada uma representa,
  evita confundir "mesma tabela de ampacidade" com "mesma tabela de R/XL"
  quando um novo cabo for cadastrado.
- Cadastrar um cabo novo exige decidir os dois agrupamentos
  independentemente — correto, porque de fato são independentes na fonte
  (guia Prysmian / NBR 5410).
- `fator_k_curto_circuito` aceita alguma duplicação de valor (não de
  estrutura) em troca de não introduzir um terceiro conceito de
  agrupamento só usado por uma tabela pequena.

## Atualização (ver [0010](0010-multi-fabricante-identificacao-por-construcao.md))

Com a chegada de um catálogo multi-fabricante, `fator_k_curto_circuito`
deixou de referenciar `cabo_id` diretamente — passou a referenciar
`material_isolacao_id`, que é a chave que sempre deveria ter sido usada
aqui (a tabela é normativa, não varia por fabricante). O raciocínio deste
ADR sobre por que essa tabela usa um terceiro agrupamento próprio continua
válido; só a coluna de chave mudou.
