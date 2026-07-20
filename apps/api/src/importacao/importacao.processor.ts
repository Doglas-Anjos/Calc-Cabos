import { Processor, WorkerHost } from '@nestjs/bullmq';
import { InjectRepository } from '@nestjs/typeorm';
import { Job } from 'bullmq';
import { read, utils } from 'xlsx';
import { Repository } from 'typeorm';
import { ImportJobItem } from '../entities/import-job-item.entity';
import { ImportJob } from '../entities/import-job.entity';
import { CircuitosService } from '../circuitos/circuitos.service';
import { CreateCircuitoDto } from '../circuitos/dto/create-circuito.dto';
import { IMPORT_CIRCUITOS_QUEUE, ImportCircuitosJobData } from './importacao.types';

/**
 * Worker da fila "import-circuitos" — único fluxo do app que roda
 * assíncrono via Redis/BullMQ (criar/editar um circuito manualmente é
 * síncrono, ver DimensionamentoService). Cada linha da planilha vira uma
 * chamada a CircuitosService.create; falha em uma linha não interrompe as
 * demais — fica registrada em import_job_itens.erro_msg.
 *
 * Cabeçalho esperado na planilha: mesmos nomes de campo de CreateCircuitoDto
 * (nome, tipoCargaId, metodoInstalacaoId, tipoCircuitoId, categoriaCaboId,
 * produtoComercialId, materialCondutorId, temperaturaAmbienteC,
 * fatorAgrupamentoTipo, fatorAgrupamentoId, comprimentoM, tensaoNominalV,
 * correnteA, fatorPotencia, correnteCurtoCircuitoA,
 * tempoAtuacaoCurtoCircuitoS, quedaTensaoNominalMaxPct e, para motores,
 * quedaTensaoPartidaMaxPct/fatorPotenciaPartida/correntePartidaA).
 */
@Processor(IMPORT_CIRCUITOS_QUEUE)
export class ImportacaoProcessor extends WorkerHost {
  constructor(
    @InjectRepository(ImportJob) private readonly jobRepo: Repository<ImportJob>,
    @InjectRepository(ImportJobItem) private readonly itemRepo: Repository<ImportJobItem>,
    private readonly circuitosService: CircuitosService,
  ) {
    super();
  }

  async process(job: Job<ImportCircuitosJobData>): Promise<void> {
    const { importJobId, projetoId, arquivoBase64 } = job.data;

    const workbook = read(Buffer.from(arquivoBase64, 'base64'), { type: 'buffer' });
    const primeiraAba = workbook.SheetNames[0];
    const linhas = utils.sheet_to_json<Record<string, unknown>>(workbook.Sheets[primeiraAba], { defval: null });

    await this.jobRepo.update(importJobId, { status: 'processing', totalLinhas: linhas.length });

    let processadas = 0;
    let comErro = 0;

    for (let i = 0; i < linhas.length; i++) {
      const linhaNumero = i + 2; // +1 cabeçalho, +1 índice 1-based
      const dadosOriginais = linhas[i];
      try {
        const dto = this.paraDto(dadosOriginais);
        const circuito = await this.circuitosService.create(projetoId, dto);
        await this.itemRepo.save(
          this.itemRepo.create({
            importJobId,
            linhaNumero,
            dadosOriginais,
            status: 'done',
            erroMsg: null,
            circuitoId: circuito.id,
          }),
        );
        processadas++;
      } catch (err) {
        comErro++;
        await this.itemRepo.save(
          this.itemRepo.create({
            importJobId,
            linhaNumero,
            dadosOriginais,
            status: 'failed',
            erroMsg: err instanceof Error ? err.message : 'Erro desconhecido',
            circuitoId: null,
          }),
        );
      }
      await this.jobRepo.update(importJobId, { linhasProcessadas: processadas, linhasErro: comErro });
    }

    await this.jobRepo.update(importJobId, { status: 'done', finishedAt: new Date() });
  }

  private paraDto(linha: Record<string, unknown>): CreateCircuitoDto {
    const dto = new CreateCircuitoDto();
    Object.assign(dto, linha);
    return dto;
  }
}
