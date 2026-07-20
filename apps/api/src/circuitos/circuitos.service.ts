import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO,
  NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO,
} from '../config/constants';
import { Circuito } from '../entities/circuito.entity';
import { ResultadoCalculo } from '../entities/resultado-calculo.entity';
import { DimensionamentoService } from '../dimensionamento/dimensionamento.service';
import { ProjetosService } from '../projetos/projetos.service';
import { TipoCargaService } from '../tipo-carga/tipo-carga.service';
import { CreateCircuitoDto } from './dto/create-circuito.dto';
import { UpdateCircuitoDto } from './dto/update-circuito.dto';

@Injectable()
export class CircuitosService {
  constructor(
    @InjectRepository(Circuito) private readonly circuitoRepo: Repository<Circuito>,
    @InjectRepository(ResultadoCalculo) private readonly resultadoRepo: Repository<ResultadoCalculo>,
    private readonly projetosService: ProjetosService,
    private readonly tipoCargaService: TipoCargaService,
    private readonly dimensionamentoService: DimensionamentoService,
  ) {}

  async findAllByProjeto(projetoId: number) {
    await this.projetosService.findOneOrFail(projetoId);
    const circuitos = await this.circuitoRepo.find({ where: { projetoId }, order: { createdAt: 'DESC' } });
    return Promise.all(circuitos.map((c) => this.comResultadoAtual(c)));
  }

  async findOneOrFail(id: number) {
    const circuito = await this.circuitoRepo.findOneBy({ id });
    if (!circuito) throw new NotFoundException(`Circuito ${id} não encontrado`);
    return this.comResultadoAtual(circuito);
  }

  async create(projetoId: number, dto: CreateCircuitoDto) {
    await this.projetosService.findOneOrFail(projetoId);

    const existente = await this.circuitoRepo.findOneBy({ projetoId, nome: dto.nome });
    if (existente) throw new ConflictException(`Já existe um circuito com o nome "${dto.nome}" neste projeto`);

    const isMotor = await this.tipoCargaService.isMotor(dto.tipoCargaId);
    this.validarCamposPartida(dto, isMotor);

    const numeroCondutoresParalelosMin = dto.numeroCondutoresParalelosMin ?? NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO;
    const numeroCondutoresParalelosMax = dto.numeroCondutoresParalelosMax ?? NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO;
    this.validarIntervaloParalelos(numeroCondutoresParalelosMin, numeroCondutoresParalelosMax);

    const agora = new Date();
    const circuito = this.circuitoRepo.create({
      projetoId,
      nome: dto.nome,
      tipoCargaId: dto.tipoCargaId,
      metodoInstalacaoId: dto.metodoInstalacaoId,
      tipoCircuitoId: dto.tipoCircuitoId,
      categoriaCaboId: dto.categoriaCaboId,
      produtoComercialId: dto.produtoComercialId,
      materialCondutorId: dto.materialCondutorId,
      temperaturaAmbienteC: dto.temperaturaAmbienteC,
      fatorAgrupamentoTipo: dto.fatorAgrupamentoTipo,
      fatorAgrupamentoId: dto.fatorAgrupamentoId,
      comprimentoM: dto.comprimentoM,
      tensaoNominalV: dto.tensaoNominalV,
      correnteA: dto.correnteA,
      fatorPotencia: dto.fatorPotencia,
      correnteCurtoCircuitoA: dto.correnteCurtoCircuitoA,
      tempoAtuacaoCurtoCircuitoS: dto.tempoAtuacaoCurtoCircuitoS,
      quedaTensaoNominalMaxPct: dto.quedaTensaoNominalMaxPct,
      quedaTensaoPartidaMaxPct: isMotor ? dto.quedaTensaoPartidaMaxPct ?? null : null,
      fatorPotenciaPartida: isMotor ? dto.fatorPotenciaPartida ?? null : null,
      correntePartidaA: isMotor ? dto.correntePartidaA ?? null : null,
      numeroCondutoresParalelosMin,
      numeroCondutoresParalelosMax,
      createdAt: agora,
      updatedAt: agora,
    });
    const salvo = await this.circuitoRepo.save(circuito);
    const resultado = await this.calcularEPersistir(salvo, isMotor);
    return { ...salvo, resultadoAtual: resultado };
  }

  async update(id: number, dto: UpdateCircuitoDto) {
    const circuito = await this.circuitoRepo.findOneBy({ id });
    if (!circuito) throw new NotFoundException(`Circuito ${id} não encontrado`);

    if (dto.nome && dto.nome !== circuito.nome) {
      const existente = await this.circuitoRepo.findOneBy({ projetoId: circuito.projetoId, nome: dto.nome });
      if (existente) throw new ConflictException(`Já existe um circuito com o nome "${dto.nome}" neste projeto`);
    }

    const tipoCargaId = dto.tipoCargaId ?? circuito.tipoCargaId;
    const isMotor = await this.tipoCargaService.isMotor(tipoCargaId);
    this.validarCamposPartida({ ...circuito, ...dto }, isMotor);

    Object.assign(circuito, dto);
    circuito.tipoCargaId = tipoCargaId;
    if (!isMotor) {
      circuito.quedaTensaoPartidaMaxPct = null;
      circuito.fatorPotenciaPartida = null;
      circuito.correntePartidaA = null;
    }
    this.validarIntervaloParalelos(circuito.numeroCondutoresParalelosMin, circuito.numeroCondutoresParalelosMax);
    circuito.updatedAt = new Date();
    const salvo = await this.circuitoRepo.save(circuito);
    const resultado = await this.calcularEPersistir(salvo, isMotor);
    return { ...salvo, resultadoAtual: resultado };
  }

  async remove(id: number) {
    const circuito = await this.circuitoRepo.findOneBy({ id });
    if (!circuito) throw new NotFoundException(`Circuito ${id} não encontrado`);
    await this.resultadoRepo.delete({ circuitoId: id });
    await this.circuitoRepo.remove(circuito);
  }

  private validarCamposPartida(
    dto: {
      quedaTensaoPartidaMaxPct?: number | null;
      fatorPotenciaPartida?: number | null;
      correntePartidaA?: number | null;
    },
    isMotor: boolean,
  ) {
    if (!isMotor) return;
    if (dto.quedaTensaoPartidaMaxPct == null || dto.fatorPotenciaPartida == null || dto.correntePartidaA == null) {
      throw new BadRequestException(
        'Para tipo de carga Motor, queda de tensão na partida, fator de potência na partida e corrente de partida são obrigatórios',
      );
    }
  }

  private validarIntervaloParalelos(min: number, max: number) {
    if (
      min < NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO ||
      max > NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO ||
      min > max
    ) {
      throw new BadRequestException(
        `Intervalo de condutores em paralelo inválido (permitido: ${NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO} a ${NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO})`,
      );
    }
  }

  private async calcularEPersistir(circuito: Circuito, isMotor: boolean): Promise<ResultadoCalculo> {
    const resultado = await this.dimensionamentoService.calcular({
      tipoCircuitoId: circuito.tipoCircuitoId,
      metodoInstalacaoId: circuito.metodoInstalacaoId,
      categoriaCaboId: circuito.categoriaCaboId,
      produtoComercialId: circuito.produtoComercialId,
      materialCondutorId: circuito.materialCondutorId,
      temperaturaAmbienteC: circuito.temperaturaAmbienteC,
      fatorAgrupamentoTipo: circuito.fatorAgrupamentoTipo,
      fatorAgrupamentoId: circuito.fatorAgrupamentoId,
      comprimentoM: Number(circuito.comprimentoM),
      tensaoNominalV: Number(circuito.tensaoNominalV),
      correnteA: Number(circuito.correnteA),
      fatorPotencia: Number(circuito.fatorPotencia),
      correnteCurtoCircuitoA: Number(circuito.correnteCurtoCircuitoA),
      tempoAtuacaoCurtoCircuitoS: Number(circuito.tempoAtuacaoCurtoCircuitoS),
      quedaTensaoNominalMaxPct: Number(circuito.quedaTensaoNominalMaxPct),
      isMotor,
      quedaTensaoPartidaMaxPct:
        circuito.quedaTensaoPartidaMaxPct != null ? Number(circuito.quedaTensaoPartidaMaxPct) : null,
      fatorPotenciaPartida: circuito.fatorPotenciaPartida != null ? Number(circuito.fatorPotenciaPartida) : null,
      correntePartidaA: circuito.correntePartidaA != null ? Number(circuito.correntePartidaA) : null,
      numeroCondutoresParalelosMin: circuito.numeroCondutoresParalelosMin,
      numeroCondutoresParalelosMax: circuito.numeroCondutoresParalelosMax,
    });

    const entidade = this.resultadoRepo.create({
      circuitoId: circuito.id,
      secaoCalculadaMm2: resultado.secaoCalculadaMm2,
      correnteAdmissivelCorrigidaA: resultado.correnteAdmissivelCorrigidaA,
      quedaTensaoCalculadaPct: resultado.quedaTensaoCalculadaPct,
      quedaTensaoPartidaCalculadaPct: resultado.quedaTensaoPartidaCalculadaPct,
      secaoMinimaCurtoCircuitoMm2: resultado.secaoMinimaCurtoCircuitoMm2,
      numeroCondutoresParalelosCalculado: resultado.numeroCondutoresParalelosCalculado,
      viavel: resultado.viavel,
      memoriaCalculo: resultado.memoriaCalculo,
      createdAt: new Date(),
    });
    return this.resultadoRepo.save(entidade);
  }

  private async comResultadoAtual(circuito: Circuito) {
    const resultadoAtual = await this.resultadoRepo.findOne({
      where: { circuitoId: circuito.id },
      order: { createdAt: 'DESC' },
    });
    return { ...circuito, resultadoAtual: resultadoAtual ?? null };
  }
}
