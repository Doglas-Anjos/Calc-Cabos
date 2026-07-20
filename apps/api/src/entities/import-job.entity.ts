import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

export type ImportJobStatus = 'pending' | 'processing' | 'done' | 'failed';

@Entity('import_jobs')
export class ImportJob {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'projeto_id' })
  projetoId: number;

  @Column({ name: 'arquivo_nome' })
  arquivoNome: string;

  @Column()
  status: ImportJobStatus;

  @Column({ name: 'total_linhas' })
  totalLinhas: number;

  @Column({ name: 'linhas_processadas' })
  linhasProcessadas: number;

  @Column({ name: 'linhas_erro' })
  linhasErro: number;

  @Column({ name: 'created_at' })
  createdAt: Date;

  @Column({ name: 'finished_at', type: 'timestamptz', nullable: true })
  finishedAt: Date | null;
}
