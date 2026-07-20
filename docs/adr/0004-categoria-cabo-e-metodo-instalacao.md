# 0004 — Categoria de cabo depende da variante, não do produto; referências de método viram tabela ponte

## Status
Aceito.

## Contexto

A Tabela 6 do guia Prysmian lista os mesmos produtos (ex.: Sintenax, GSette
Easy) ora como "Cabo Unipolar" (quando fornecido/instalado com 1 condutor),
ora como "Cabo Multipolar" (quando fornecido/instalado com 2 a 5
condutores). Ou seja, `categoria_cabo` **não é um atributo fixo do
produto** — é um atributo da variante (produto × número de condutores).

Além disso, `metodo_instalacao` tinha três colunas nulláveis
(`ref_condutor_isolado`, `ref_cabo_unipolar`, `ref_cabo_multipolar`), cada
uma apontando opcionalmente para um método de referência (A1, B1, C...)
dependendo de qual categoria de cabo está instalada daquele jeito. Colunas
nulláveis paralelas são o mesmo antipadrão do ADR 0003: uma dimensão
(categoria de cabo) codificada como múltiplas colunas em vez de uma FK.

## Decisão

- `categoria_cabo_id` fica em `cabo_numero_condutores` (por variante), não
  em `cabos` — reflete que a categoria depende do número de condutores da
  instalação, não do produto isoladamente (ver ADR 0003).
- As três colunas nulláveis de `metodo_instalacao` viram uma tabela ponte
  `metodo_instalacao_referencia` (`metodo_instalacao_id` FK,
  `categoria_cabo_id` FK, `metodo_referencia_id` FK,
  `UNIQUE(metodo_instalacao_id, categoria_cabo_id)`) — mesmo padrão de
  normalização do ADR 0003, e permite fazer JOIN direto com
  `capacidade_conducao_corrente.metodo_referencia_id` sem branch condicional
  por categoria.

## Consequências

- Determinar a categoria de uma instalação concreta exige, agora,
  informar tanto o cabo quanto o número de condutores (a chave natural de
  `cabo_numero_condutores`) — correto, é exatamente a granularidade em que
  a categoria realmente varia na fonte.
- `metodo_instalacao_referencia` pode ter 0, 1, 2 ou 3 linhas por método de
  instalação (algumas linhas de instalação simplesmente não se aplicam a
  todas as categorias) — ausência de linha substitui `NULL` de coluna,
  sem exigir `CHECK` extra para "pelo menos uma categoria aplicável".

## Atualização (ver [0010](0010-multi-fabricante-identificacao-por-construcao.md))

A tabela `cabos_metodo_instalacao` citada no inventário original de
tabelas foi removida: verificou-se que ela era 100% derivável de
`cabo_numero_condutores.categoria_cabo_id → metodo_instalacao_referencia`,
sem nenhum dado próprio por cabo. Isso ficou evidente ao planejar suporte
a múltiplos fabricantes — manter a junção por `cabo_id` exigiria
recadastrar os mesmos pares para cada novo fabricante, apesar de a
resposta já estar implícita na categoria de construção do cabo.
