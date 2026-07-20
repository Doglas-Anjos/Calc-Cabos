import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('resultados_calculo')
export class ResultadoCalculo {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'circuito_id' })
  circuitoId: number;

  @Column({ name: 'secao_calculada_mm2', type: 'numeric', nullable: true })
  secaoCalculadaMm2: number | null;

  @Column({ name: 'corrente_admissivel_corrigida_a', type: 'numeric', nullable: true })
  correnteAdmissivelCorrigidaA: number | null;

  @Column({ name: 'queda_tensao_calculada_pct', type: 'numeric', nullable: true })
  quedaTensaoCalculadaPct: number | null;

  @Column({ name: 'queda_tensao_partida_calculada_pct', type: 'numeric', nullable: true })
  quedaTensaoPartidaCalculadaPct: number | null;

  @Column({ name: 'secao_minima_curto_circuito_mm2', type: 'numeric', nullable: true })
  secaoMinimaCurtoCircuitoMm2: number | null;

  @Column({ name: 'numero_condutores_paralelos_calculado', type: 'int', nullable: true })
  numeroCondutoresParalelosCalculado: number | null;

  @Column()
  viavel: boolean;

  @Column({ name: 'memoria_calculo', type: 'jsonb' })
  memoriaCalculo: Record<string, unknown>;

  @Column({ name: 'created_at' })
  createdAt: Date;
}
