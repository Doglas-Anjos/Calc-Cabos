// Tipos compartilhados entre apps/api e apps/web — mantidos em sincronia
// manual com database/app/01_create_table.sql e database/app/02_insert_data.sql.

export type FatorAgrupamentoTipo = 'ar' | 'enterrado';

// Espelha database/app/02_insert_data.sql (tabela tipo_carga) — nomes, não IDs
// (os IDs vêm sempre da API/catálogo, nunca hardcoded no front).
export const TIPO_CARGA_MOTOR = 'Motor';

// Condutores em paralelo por fase (NBR 5410 §6.2.5.7) — espelha
// apps/api/src/config/constants.ts (NUMERO_CONDUTORES_PARALELOS_*_ABSOLUTO).
// Mudar aqui exige mudar lá também.
export const NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO = 1;
export const NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO = 10;

export interface CatalogoOption {
  id: number;
  label: string;
}

export interface CircuitoInput {
  nome: string;
  tipoCargaId: number;
  metodoInstalacaoId: number;
  tipoCircuitoId: number;
  categoriaCaboId: number;
  produtoComercialId: number;
  materialCondutorId: number;
  temperaturaAmbienteC: number;
  fatorAgrupamentoTipo: FatorAgrupamentoTipo;
  fatorAgrupamentoId: number;
  comprimentoM: number;
  tensaoNominalV: number;
  correnteA: number;
  fatorPotencia: number;
  correnteCurtoCircuitoA: number;
  tempoAtuacaoCurtoCircuitoS: number;
  quedaTensaoNominalMaxPct: number;
  // Só preenchidos quando tipoCargaId aponta para "Motor"
  quedaTensaoPartidaMaxPct?: number | null;
  fatorPotenciaPartida?: number | null;
  correntePartidaA?: number | null;
  // Intervalo de condutores em paralelo por fase que o motor de cálculo
  // pode testar para este circuito (ver NUMERO_CONDUTORES_PARALELOS_*_ABSOLUTO).
  numeroCondutoresParalelosMin: number;
  numeroCondutoresParalelosMax: number;
}

export interface ResultadoCalculo {
  id: number;
  circuitoId: number;
  secaoCalculadaMm2: number | null;
  correnteAdmissivelCorrigidaA: number | null;
  quedaTensaoCalculadaPct: number | null;
  quedaTensaoPartidaCalculadaPct: number | null;
  secaoMinimaCurtoCircuitoMm2: number | null;
  numeroCondutoresParalelosCalculado: number | null;
  viavel: boolean;
  memoriaCalculo: Record<string, unknown>;
  createdAt: string;
}

export interface Circuito extends CircuitoInput {
  id: number;
  projetoId: number;
  createdAt: string;
  updatedAt: string;
  resultadoAtual?: ResultadoCalculo | null;
}

export interface Projeto {
  id: number;
  nome: string;
  descricao: string | null;
  createdAt: string;
}

export type ImportJobStatus = 'pending' | 'processing' | 'done' | 'failed';

export interface ImportJob {
  id: number;
  projetoId: number;
  arquivoNome: string;
  status: ImportJobStatus;
  totalLinhas: number;
  linhasProcessadas: number;
  linhasErro: number;
  createdAt: string;
  finishedAt: string | null;
}
