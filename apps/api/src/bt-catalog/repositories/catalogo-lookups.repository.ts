import { Inject, Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { BT_POOL } from '../bt-pool.provider';

export interface CaboEspecificacao {
  caboId: number;
  materialIsolacaoId: number;
  materialCoberturaId: number;
  classeEncordoamentoId: number;
  grupoConstrutivoId: number;
  grupoTermicoId: number;
  tempCurtoCircuitoC: number;
}

@Injectable()
export class CatalogoLookupsRepository {
  constructor(@Inject(BT_POOL) private readonly pool: Pool) {}

  async listTiposCircuito() {
    const { rows } = await this.pool.query(
      `SELECT id, codigo, tipo_corrente, numero_fases, tem_neutro, tem_protecao_pe,
              tem_blindagem, numero_condutores_carregados, formula_queda_tensao
       FROM tipo_circuito ORDER BY codigo`,
    );
    return rows;
  }

  async getTipoCircuito(id: number) {
    const { rows } = await this.pool.query(`SELECT * FROM tipo_circuito WHERE id = $1`, [id]);
    return rows[0] ?? null;
  }

  async listMetodosInstalacao() {
    const { rows } = await this.pool.query(
      `SELECT mi.id, mi.tipo_linha_eletrica,
              array_agg(DISTINCT min.codigo ORDER BY min.codigo) AS codigos
       FROM metodo_instalacao mi
       LEFT JOIN metodo_instalacao_numero min ON min.metodo_instalacao_id = mi.id
       GROUP BY mi.id, mi.tipo_linha_eletrica
       ORDER BY mi.id`,
    );
    return rows;
  }

  async listCategoriasCabo() {
    const { rows } = await this.pool.query(`SELECT id, nome FROM categoria_cabo ORDER BY id`);
    return rows;
  }

  async listMateriaisCondutor() {
    const { rows } = await this.pool.query(
      `SELECT id, nome, coeficiente_temperatura_20c, fator_kp_proximidade FROM material_condutor ORDER BY id`,
    );
    return rows;
  }

  async getMaterialCondutor(id: number) {
    const { rows } = await this.pool.query(`SELECT * FROM material_condutor WHERE id = $1`, [id]);
    return rows[0] ?? null;
  }

  async listProdutosComerciais() {
    const { rows } = await this.pool.query(
      `SELECT pc.id, f.nome AS fabricante, pc.nome_comercial,
              c.tensao_isolamento, mi.nome AS material_isolacao, mc.nome AS material_cobertura
       FROM produto_comercial pc
       JOIN fabricante f ON f.id = pc.fabricante_id
       JOIN cabos c ON c.id = pc.cabo_id
       JOIN material_isolacao mi ON mi.id = c.material_isolacao_id
       JOIN material_cobertura mc ON mc.id = c.material_cobertura_id
       ORDER BY f.nome, pc.nome_comercial`,
    );
    return rows;
  }

  /** Resolve a especificação técnica genérica (cabos) a partir do produto comercial escolhido no formulário. */
  async resolveCaboEspecificacao(produtoComercialId: number): Promise<CaboEspecificacao | null> {
    const { rows } = await this.pool.query(
      `SELECT c.id AS cabo_id, c.material_isolacao_id, c.material_cobertura_id,
              c.classe_encordoamento_id, c.grupo_construtivo_id,
              mi.grupo_termico_id, mi.temp_curto_circuito_c
       FROM produto_comercial pc
       JOIN cabos c ON c.id = pc.cabo_id
       JOIN material_isolacao mi ON mi.id = c.material_isolacao_id
       WHERE pc.id = $1`,
      [produtoComercialId],
    );
    if (!rows[0]) return null;
    const r = rows[0];
    return {
      caboId: r.cabo_id,
      materialIsolacaoId: r.material_isolacao_id,
      materialCoberturaId: r.material_cobertura_id,
      classeEncordoamentoId: r.classe_encordoamento_id,
      grupoConstrutivoId: r.grupo_construtivo_id,
      grupoTermicoId: r.grupo_termico_id,
      tempCurtoCircuitoC: r.temp_curto_circuito_c,
    };
  }

  /** NBR 5410 Tabela 33: método de instalação × categoria de cabo -> método de referência. */
  async getMetodoReferencia(metodoInstalacaoId: number, categoriaCaboId: number) {
    const { rows } = await this.pool.query(
      `SELECT mr.id, mr.codigo
       FROM metodo_instalacao_referencia mir
       JOIN metodo_referencia mr ON mr.id = mir.metodo_referencia_id
       WHERE mir.metodo_instalacao_id = $1 AND mir.categoria_cabo_id = $2`,
      [metodoInstalacaoId, categoriaCaboId],
    );
    return rows[0] ?? null;
  }

  async listFatoresAgrupamento(tipo: 'ar' | 'enterrado') {
    if (tipo === 'ar') {
      const { rows } = await this.pool.query(
        `SELECT id, cenario, circuitos_min, circuitos_max, camadas_min, camadas_max,
                metodo_instalacao_grupo, fator
         FROM fator_agrupamento_ar ORDER BY id`,
      );
      return rows;
    }
    const { rows } = await this.pool.query(
      `SELECT id, cenario, numero_circuitos, distancia_desc, fator
       FROM fator_agrupamento_enterrado ORDER BY id`,
    );
    return rows;
  }

  async getFatorAgrupamento(tipo: 'ar' | 'enterrado', id: number): Promise<number | null> {
    const tabela = tipo === 'ar' ? 'fator_agrupamento_ar' : 'fator_agrupamento_enterrado';
    const { rows } = await this.pool.query(`SELECT fator FROM ${tabela} WHERE id = $1`, [id]);
    // node-postgres retorna NUMERIC como string por padrão — Number() explícito
    // evita concatenar string em vez de somar/multiplicar no motor de cálculo.
    return rows[0] ? Number(rows[0].fator) : null;
  }

  /** Temperaturas disponíveis (Tabela 40) para popular o select, filtradas pelo grupo térmico do cabo escolhido. */
  async listTemperaturas(tipoInstalacao: 'ambiente' | 'solo', grupoTermicoId: number) {
    const { rows } = await this.pool.query(
      `SELECT temperatura_c, fator
       FROM fator_correcao_temperatura
       WHERE tipo_instalacao = $1 AND grupo_termico_id = $2
       ORDER BY temperatura_c`,
      [tipoInstalacao, grupoTermicoId],
    );
    return rows;
  }

  async getFatorCorrecaoTemperatura(
    tipoInstalacao: 'ambiente' | 'solo',
    grupoTermicoId: number,
    temperaturaC: number,
  ): Promise<number | null> {
    const { rows } = await this.pool.query(
      `SELECT fator FROM fator_correcao_temperatura
       WHERE tipo_instalacao = $1 AND grupo_termico_id = $2 AND temperatura_c = $3`,
      [tipoInstalacao, grupoTermicoId, temperaturaC],
    );
    return rows[0] ? Number(rows[0].fator) : null;
  }
}
