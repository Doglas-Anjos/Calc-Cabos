# Calc-Cabos

Calculadora de dimensionamento de cabos (NBR 5410:2004), organizada em
projetos: o usuário cria um projeto e, dentro dele, circuitos — cada
circuito é um cálculo de dimensionamento de baixa tensão (ampacidade, queda
de tensão e curto-circuito). Média tensão está reservada para uma fase
futura (ver `database/mt/README.md`).

## Arquitetura

- `database/bt` — catálogo normativo de baixa tensão (schema já existente,
  ver `docs/adr/`).
- `database/app` — projetos, circuitos, resultados de cálculo, jobs de
  importação.
- `database/mt` — placeholder para a futura calculadora de média tensão.
- `apps/api` — NestJS. TypeORM para o banco de aplicação; `pg` com SQL de
  mão para o catálogo bt (schema externo, só leitura). BullMQ/Redis só para
  o fluxo de importação em massa via Excel — criar/editar um circuito
  manualmente é síncrono.
- `apps/web` — React (Vite) + React Query.
- `packages/shared-types` — tipos TS compartilhados entre api e web.

## Rodando tudo

```
docker compose up -d
```

Sobe 3 Postgres (bt/app/mt), Redis, a API (`http://localhost:3000/api`) e o
front (`http://localhost:5173`). Os containers `api`/`web` rodam
`npm install && npm run dev:...` a cada start — não é necessário ter Node
instalado no host.

Se preferir rodar a API ou o front localmente (com Node 20+ instalado),
copie `apps/api/.env.example` para `.env` e `apps/web/.env.example` para
`.env`, rode `npm install` na raiz do repo e use `npm run dev:api` /
`npm run dev:web`.

## Acesso direto aos bancos (psql, DBeaver, etc.)

Além do usuário de conexão da aplicação (`calc_cabos`/`calc_cabos`, já
superusuário por padrão da imagem `postgres`), cada um dos 3 bancos tem um
role `root`/`root` dedicado a acesso administrativo manual — criado pelos
scripts `00_create_root.sql` em `database/bt`, `database/app` e
`database/mt` (rodam automaticamente em volume novo; nos containers já
existentes foi criado manualmente uma vez via `docker exec`). Credenciais de
desenvolvimento, não usar fora do ambiente local.

| Banco            | Host      | Porta | Usuário | Senha |
|-------------------|-----------|-------|---------|-------|
| calc_cabos_bt      | localhost | 5432  | root    | root  |
| calc_cabos_app     | localhost | 5433  | root    | root  |
| calc_cabos_mt      | localhost | 5434  | root    | root  |

## Reprocessar o catálogo bt/app do zero

Os scripts em `database/bt` e `database/app` rodam automaticamente no
primeiro start de cada container (via `docker-entrypoint-initdb.d`). Para
recarregar do zero: `docker compose down -v` (remove os volumes) seguido de
`docker compose up -d`.
