import { Inject, Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { BT_POOL } from '../bt-pool.provider';

export interface CapacidadeConducaoResult {
  secaoNominalId: number;
  correnteAdmissivelA: number;
  arranjoAmpacidadeIdUsado: number | null;
  arranjoAssumido: boolean;
}

export interface ResistenciaReatanciaResult {
  resistenciaCaOhmKm: number;
  reatanciaIndutivaOhmKm: number;
  arranjoEspacamentoUsado: string;
  origemOverrideProduto: boolean;
}

@Injectable()
export class CalculoDadosRepository {
  constructor(@Inject(BT_POOL) private readonly pool: Pool) {}

  async listSecoesNominaisAscendentes(): Promise<{ id: number; valorMm2: number }[]> {
    const { rows } = await this.pool.query(
      `SELECT id, valor_mm2 FROM secao_nominal ORDER BY valor_mm2 ASC`,
    );
    return rows.map((r: { id: number; valor_mm2: string }) => ({ id: r.id, valorMm2: Number(r.valor_mm2) }));
  }

  /**
   * NBR 5410 Tabelas 36-39. Para métodos A1/A2/B1/B2/C/D não há arranjo
   * (arranjo_ampacidade_id IS NULL). Para E/F/G a norma exige uma topologia
   * física que o formulário atual não captura como campo próprio — nesse
   * caso assume-se a menor arranjo_ampacidade_id disponível para a
   * combinação (arranjoAssumido=true), sinalizado na memória de cálculo.
   */
  async getCapacidadeConducao(
    grupoTermicoId: number,
    materialCondutorId: number,
    metodoReferenciaId: number,
    numeroCondutoresCarregados: number,
    secaoNominalId: number,
  ): Promise<CapacidadeConducaoResult | null> {
    const semArranjo = await this.pool.query(
      `SELECT corrente_admissivel_a FROM capacidade_conducao_corrente
       WHERE grupo_termico_id = $1 AND material_condutor_id = $2 AND metodo_referencia_id = $3
         AND numero_condutores_carregados = $4 AND secao_nominal_id = $5
         AND arranjo_ampacidade_id IS NULL`,
      [grupoTermicoId, materialCondutorId, metodoReferenciaId, numeroCondutoresCarregados, secaoNominalId],
    );
    if (semArranjo.rows[0]) {
      return {
        secaoNominalId,
        correnteAdmissivelA: Number(semArranjo.rows[0].corrente_admissivel_a),
        arranjoAmpacidadeIdUsado: null,
        arranjoAssumido: false,
      };
    }

    const comArranjo = await this.pool.query(
      `SELECT arranjo_ampacidade_id, corrente_admissivel_a FROM capacidade_conducao_corrente
       WHERE grupo_termico_id = $1 AND material_condutor_id = $2 AND metodo_referencia_id = $3
         AND numero_condutores_carregados = $4 AND secao_nominal_id = $5
         AND arranjo_ampacidade_id IS NOT NULL
       ORDER BY arranjo_ampacidade_id ASC LIMIT 1`,
      [grupoTermicoId, materialCondutorId, metodoReferenciaId, numeroCondutoresCarregados, secaoNominalId],
    );
    if (!comArranjo.rows[0]) return null;
    return {
      secaoNominalId,
      correnteAdmissivelA: Number(comArranjo.rows[0].corrente_admissivel_a),
      arranjoAmpacidadeIdUsado: comArranjo.rows[0].arranjo_ampacidade_id,
      arranjoAssumido: true,
    };
  }

  /**
   * Base do cálculo de queda de tensão (ADR 0007). Prioriza override por
   * produto comercial (ADR 0010/0011); cai para o valor base do grupo
   * construtivo. arranjo_espacamento/arranjo_ampacidade não são campos do
   * formulário — assume-se "encostado" (o mais comum na prática) e a menor
   * arranjo_ampacidade_id compatível, mesma lógica de getCapacidadeConducao.
   */
  async getResistenciaReatancia(
    grupoConstrutivoId: number,
    produtoComercialId: number,
    materialCondutorId: number,
    secaoNominalId: number,
    numeroCondutoresCarregados: number,
  ): Promise<ResistenciaReatanciaResult | null> {
    const override = await this.pool.query(
      `SELECT rr.resistencia_ca_ohm_km, rr.reatancia_indutiva_ohm_km, ae.codigo AS espacamento
       FROM resistencia_reatancia_ca rr
       JOIN arranjo_espacamento ae ON ae.id = rr.arranjo_espacamento_id
       WHERE rr.produto_comercial_id = $1 AND rr.material_condutor_id = $2
         AND rr.secao_nominal_id = $3 AND rr.numero_condutores_carregados = $4
         AND ae.codigo = 'encostado'
       ORDER BY rr.arranjo_ampacidade_id ASC LIMIT 1`,
      [produtoComercialId, materialCondutorId, secaoNominalId, numeroCondutoresCarregados],
    );
    if (override.rows[0]) {
      return this.mapResistenciaRow(override.rows[0], true);
    }

    const baseRow = await this.pool.query(
      `SELECT rr.resistencia_ca_ohm_km, rr.reatancia_indutiva_ohm_km, ae.codigo AS espacamento
       FROM resistencia_reatancia_ca rr
       JOIN arranjo_espacamento ae ON ae.id = rr.arranjo_espacamento_id
       WHERE rr.produto_comercial_id IS NULL AND rr.grupo_construtivo_id = $1
         AND rr.material_condutor_id = $2 AND rr.secao_nominal_id = $3
         AND rr.numero_condutores_carregados = $4 AND ae.codigo = 'encostado'
       ORDER BY rr.arranjo_ampacidade_id ASC LIMIT 1`,
      [grupoConstrutivoId, materialCondutorId, secaoNominalId, numeroCondutoresCarregados],
    );
    if (!baseRow.rows[0]) return null;
    return this.mapResistenciaRow(baseRow.rows[0], false);
  }

  private mapResistenciaRow(row: any, origemOverrideProduto: boolean): ResistenciaReatanciaResult {
    return {
      resistenciaCaOhmKm: Number(row.resistencia_ca_ohm_km),
      reatanciaIndutivaOhmKm: Number(row.reatancia_indutiva_ohm_km),
      arranjoEspacamentoUsado: row.espacamento,
      origemOverrideProduto,
    };
  }

  /** NBR 5410 Tabela 30 — fator k para S=√(I²·t)/k, escolhendo a faixa de seção correta. */
  async getFatorKCurtoCircuito(
    materialIsolacaoId: number,
    materialCondutorId: number,
    secaoMm2: number,
  ): Promise<number | null> {
    const { rows } = await this.pool.query(
      `SELECT fator_k FROM fator_k_curto_circuito
       WHERE material_isolacao_id = $1 AND material_condutor_id = $2
         AND (secao_max_mm2 IS NULL OR secao_max_mm2 >= $3)
       ORDER BY secao_max_mm2 ASC NULLS LAST LIMIT 1`,
      [materialIsolacaoId, materialCondutorId, secaoMm2],
    );
    return rows[0] ? Number(rows[0].fator_k) : null;
  }
}
