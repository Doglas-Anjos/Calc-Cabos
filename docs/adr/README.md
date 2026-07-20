# Architecture Decision Records — Calc-Cabos

Este diretório documenta as decisões de design do banco de dados do Calc-Cabos,
seguindo a convenção usual de ADR (Architecture Decision Record): um arquivo
markdown por decisão significativa, numerado sequencialmente, imutável depois
de aceito (uma mudança de rumo vira um novo ADR que referencia o anterior, não
uma edição retroativa).

## Contexto geral

O schema modela o dimensionamento de condutores de baixa tensão conforme a
**NBR 5410:2004** (Instalações elétricas de baixa tensão), usando o "Guia de
Dimensionamento de Cabos para Baixa Tensão" da Prysmian como fonte prática das
tabelas de produto — mas tratando a norma como fonte primária sempre que as
duas divergem em nomenclatura ou nível de detalhe. O escopo do schema é
deliberadamente restrito a **ampacidade, queda de tensão e suportabilidade ao
curto-circuito**; seções sobre princípios fundamentais, proteção contra
choques elétricos etc. ficam fora.

## Índice

| ADR | Título |
|---|---|
| [0001](0001-normalizacao-dimensoes-compartilhadas.md) | Normalização de dimensões compartilhadas |
| [0002](0002-agrupamento-termico-vs-construtivo.md) | Agrupamento térmico vs. construtivo |
| [0003](0003-normalizacao-campos-compostos.md) | Normalização de campos de texto composto |
| [0004](0004-categoria-cabo-e-metodo-instalacao.md) | Categoria de cabo e método de instalação |
| [0005](0005-tipo-circuito-e-finalidade-circuito.md) | Tipo de circuito e finalidade de circuito |
| [0006](0006-fatores-agrupamento-unificados.md) | Fatores de agrupamento unificados |
| [0007](0007-queda-tensao-calculada-nao-armazenada.md) | Queda de tensão calculada, não armazenada |
| [0008](0008-fator-k-curto-circuito-ancorado-na-norma.md) | Fator k de curto-circuito ancorado na norma |
| [0009](0009-restricao-material-condutor.md) | Restrição de uso de condutor de alumínio |
| [0010](0010-multi-fabricante-identificacao-por-construcao.md) | Catálogo multi-fabricante: identidade por material de isolação/cobertura |
| [0011](0011-cabos-especificacao-generica-produto-comercial.md) | `cabos` como especificação técnica pura; fabricante isolado em `produto_comercial` |
| [0012](0012-arranjo-ampacidade-em-resistencia-reatancia-ca.md) | `arranjo_ampacidade` completo e reutilizado em `resistencia_reatancia_ca` |

## Convenção adotada neste repositório

- Todo `COMMENT ON TABLE`/`COMMENT ON COLUMN` em `database/bt/create_table.sql`
  cita a cláusula ou tabela da NBR 5410:2004 correspondente — a norma é
  citada mesmo quando o dado imediato veio do guia Prysmian, porque o guia é
  uma restatement comercial da norma.
- `database/bt/create_table.sql` contém só schema + índices; `database/bt/insert_data.sql`
  contém a migração dos dados já existentes e 1-2 linhas de exemplo por
  tabela nova. Duas exceções com carga numérica completa, isoladas em
  arquivos próprios (executados depois de `insert_data.sql`) por causa do
  volume: `database/bt/insert_data_ampacidade.sql` (Tabelas 7-10 do guia,
  ~1.520 linhas) e `database/bt/insert_data_resistencia.sql` (Tabelas 18 e
  28-36, ver docs/adr/0012). As demais tabelas numéricas do guia (fatores de
  agrupamento, seções mínimas etc.) continuam com carga completa pendente
  para uma futura importação via CSV.
- Esses arquivos vivem em `database/bt/` porque o repositório passou a ter
  três bancos Postgres separados (`calc_cabos_bt`, `calc_cabos_app` e o
  placeholder `calc_cabos_mt` para média tensão) — ver `docker-compose.yml`
  e `database/app/`. Os ADRs abaixo, escritos antes dessa reestruturação,
  referenciam os caminhos antigos (`database/create_table.sql` etc.); por
  serem imutáveis após aceitos, não foram editados — o caminho atual é
  sempre `database/bt/<mesmo nome de arquivo>`.
