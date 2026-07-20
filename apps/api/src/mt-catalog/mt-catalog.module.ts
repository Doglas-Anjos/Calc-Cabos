import { Module } from '@nestjs/common';
import { mtPoolProvider } from './mt-pool.provider';

@Module({
  providers: [mtPoolProvider],
  exports: [mtPoolProvider],
})
export class MtCatalogModule {}
