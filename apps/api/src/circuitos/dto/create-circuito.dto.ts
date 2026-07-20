import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { FatorAgrupamentoTipo } from '../../entities/circuito.entity';
import {
  NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO,
  NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO,
} from '../../config/constants';

export class CreateCircuitoDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  nome: string;

  @Type(() => Number)
  @IsInt()
  tipoCargaId: number;

  @Type(() => Number)
  @IsInt()
  metodoInstalacaoId: number;

  @Type(() => Number)
  @IsInt()
  tipoCircuitoId: number;

  @Type(() => Number)
  @IsInt()
  categoriaCaboId: number;

  @Type(() => Number)
  @IsInt()
  produtoComercialId: number;

  @Type(() => Number)
  @IsInt()
  materialCondutorId: number;

  @Type(() => Number)
  @IsInt()
  temperaturaAmbienteC: number;

  @IsIn(['ar', 'enterrado'])
  fatorAgrupamentoTipo: FatorAgrupamentoTipo;

  @Type(() => Number)
  @IsInt()
  fatorAgrupamentoId: number;

  @Type(() => Number)
  @IsNumber()
  @IsPositive()
  comprimentoM: number;

  @Type(() => Number)
  @IsNumber()
  @IsPositive()
  tensaoNominalV: number;

  @Type(() => Number)
  @IsNumber()
  @IsPositive()
  correnteA: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(1)
  fatorPotencia: number;

  @Type(() => Number)
  @IsNumber()
  @IsPositive()
  correnteCurtoCircuitoA: number;

  @Type(() => Number)
  @IsNumber()
  @IsPositive()
  tempoAtuacaoCurtoCircuitoS: number;

  @Type(() => Number)
  @IsNumber()
  @IsPositive()
  quedaTensaoNominalMaxPct: number;

  // Obrigatórios apenas quando tipoCargaId aponta para "Motor" — validado em
  // CircuitosService (depende de lookup no banco, não é uma regra estática do DTO).
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @IsPositive()
  quedaTensaoPartidaMaxPct?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(1)
  fatorPotenciaPartida?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @IsPositive()
  correntePartidaA?: number;

  // Intervalo de condutores em paralelo por fase que o motor de cálculo pode
  // testar (NBR 5410 §6.2.5.7) — opcionais no DTO, default aplicado em
  // CircuitosService quando omitidos.
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO)
  @Max(NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO)
  numeroCondutoresParalelosMin?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO)
  @Max(NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO)
  numeroCondutoresParalelosMax?: number;
}
