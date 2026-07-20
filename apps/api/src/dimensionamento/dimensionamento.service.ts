import { BadRequestException, Injectable } from '@nestjs/common';
import { CalculoDadosRepository } from '../bt-catalog/repositories/calculo-dados.repository';
import { CatalogoLookupsRepository } from '../bt-catalog/repositories/catalogo-lookups.repository';
import {
  NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO,
  NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO,
} from '../config/constants';
import { DimensionamentoInput, DimensionamentoResultado } from './dimensionamento.types';

interface SecaoCandidata {
  id: number;
  valorMm2: number;
}

interface AvaliacaoSecao {
  ok: boolean;
  capacidadeCorrigidaA: number;
  quedaTensaoPct: number;
  quedaTensaoPartidaPct: number | null;
  arranjoAssumido: boolean;
  arranjoEspacamentoUsado: string;
}

interface BuscaPorNResultado {
  secaoFinal: SecaoCandidata;
  secaoEletricaMm2: number;
  avaliacaoFinal: AvaliacaoSecao;
  secaoMinimaCurtoCircuitoMm2: number;
  fatorK: number;
}

/**
 * Motor de dimensionamento de baixa tensão — NBR 5410:2004. Encontra a menor
 * seção nominal — e o menor número de condutores em paralelo por fase
 * (§6.2.5.7, N=numeroCondutoresParalelosMin..Max) — que atende,
 * simultaneamente, ampacidade (§6.2.5), queda de tensão (§6.2, ADR 0007) e
 * suportabilidade ao curto-circuito (§5.3.5.5). Com N condutores idênticos em
 * paralelo, a corrente se divide igualmente entre eles (I/N) e a R/XL
 * equivalente cai na mesma proporção (R/N, XL/N) — algebricamente equivale a
 * rodar a mesma busca de seção "como se fosse 1 condutor" usando corrente/N
 * (nominal, de partida e de curto-circuito), daí buscarSecaoParaCorrente
 * abaixo não precisar reimplementar a física, só escalar as correntes.
 *
 * Tenta N=min primeiro; só avança para N+1 quando NENHUMA seção do catálogo
 * atende com o N atual — não otimiza custo total de cobre entre soluções
 * viáveis com N diferentes, para no primeiro N que funcionar.
 *
 * Simplificações assumidas nesta primeira versão (ver docs/adr ou o plano
 * desta rodada): usa sempre numero_condutores_carregados "base" de
 * tipo_circuito (não aplica o fator 0,86 do 4º condutor, §6.2.5.6.1); quando
 * a norma exige uma topologia física (arranjo_ampacidade) que o formulário
 * não captura, assume a menor arranjo disponível — sinalizado em
 * memoriaCalculo.avisos; e não aplica derating adicional de agrupamento
 * entre os N condutores em paralelo (tratados como um único circuito).
 */
@Injectable()
export class DimensionamentoService {
  constructor(
    private readonly lookups: CatalogoLookupsRepository,
    private readonly calculoDados: CalculoDadosRepository,
  ) {}

  async calcular(input: DimensionamentoInput): Promise<DimensionamentoResultado> {
    const avisos: string[] = [];

    if (
      input.numeroCondutoresParalelosMin < NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO ||
      input.numeroCondutoresParalelosMax > NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO ||
      input.numeroCondutoresParalelosMin > input.numeroCondutoresParalelosMax
    ) {
      throw new BadRequestException(
        `Intervalo de condutores em paralelo inválido (permitido: ${NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO} a ${NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO})`,
      );
    }

    const tipoCircuito = await this.lookups.getTipoCircuito(input.tipoCircuitoId);
    if (!tipoCircuito) throw new BadRequestException('tipoCircuitoId inválido');

    const cabo = await this.lookups.resolveCaboEspecificacao(input.produtoComercialId);
    if (!cabo) throw new BadRequestException('produtoComercialId inválido');

    const metodoReferencia = await this.lookups.getMetodoReferencia(
      input.metodoInstalacaoId,
      input.categoriaCaboId,
    );
    if (!metodoReferencia) {
      throw new BadRequestException(
        'Combinação de método de instalação e tipo de cabo não prevista na NBR 5410 Tabela 33',
      );
    }

    const tipoInstalacaoTemperatura = input.fatorAgrupamentoTipo === 'ar' ? 'ambiente' : 'solo';
    const fatorTemperatura = await this.lookups.getFatorCorrecaoTemperatura(
      tipoInstalacaoTemperatura,
      cabo.grupoTermicoId,
      input.temperaturaAmbienteC,
    );
    if (fatorTemperatura === null) {
      throw new BadRequestException('Não há fator de correção de temperatura para os valores informados');
    }

    const fatorAgrupamento = await this.lookups.getFatorAgrupamento(
      input.fatorAgrupamentoTipo,
      input.fatorAgrupamentoId,
    );
    if (fatorAgrupamento === null) {
      throw new BadRequestException('fatorAgrupamentoId inválido para o tipo informado');
    }

    const multiplicador = tipoCircuito.formula_queda_tensao === 'trifasica' ? Math.sqrt(3) : 2;
    const secoes = await this.calculoDados.listSecoesNominaisAscendentes();

    const avaliar = async (
      secao: SecaoCandidata,
      correnteEfetivaA: number,
      correntePartidaEfetivaA: number | null,
    ): Promise<AvaliacaoSecao | null> => {
      const cap = await this.calculoDados.getCapacidadeConducao(
        cabo.grupoTermicoId,
        input.materialCondutorId,
        metodoReferencia.id,
        tipoCircuito.numero_condutores_carregados,
        secao.id,
      );
      if (!cap) return null;
      const capacidadeCorrigidaA = cap.correnteAdmissivelA * fatorTemperatura * fatorAgrupamento;
      if (capacidadeCorrigidaA < correnteEfetivaA) {
        return {
          ok: false,
          capacidadeCorrigidaA,
          quedaTensaoPct: NaN,
          quedaTensaoPartidaPct: null,
          arranjoAssumido: cap.arranjoAssumido,
          arranjoEspacamentoUsado: '',
        };
      }

      const rr = await this.calculoDados.getResistenciaReatancia(
        cabo.grupoConstrutivoId,
        input.produtoComercialId,
        input.materialCondutorId,
        secao.id,
        tipoCircuito.numero_condutores_carregados,
      );
      if (!rr) return null;

      const comprimentoKm = input.comprimentoM / 1000;
      const senFi = Math.sqrt(1 - input.fatorPotencia ** 2);
      const quedaV =
        multiplicador *
        (rr.resistenciaCaOhmKm * input.fatorPotencia + rr.reatanciaIndutivaOhmKm * senFi) *
        correnteEfetivaA *
        comprimentoKm;
      const quedaTensaoPct = (quedaV / input.tensaoNominalV) * 100;

      let quedaTensaoPartidaPct: number | null = null;
      if (input.isMotor && input.fatorPotenciaPartida != null && correntePartidaEfetivaA != null) {
        const senFiPartida = Math.sqrt(1 - input.fatorPotenciaPartida ** 2);
        const quedaPartidaV =
          multiplicador *
          (rr.resistenciaCaOhmKm * input.fatorPotenciaPartida + rr.reatanciaIndutivaOhmKm * senFiPartida) *
          correntePartidaEfetivaA *
          comprimentoKm;
        quedaTensaoPartidaPct = (quedaPartidaV / input.tensaoNominalV) * 100;
      }

      const quedaOk = quedaTensaoPct <= input.quedaTensaoNominalMaxPct;
      const quedaPartidaOk =
        quedaTensaoPartidaPct === null || quedaTensaoPartidaPct <= (input.quedaTensaoPartidaMaxPct ?? Infinity);

      return {
        ok: quedaOk && quedaPartidaOk,
        capacidadeCorrigidaA,
        quedaTensaoPct,
        quedaTensaoPartidaPct,
        arranjoAssumido: cap.arranjoAssumido,
        arranjoEspacamentoUsado: rr.arranjoEspacamentoUsado,
      };
    };

    /** Busca a menor seção que atende com N condutores em paralelo (corrente/N em cada um), ou null se nenhuma seção do catálogo servir. */
    const buscarParaN = async (n: number): Promise<BuscaPorNResultado | null> => {
      const correnteEfetivaA = input.correnteA / n;
      const correntePartidaEfetivaA = input.correntePartidaA != null ? input.correntePartidaA / n : null;

      let secaoEletrica: SecaoCandidata | null = null;
      let avaliacaoEletrica: AvaliacaoSecao | null = null;
      for (const secao of secoes) {
        const avaliacao = await avaliar(secao, correnteEfetivaA, correntePartidaEfetivaA);
        if (avaliacao?.ok) {
          secaoEletrica = secao;
          avaliacaoEletrica = avaliacao;
          break;
        }
      }
      if (!secaoEletrica || !avaliacaoEletrica) return null;

      if (avaliacaoEletrica.arranjoAssumido) {
        avisos.push(
          'O formulário não captura a topologia física dos condutores (arranjo); assumida a menor arranjo_ampacidade disponível para o método de referência.',
        );
      }

      const fatorK = await this.calculoDados.getFatorKCurtoCircuito(
        cabo.materialIsolacaoId,
        input.materialCondutorId,
        secaoEletrica.valorMm2,
      );
      if (fatorK === null) {
        throw new BadRequestException('Não há fator k de curto-circuito para o material/seção calculados');
      }
      const correnteCurtoCircuitoEfetivaA = input.correnteCurtoCircuitoA / n;
      const secaoMinimaCurtoCircuitoMm2 =
        (correnteCurtoCircuitoEfetivaA * Math.sqrt(input.tempoAtuacaoCurtoCircuitoS)) / fatorK;

      let secaoFinal = secaoEletrica;
      let avaliacaoFinal = avaliacaoEletrica;
      if (secaoMinimaCurtoCircuitoMm2 > secaoEletrica.valorMm2) {
        const candidata = secoes.find((s) => s.valorMm2 >= secaoMinimaCurtoCircuitoMm2);
        if (!candidata) return null;
        const reavaliacao = await avaliar(candidata, correnteEfetivaA, correntePartidaEfetivaA);
        if (!reavaliacao) return null;
        secaoFinal = candidata;
        avaliacaoFinal = reavaliacao;
      }

      return {
        secaoFinal,
        secaoEletricaMm2: secaoEletrica.valorMm2,
        avaliacaoFinal,
        secaoMinimaCurtoCircuitoMm2,
        fatorK,
      };
    };

    for (let n = input.numeroCondutoresParalelosMin; n <= input.numeroCondutoresParalelosMax; n++) {
      const resultado = await buscarParaN(n);
      if (!resultado) continue;

      if (n > input.numeroCondutoresParalelosMin) {
        avisos.push(
          `Não foi possível atender com ${input.numeroCondutoresParalelosMin} condutor(es) em paralelo; usados ${n}.`,
        );
      }

      return {
        secaoCalculadaMm2: resultado.secaoFinal.valorMm2,
        correnteAdmissivelCorrigidaA: resultado.avaliacaoFinal.capacidadeCorrigidaA,
        quedaTensaoCalculadaPct: resultado.avaliacaoFinal.quedaTensaoPct,
        quedaTensaoPartidaCalculadaPct: resultado.avaliacaoFinal.quedaTensaoPartidaPct,
        secaoMinimaCurtoCircuitoMm2: resultado.secaoMinimaCurtoCircuitoMm2,
        numeroCondutoresParalelosCalculado: n,
        viavel: true,
        memoriaCalculo: {
          metodoReferencia: metodoReferencia.codigo,
          numeroCondutoresCarregados: tipoCircuito.numero_condutores_carregados,
          formulaQuedaTensao: tipoCircuito.formula_queda_tensao,
          fatorTemperatura,
          fatorAgrupamento,
          fatorK: resultado.fatorK,
          arranjoEspacamentoUsado: resultado.avaliacaoFinal.arranjoEspacamentoUsado,
          numeroCondutoresParalelos: n,
          secaoEletricaMm2: resultado.secaoEletricaMm2,
          secaoFinalMm2: resultado.secaoFinal.valorMm2,
          avisos,
        },
      };
    }

    return {
      secaoCalculadaMm2: null,
      correnteAdmissivelCorrigidaA: null,
      quedaTensaoCalculadaPct: null,
      quedaTensaoPartidaCalculadaPct: null,
      secaoMinimaCurtoCircuitoMm2: null,
      numeroCondutoresParalelosCalculado: null,
      viavel: false,
      memoriaCalculo: {
        motivo: `Nenhuma seção do catálogo atende ampacidade, queda de tensão e/ou curto-circuito, mesmo testando de ${input.numeroCondutoresParalelosMin} a ${input.numeroCondutoresParalelosMax} condutor(es) em paralelo por fase.`,
        metodoReferencia: metodoReferencia.codigo,
        fatorTemperatura,
        fatorAgrupamento,
        avisos,
      },
    };
  }
}
