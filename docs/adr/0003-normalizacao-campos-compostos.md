# 0003 — Normalização de campos de texto composto

## Status
Aceito.

## Contexto

O schema original guardava listas em uma única coluna de texto:

- `cabos.numero_condutores` com valores como `'1'`, `'1,2,3,4 e 5'`,
  `'1 ou 3 (triplexado)'`.
- `metodo_instalacao.numero_metodo` com valores como `'31/31A/32/32A/35/36'`
  (referenciando múltiplos números de método da Tabela 33 da NBR 5410 para
  uma mesma linha de instalação).

Esse formato impede consultas como "quais cabos existem em configuração de
3 condutores" ou "qual método de instalação corresponde ao código 32A" sem
parsing de string em tempo de consulta — e não tem como impor unicidade ou
integridade referencial sobre os valores individuais.

## Decisão

Cada campo composto vira uma tabela filha, uma linha por valor individual:

- `cabo_numero_condutores` (`cabo_id` FK, `numero_condutores SMALLINT`,
  `categoria_cabo_id` FK, `UNIQUE(cabo_id, numero_condutores)`).
- `metodo_instalacao_numero` (`metodo_instalacao_id` FK, `codigo VARCHAR`,
  `UNIQUE(metodo_instalacao_id, codigo)`).

A migração dos dados existentes (`database/insert_data.sql`) usa
`unnest(string_to_array(...))` para popular `metodo_instalacao_numero` a
partir da lista de códigos originalmente escrita como string separada por
`/`, evitando reescrever 30+ linhas manualmente e mantendo a fonte dos
dados auditável no próprio script.

## Consequências

- Consultas por número de condutores ou por código de método individual
  passam a ser `WHERE` direto em vez de `LIKE`/parsing.
- Constraints `UNIQUE` e `CHECK` (ex.: `numero_condutores` só aceita 1-5)
  passam a ser aplicáveis pelo banco, não só pela aplicação.
- Cada cabo/método com múltiplos valores agora ocupa múltiplas linhas na
  tabela filha — aceito, é a definição de estar em 1FN.
