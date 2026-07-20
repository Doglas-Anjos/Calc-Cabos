import { FileInterceptor } from '@nestjs/platform-express';
import {
  BadRequestException,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { ImportacaoService } from './importacao.service';

@Controller()
export class ImportacaoController {
  constructor(private readonly service: ImportacaoService) {}

  @Post('projetos/:projetoId/circuitos/importar')
  @UseInterceptors(FileInterceptor('arquivo'))
  async importar(
    @Param('projetoId', ParseIntPipe) projetoId: number,
    @UploadedFile() arquivo?: Express.Multer.File,
  ) {
    if (!arquivo) throw new BadRequestException('Envie o arquivo Excel no campo "arquivo"');
    const job = await this.service.iniciarImportacao(projetoId, arquivo.originalname, arquivo.buffer);
    return { importJobId: job.id };
  }

  @Get('import-jobs/:id')
  status(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOneOrFail(id);
  }
}
