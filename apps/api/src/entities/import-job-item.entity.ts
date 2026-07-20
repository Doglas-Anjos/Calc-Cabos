import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

export type ImportJobItemStatus = 'pending' | 'done' | 'failed';

@Entity('import_job_itens')
export class ImportJobItem {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'import_job_id' })
  importJobId: number;

  @Column({ name: 'linha_numero' })
  linhaNumero: number;

  @Column({ name: 'dados_originais', type: 'jsonb' })
  dadosOriginais: Record<string, unknown>;

  @Column()
  status: ImportJobItemStatus;

  @Column({ name: 'erro_msg', type: 'text', nullable: true })
  erroMsg: string | null;

  @Column({ name: 'circuito_id', type: 'int', nullable: true })
  circuitoId: number | null;
}
