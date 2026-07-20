import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

export type FatorAgrupamentoTipo = 'ar' | 'enterrado';

@Entity('circuitos')
export class Circuito {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'projeto_id' })
  projetoId: number;

  @Column()
  nome: string;

  @Column({ name: 'tipo_carga_id' })
  tipoCargaId: number;

  // Referências lógicas ao catálogo calc_cabos_bt (sem FK cross-database,
  // validadas em CircuitosService antes de gravar/calcular).
  @Column({ name: 'metodo_instalacao_id' })
  metodoInstalacaoId: number;

  @Column({ name: 'tipo_circuito_id' })
  tipoCircuitoId: number;

  @Column({ name: 'categoria_cabo_id' })
  categoriaCaboId: number;

  @Column({ name: 'produto_comercial_id' })
  produtoComercialId: number;

  @Column({ name: 'material_condutor_id' })
  materialCondutorId: number;

  @Column({ name: 'temperatura_ambiente_c' })
  temperaturaAmbienteC: number;

  @Column({ name: 'fator_agrupamento_tipo' })
  fatorAgrupamentoTipo: FatorAgrupamentoTipo;

  @Column({ name: 'fator_agrupamento_id' })
  fatorAgrupamentoId: number;

  @Column({ name: 'comprimento_m', type: 'numeric' })
  comprimentoM: number;

  @Column({ name: 'tensao_nominal_v', type: 'numeric' })
  tensaoNominalV: number;

  @Column({ name: 'corrente_a', type: 'numeric' })
  correnteA: number;

  @Column({ name: 'fator_potencia', type: 'numeric' })
  fatorPotencia: number;

  @Column({ name: 'corrente_curto_circuito_a', type: 'numeric' })
  correnteCurtoCircuitoA: number;

  @Column({ name: 'tempo_atuacao_curto_circuito_s', type: 'numeric' })
  tempoAtuacaoCurtoCircuitoS: number;

  @Column({ name: 'queda_tensao_nominal_max_pct', type: 'numeric' })
  quedaTensaoNominalMaxPct: number;

  @Column({ name: 'queda_tensao_partida_max_pct', type: 'numeric', nullable: true })
  quedaTensaoPartidaMaxPct: number | null;

  @Column({ name: 'fator_potencia_partida', type: 'numeric', nullable: true })
  fatorPotenciaPartida: number | null;

  @Column({ name: 'corrente_partida_a', type: 'numeric', nullable: true })
  correntePartidaA: number | null;

  @Column({ name: 'numero_condutores_paralelos_min' })
  numeroCondutoresParalelosMin: number;

  @Column({ name: 'numero_condutores_paralelos_max' })
  numeroCondutoresParalelosMax: number;

  @Column({ name: 'created_at' })
  createdAt: Date;

  @Column({ name: 'updated_at' })
  updatedAt: Date;
}
