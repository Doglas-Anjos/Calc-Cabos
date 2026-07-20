import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Circuito } from '../entities/circuito.entity';
import { ResultadoCalculo } from '../entities/resultado-calculo.entity';
import { DimensionamentoModule } from '../dimensionamento/dimensionamento.module';
import { ProjetosModule } from '../projetos/projetos.module';
import { TipoCargaModule } from '../tipo-carga/tipo-carga.module';
import { CircuitosController, ProjetoCircuitosController } from './circuitos.controller';
import { CircuitosService } from './circuitos.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Circuito, ResultadoCalculo]),
    DimensionamentoModule,
    ProjetosModule,
    TipoCargaModule,
  ],
  controllers: [ProjetoCircuitosController, CircuitosController],
  providers: [CircuitosService],
  exports: [CircuitosService],
})
export class CircuitosModule {}
