import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CircuitosModule } from '../circuitos/circuitos.module';
import { ImportJobItem } from '../entities/import-job-item.entity';
import { ImportJob } from '../entities/import-job.entity';
import { ProjetosModule } from '../projetos/projetos.module';
import { ImportacaoController } from './importacao.controller';
import { ImportacaoProcessor } from './importacao.processor';
import { ImportacaoService } from './importacao.service';
import { IMPORT_CIRCUITOS_QUEUE } from './importacao.types';

@Module({
  imports: [
    TypeOrmModule.forFeature([ImportJob, ImportJobItem]),
    BullModule.registerQueue({ name: IMPORT_CIRCUITOS_QUEUE }),
    CircuitosModule,
    ProjetosModule,
  ],
  controllers: [ImportacaoController],
  providers: [ImportacaoService, ImportacaoProcessor],
})
export class ImportacaoModule {}
