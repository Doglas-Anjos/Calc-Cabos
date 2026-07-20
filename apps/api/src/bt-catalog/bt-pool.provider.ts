import { ConfigService } from '@nestjs/config';
import { Provider } from '@nestjs/common';
import { Pool } from 'pg';

export const BT_POOL = 'BT_POOL';

export const btPoolProvider: Provider = {
  provide: BT_POOL,
  inject: [ConfigService],
  useFactory: (config: ConfigService) =>
    new Pool({
      host: config.get<string>('BT_DB_HOST', 'localhost'),
      port: config.get<number>('BT_DB_PORT', 5432),
      user: config.get<string>('BT_DB_USER', 'calc_cabos'),
      password: config.get<string>('BT_DB_PASSWORD', 'calc_cabos'),
      database: config.get<string>('BT_DB_NAME', 'calc_cabos_bt'),
    }),
};
