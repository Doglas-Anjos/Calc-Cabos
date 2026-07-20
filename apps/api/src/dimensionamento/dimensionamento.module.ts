import { Module } from '@nestjs/common';
import { BtCatalogModule } from '../bt-catalog/bt-catalog.module';
import { DimensionamentoService } from './dimensionamento.service';

@Module({
  imports: [BtCatalogModule],
  providers: [DimensionamentoService],
  exports: [DimensionamentoService],
})
export class DimensionamentoModule {}
