import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DEFAULT_USUARIO_ID } from '../config/constants';
import { Projeto } from '../entities/projeto.entity';
import { CreateProjetoDto } from './dto/create-projeto.dto';

@Injectable()
export class ProjetosService {
  constructor(@InjectRepository(Projeto) private readonly repo: Repository<Projeto>) {}

  findAll() {
    return this.repo.find({ where: { usuarioId: DEFAULT_USUARIO_ID }, order: { createdAt: 'DESC' } });
  }

  async findOneOrFail(id: number): Promise<Projeto> {
    const projeto = await this.repo.findOneBy({ id, usuarioId: DEFAULT_USUARIO_ID });
    if (!projeto) throw new NotFoundException(`Projeto ${id} não encontrado`);
    return projeto;
  }

  async create(dto: CreateProjetoDto): Promise<Projeto> {
    const existente = await this.repo.findOneBy({ usuarioId: DEFAULT_USUARIO_ID, nome: dto.nome });
    if (existente) throw new ConflictException(`Já existe um projeto com o nome "${dto.nome}"`);
    const projeto = this.repo.create({
      usuarioId: DEFAULT_USUARIO_ID,
      nome: dto.nome,
      descricao: dto.descricao ?? null,
      createdAt: new Date(),
    });
    return this.repo.save(projeto);
  }
}
