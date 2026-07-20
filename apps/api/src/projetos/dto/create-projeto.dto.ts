import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateProjetoDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  nome: string;

  @IsOptional()
  @IsString()
  descricao?: string;
}
