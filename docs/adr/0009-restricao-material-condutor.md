# 0009 — Restrição de uso de condutor de alumínio é regra normativa, não coincidência de tabela

## Status
Aceito.

## Contexto

O usuário destacou que a escolha do material do condutor (cobre vs.
alumínio) é uma decisão importante do dimensionamento, não um campo solto.
A NBR 5410 restringe onde alumínio pode ser usado:

- §6.2.3.7 — proibido em instalações residenciais e em locais de classe
  BD4 (alta densidade de ocupação e percurso de fuga longo), em qualquer
  seção.
- §6.2.3.8.1 — permitido em instalações industriais somente com seção
  ≥16 mm², alimentação por subestação/transformador próprio ou fonte
  própria, e instalação/manutenção por pessoal qualificado.
- §6.2.3.8.2 — permitido em instalações comerciais somente com seção
  ≥50 mm², em locais exclusivamente BD1 (baixa densidade de ocupação,
  percurso de fuga breve, altura <28 m), e instalação/manutenção por
  pessoal qualificado.

Sem modelar essa regra, nada impede que uma consulta de dimensionamento
"ofereça" alumínio como opção de material em um contexto onde a norma
proíbe.

## Decisão

Nova tabela `restricao_material_condutor`:

```
restricao_material_condutor (
  id,
  material_condutor_id FK,
  contexto CHECK IN ('industrial','comercial','residencial','bd4'),
  secao_minima_mm2 NUMERIC NULL,   -- NULL quando permitido=FALSE (não há seção que resolva)
  permitido BOOLEAN,
  condicao_desc TEXT NULL,         -- texto livre com a condição adicional (alimentação, pessoal qualificado etc.)
  UNIQUE(material_condutor_id, contexto)
)
```

Populada com as 4 linhas correspondentes às cláusulas acima para o
Alumínio (residencial e BD4 com `permitido=FALSE`; industrial e comercial
com `permitido=TRUE` e a seção mínima/condição descrita). Cobre não
recebe linha — ausência de restrição é o padrão, não precisa ser
declarada explicitamente linha a linha.

## Consequências

- Qualquer fluxo de dimensionamento pode consultar esta tabela antes de
  aceitar alumínio como material candidato, dado o contexto da instalação
  (residencial/comercial/industrial/BD4) — a regra fica no banco, não
  espalhada em código de aplicação.
- `condicao_desc` é texto livre (não modelado estruturalmente) porque as
  condições adicionais (alimentação própria, pessoal qualificado) são
  qualitativas e não entram em nenhum cálculo — normalizá-las estruturalmente
  seria sobre-projetar em cima de um requisito que não existe hoje.
