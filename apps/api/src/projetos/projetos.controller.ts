import { Body, Controller, Get, Param, ParseIntPipe, Post } from '@nestjs/common';
import { CreateProjetoDto } from './dto/create-projeto.dto';
import { ProjetosService } from './projetos.service';

@Controller('projetos')
export class ProjetosController {
  constructor(private readonly service: ProjetosService) {}

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOneOrFail(id);
  }

  @Post()
  create(@Body() dto: CreateProjetoDto) {
    return this.service.create(dto);
  }
}
