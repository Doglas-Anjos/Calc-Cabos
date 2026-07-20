import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { CalculoDadosRepository } from './repositories/calculo-dados.repository';
import { CatalogoLookupsRepository } from './repositories/catalogo-lookups.repository';

@Controller('catalogo-bt')
export class BtCatalogController {
  constructor(
    private readonly lookups: CatalogoLookupsRepository,
    private readonly calculoDados: CalculoDadosRepository,
  ) {}

  @Get('tipos-circuito')
  listTiposCircuito() {
    return this.lookups.listTiposCircuito();
  }

  @Get('metodos-instalacao')
  listMetodosInstalacao() {
    return this.lookups.listMetodosInstalacao();
  }

  @Get('categorias-cabo')
  listCategoriasCabo() {
    return this.lookups.listCategoriasCabo();
  }

  @Get('materiais-condutor')
  listMateriaisCondutor() {
    return this.lookups.listMateriaisCondutor();
  }

  @Get('produtos-comerciais')
  listProdutosComerciais() {
    return this.lookups.listProdutosComerciais();
  }

  @Get('fatores-agrupamento')
  async listFatoresAgrupamento(@Query('tipo') tipo: string) {
    if (tipo !== 'ar' && tipo !== 'enterrado') {
      throw new BadRequestException('tipo deve ser "ar" ou "enterrado"');
    }
    return this.lookups.listFatoresAgrupamento(tipo);
  }

  /** Temperaturas disponíveis para o cabo (produto comercial) e tipo de instalação escolhidos. */
  @Get('temperaturas')
  async listTemperaturas(
    @Query('produtoComercialId') produtoComercialIdRaw: string,
    @Query('fatorAgrupamentoTipo') fatorAgrupamentoTipo: string,
  ) {
    const produtoComercialId = Number(produtoComercialIdRaw);
    if (!produtoComercialId) throw new BadRequestException('produtoComercialId é obrigatório');
    if (fatorAgrupamentoTipo !== 'ar' && fatorAgrupamentoTipo !== 'enterrado') {
      throw new BadRequestException('fatorAgrupamentoTipo deve ser "ar" ou "enterrado"');
    }
    const cabo = await this.lookups.resolveCaboEspecificacao(produtoComercialId);
    if (!cabo) throw new BadRequestException('produtoComercialId inválido');
    const tipoInstalacao = fatorAgrupamentoTipo === 'ar' ? 'ambiente' : 'solo';
    return this.lookups.listTemperaturas(tipoInstalacao, cabo.grupoTermicoId);
  }
}
