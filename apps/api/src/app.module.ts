import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BtCatalogModule } from './bt-catalog/bt-catalog.module';
import { buildAppDataSourceOptions } from './config/typeorm.config';
import { CircuitosModule } from './circuitos/circuitos.module';
import { DimensionamentoModule } from './dimensionamento/dimensionamento.module';
import { ImportacaoModule } from './importacao/importacao.module';
import { MtCatalogModule } from './mt-catalog/mt-catalog.module';
import { ProjetosModule } from './projetos/projetos.module';
import { TipoCargaModule } from './tipo-carga/tipo-carga.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: buildAppDataSourceOptions,
    }),
    BullModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        connection: {
          host: config.get<string>('REDIS_HOST', 'localhost'),
          port: config.get<number>('REDIS_PORT', 6379),
        },
      }),
    }),
    BtCatalogModule,
    MtCatalogModule,
    ProjetosModule,
    TipoCargaModule,
    DimensionamentoModule,
    CircuitosModule,
    ImportacaoModule,
  ],
})
export class AppModule {}
