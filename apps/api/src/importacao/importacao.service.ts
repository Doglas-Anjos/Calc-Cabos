import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Queue } from 'bullmq';
import { Repository } from 'typeorm';
import { ImportJob } from '../entities/import-job.entity';
import { ProjetosService } from '../projetos/projetos.service';
import { IMPORT_CIRCUITOS_QUEUE, ImportCircuitosJobData } from './importacao.types';

@Injectable()
export class ImportacaoService {
  constructor(
    @InjectRepository(ImportJob) private readonly jobRepo: Repository<ImportJob>,
    @InjectQueue(IMPORT_CIRCUITOS_QUEUE) private readonly queue: Queue<ImportCircuitosJobData>,
    private readonly projetosService: ProjetosService,
  ) {}

  async iniciarImportacao(projetoId: number, arquivoNome: string, buffer: Buffer): Promise<ImportJob> {
    await this.projetosService.findOneOrFail(projetoId);

    const job = await this.jobRepo.save(
      this.jobRepo.create({
        projetoId,
        arquivoNome,
        status: 'pending',
        totalLinhas: 0,
        linhasProcessadas: 0,
        linhasErro: 0,
        createdAt: new Date(),
        finishedAt: null,
      }),
    );

    await this.queue.add(IMPORT_CIRCUITOS_QUEUE, {
      importJobId: job.id,
      projetoId,
      arquivoBase64: buffer.toString('base64'),
    });

    return job;
  }

  async findOneOrFail(id: number): Promise<ImportJob> {
    const job = await this.jobRepo.findOneBy({ id });
    if (!job) throw new NotFoundException(`Job de importação ${id} não encontrado`);
    return job;
  }
}
