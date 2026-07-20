import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TipoCarga } from '../entities/tipo-carga.entity';
import { TipoCargaController } from './tipo-carga.controller';
import { TipoCargaService } from './tipo-carga.service';

@Module({
  imports: [TypeOrmModule.forFeature([TipoCarga])],
  controllers: [TipoCargaController],
  providers: [TipoCargaService],
  exports: [TipoCargaService],
})
export class TipoCargaModule {}
