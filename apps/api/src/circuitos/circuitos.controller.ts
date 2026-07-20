import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { CircuitosService } from './circuitos.service';
import { CreateCircuitoDto } from './dto/create-circuito.dto';
import { UpdateCircuitoDto } from './dto/update-circuito.dto';

@Controller('projetos/:projetoId/circuitos')
export class ProjetoCircuitosController {
  constructor(private readonly service: CircuitosService) {}

  @Get()
  findAll(@Param('projetoId', ParseIntPipe) projetoId: number) {
    return this.service.findAllByProjeto(projetoId);
  }

  @Post()
  create(@Param('projetoId', ParseIntPipe) projetoId: number, @Body() dto: CreateCircuitoDto) {
    return this.service.create(projetoId, dto);
  }
}

@Controller('circuitos')
export class CircuitosController {
  constructor(private readonly service: CircuitosService) {}

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOneOrFail(id);
  }

  @Patch(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateCircuitoDto) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }
}
