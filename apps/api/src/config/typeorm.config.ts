import { ConfigService } from '@nestjs/config';
import { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { Circuito } from '../entities/circuito.entity';
import { ImportJobItem } from '../entities/import-job-item.entity';
import { ImportJob } from '../entities/import-job.entity';
import { Projeto } from '../entities/projeto.entity';
import { ResultadoCalculo } from '../entities/resultado-calculo.entity';
import { TipoCarga } from '../entities/tipo-carga.entity';
import { Usuario } from '../entities/usuario.entity';

// synchronize:false de propósito — o schema de calc_cabos_app é versionado
// em database/app/*.sql (mesmo padrão do catálogo bt), não gerado pelo
// TypeORM. Entities aqui só mapeiam para as tabelas já criadas pelos
// scripts de init do docker-compose.
export function buildAppDataSourceOptions(config: ConfigService): TypeOrmModuleOptions {
  return {
    type: 'postgres',
    host: config.get<string>('APP_DB_HOST', 'localhost'),
    port: config.get<number>('APP_DB_PORT', 5433),
    username: config.get<string>('APP_DB_USER', 'calc_cabos'),
    password: config.get<string>('APP_DB_PASSWORD', 'calc_cabos'),
    database: config.get<string>('APP_DB_NAME', 'calc_cabos_app'),
    entities: [Usuario, Projeto, TipoCarga, Circuito, ResultadoCalculo, ImportJob, ImportJobItem],
    synchronize: false,
  };
}
