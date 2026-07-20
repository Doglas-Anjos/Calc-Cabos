// Sem autenticação nesta fase — usuário único implícito, seed em
// database/app/02_insert_data.sql (usuarios.id = 1). Trocar por
// req.user.id quando login for adicionado.
export const DEFAULT_USUARIO_ID = 1;

// Condutores em paralelo por fase (NBR 5410 §6.2.5.7) — o motor de
// dimensionamento tenta N=1, depois N=2, ... até achar a menor seção que
// atenda com o menor N possível, limitado ao intervalo escolhido no
// circuito (circuitos.numero_condutores_paralelos_min/max), por sua vez
// limitado a este teto absoluto. Mantido em sincronia manual com
// packages/shared-types/src/index.ts (NUMERO_CONDUTORES_PARALELOS_*) —
// mudar aqui exige mudar lá também.
export const NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO = 1;
export const NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO = 10;
