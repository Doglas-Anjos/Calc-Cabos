import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

export const TIPO_CARGA_MOTOR = 'Motor';

@Entity('tipo_carga')
export class TipoCarga {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  nome: string;
}
