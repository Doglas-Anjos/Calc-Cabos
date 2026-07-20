# 0012 — `arranjo_ampacidade` completo e reutilizado em `resistencia_reatancia_ca`

## Status
Aceito.

## Contexto

Ao transcrever a carga completa das Tabelas 7-10 (ampacidade) e 28-36
(resistência/reatância CA) do guia Prysmian para `capacidade_conducao_corrente`
e `resistencia_reatancia_ca` — até então só com 1-2 linhas de exemplo, ver
`docs/adr/README.md` — a inspeção página a página (texto **e** os ícones que
o guia usa para identificar cada bloco de colunas, já que o texto sozinho não
distingue topologias) revisou dois problemas de modelagem:

1. **`arranjo_ampacidade` estava incompleto.** As Tabelas 9/10 (ampacidade,
   métodos E/F/G) têm uma coluna "dois condutores carregados justapostos"
   (dois cabos unipolares lado a lado, sem trifólio) que não correspondia a
   nenhum dos 5 códigos existentes.

2. **`resistencia_reatancia_ca` não conseguia representar as Tabelas 28-36**,
   e essas tabelas não são uniformes entre famílias de produto — há dois
   formatos distintos, confirmados comparando os ícones de cada tabela:

   - **Superastic, Superastic Flex/Afumex Green** (Tabelas 28, 29, 34 —
     família só "Condutores Isolados/Cabos Unipolares" na Tabela 6 do guia,
     sem variante multipolar): 9 combinações por seção —
     `unipolar_justaposto_par` (2 condutores, 4 distâncias: encostado/s=2D/
     s=13cm/s=20cm) e, para 3 condutores, `unipolar_justaposto_plano`
     (encostado + 3 distâncias) ou `unipolar_justaposto_trifolio` (só
     encostado — o guia não tabela trifólio espaçado).

   - **Sintenax, Sintenax Flex, GSette Easy/Afumex Flex, Voltenax/Voltalene**
     (Tabelas 30-33, 35-36 — família que a Tabela 6 do guia também lista como
     "Cabo Multipolar"): 12 combinações por seção, as mesmas 9 acima **mais**
     3 colunas extras identificadas pelos ícones:
     - um **cabo multipolar de 2 núcleos** (ícone: 2 círculos dentro de uma
       única capa externa — produto diferente de "2 unipolares encostados",
       mesmo os dois sendo fisicamente parecidos);
     - um **cabo multipolar de 3 núcleos** (mesma ideia, 3 núcleos numa
       única capa);
     - um arranjo de **3 unipolares em quadrado**, espaçados 20 cm nos dois
       eixos (ícone: 3 círculos dentro de um quadrado tracejado com "20 CM"
       nos dois lados) — geometria que não é nem trifólio (triangular,
       encostado) nem plano (retilíneo).

   O ponto crítico do primeiro formato: "no mesmo plano, encostados" e "em
   trifólio" são **ambos "encostados"** no sentido de distância zero, mas são
   arranjos físicos diferentes com valores de Rca/XL diferentes no guia —
   conferido linha a linha na Tabela 28 (Superastic, cobre, 1,5 mm²):
   plano-encostado dá XL=0,14 Ω/km, trifólio dá XL=0,12 Ω/km. Um único
   discriminador de distância (`arranjo_espacamento`) colapsaria os dois,
   perdendo a distinção e violando unicidade assim que ambas as linhas
   fossem inseridas com a mesma chave. O cabo multipolar (2 ou 3 núcleos) é
   o mesmo problema de novo: mais uma linha "sem distância" que precisa de
   identidade própria, e que já existe como conceito em `arranjo_ampacidade`
   (`multipolar_justaposto`, usado por `capacidade_conducao_corrente`/método
   E) — só não estava disponível em `resistencia_reatancia_ca`.

## Decisão

1. Dois códigos novos em `arranjo_ampacidade`:
   - `unipolar_justaposto_par` — dois cabos unipolares carregados, justapostos
     lado a lado (cobre a coluna "2 condutores" que faltava nas Tabelas 9/10
     de ampacidade e nas Tabelas 28-36 de R/XL).
   - `unipolar_espacado_quadrado` — três cabos unipolares carregados, arranjo
     quadrado, s=20cm nos dois eixos (só usado por `resistencia_reatancia_ca`,
     Tabelas 30-33/35-36).

   `multipolar_justaposto` (já existia, usado pelo método E de ampacidade)
   passa a ser reutilizado também por `resistencia_reatancia_ca` — ver item 2.

2. `resistencia_reatancia_ca` ganhou a coluna `arranjo_ampacidade_id`
   (`NOT NULL REFERENCES arranjo_ampacidade`), **reutilizando a mesma
   dimensão já usada por `capacidade_conducao_corrente`** em vez de criar uma
   tabela de topologia paralela — o conceito ("arranjo físico/topológico dos
   condutores", independente da distância) é idêntico nas duas tabelas de
   fato, mesmo que nem todo código seja usado nas duas (`unipolar_justaposto_par`
   e `unipolar_espacado_quadrado` também servem a `capacidade_conducao_corrente`
   caso um dia o guia detalhe ampacidade para esses arranjos). A combinação
   `(numero_condutores_carregados, arranjo_ampacidade_id, arranjo_espacamento_id)`
   reproduz exatamente as colunas do guia, com `arranjo_espacamento='encostado'`
   como sentinela para as linhas "sem distância" (trifólio e multipolar).

3. Os dois índices únicos parciais (`uq_resistencia_reatancia_ca_base` /
   `uq_resistencia_reatancia_ca_override`, ver docs/adr/0010) passam a incluir
   `arranjo_ampacidade_id` na chave composta.

Não foi adicionado `CHECK` amarrando `arranjo_ampacidade_id` a
`numero_condutores_carregados`, nem restringindo quais famílias de produto
(`grupo_construtivo`) podem ter linhas de `multipolar_justaposto`/
`unipolar_espacado_quadrado` — mesmo nível de rigor já adotado em
`capacidade_conducao_corrente`: a heterogeneidade entre famílias (Superastic
não tem essas 3 colunas, Sintenax tem) fica só na carga de dados, não em
constraint.

## Consequências

- `resistencia_reatancia_ca` tem 9 combinações por seção para Superastic/
  Superastic Flex/Afumex Green e 12 para Sintenax/Sintenax Flex/GSette Easy
  /Afumex Flex/Voltenax/Voltalene — refletindo fielmente a heterogeneidade
  real do guia (Tabela 6: nem todo produto tem variante "cabo multipolar"),
  em vez de forçar as 9 famílias a um molde único.
- Qualquer consumidor que já filtrava `capacidade_conducao_corrente` por
  `arranjo_ampacidade_id` usa a mesma lista de códigos para filtrar
  `resistencia_reatancia_ca` — não há dois vocabulários de topologia no
  schema, mesmo que o subconjunto usado por cada tabela de fato seja
  diferente.
- Esta correção antecedeu a carga completa das tabelas numéricas (ver
  `database/insert_data_ampacidade.sql` e
  `database/insert_data_resistencia.sql`) — sem ela, a carga teria ido ao
  chão na primeira violação de unicidade entre uma linha plano-encostado e
  uma trifólio (ou entre trifólio e multipolar) de mesma seção.
