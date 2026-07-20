import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TIPO_CARGA_MOTOR, TipoCarga } from '../entities/tipo-carga.entity';

@Injectable()
export class TipoCargaService {
  constructor(@InjectRepository(TipoCarga) private readonly repo: Repository<TipoCarga>) {}

  findAll() {
    return this.repo.find({ order: { id: 'ASC' } });
  }

  async isMotor(tipoCargaId: number): Promise<boolean> {
    const tipo = await this.repo.findOneBy({ id: tipoCargaId });
    return tipo?.nome === TIPO_CARGA_MOTOR;
  }
}
