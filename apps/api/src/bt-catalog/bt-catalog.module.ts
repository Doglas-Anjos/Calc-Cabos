import { Module } from '@nestjs/common';
import { BtCatalogController } from './bt-catalog.controller';
import { btPoolProvider } from './bt-pool.provider';
import { CalculoDadosRepository } from './repositories/calculo-dados.repository';
import { CatalogoLookupsRepository } from './repositories/catalogo-lookups.repository';

@Module({
  controllers: [BtCatalogController],
  providers: [btPoolProvider, CatalogoLookupsRepository, CalculoDadosRepository],
  exports: [btPoolProvider, CatalogoLookupsRepository, CalculoDadosRepository],
})
export class BtCatalogModule {}
