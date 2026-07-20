import { ConfigService } from '@nestjs/config';
import { Provider } from '@nestjs/common';
import { Pool } from 'pg';

// Conexão reservada para a futura calculadora de média tensão — calc_cabos_mt
// sobe vazio (ver database/mt/README.md). Nenhum módulo consome este pool
// ainda; existe só para não exigir reestruturação de infra quando o
// desenvolvimento de MT começar.
export const MT_POOL = 'MT_POOL';

export const mtPoolProvider: Provider = {
  provide: MT_POOL,
  inject: [ConfigService],
  useFactory: (config: ConfigService) =>
    new Pool({
      host: config.get<string>('MT_DB_HOST', 'localhost'),
      port: config.get<number>('MT_DB_PORT', 5434),
      user: config.get<string>('MT_DB_USER', 'calc_cabos'),
      password: config.get<string>('MT_DB_PASSWORD', 'calc_cabos'),
      database: config.get<string>('MT_DB_NAME', 'calc_cabos_mt'),
    }),
};
