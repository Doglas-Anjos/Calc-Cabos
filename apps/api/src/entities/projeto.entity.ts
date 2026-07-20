import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('projetos')
export class Projeto {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'usuario_id' })
  usuarioId: number;

  @Column()
  nome: string;

  @Column({ type: 'text', nullable: true })
  descricao: string | null;

  @Column({ name: 'created_at' })
  createdAt: Date;
}
