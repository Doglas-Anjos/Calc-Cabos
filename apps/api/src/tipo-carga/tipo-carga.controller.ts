import { Controller, Get } from '@nestjs/common';
import { TipoCargaService } from './tipo-carga.service';

@Controller('tipos-carga')
export class TipoCargaController {
  constructor(private readonly service: TipoCargaService) {}

  @Get()
  findAll() {
    return this.service.findAll();
  }
}
