import { FatorAgrupamentoTipo } from '../entities/circuito.entity';

export interface DimensionamentoInput {
  tipoCircuitoId: number;
  metodoInstalacaoId: number;
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
  isMotor: boolean;
  quedaTensaoPartidaMaxPct?: number | null;
  fatorPotenciaPartida?: number | null;
  correntePartidaA?: number | null;
  numeroCondutoresParalelosMin: number;
  numeroCondutoresParalelosMax: number;
}

export interface DimensionamentoResultado {
  secaoCalculadaMm2: number | null;
  correnteAdmissivelCorrigidaA: number | null;
  quedaTensaoCalculadaPct: number | null;
  quedaTensaoPartidaCalculadaPct: number | null;
  secaoMinimaCurtoCircuitoMm2: number | null;
  numeroCondutoresParalelosCalculado: number | null;
  viavel: boolean;
  memoriaCalculo: Record<string, unknown>;
}
