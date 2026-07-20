# 0011 — `cabos` como especificação técnica pura; fabricante/nome comercial isolados em `produto_comercial`

## Status
Aceito. Estende o ADR 0010 (que já havia adicionado `fabricante_id` a `cabos` — este ADR remove essa coluna de novo, junto com `tipo_cabo`, e move essa informação para uma tabela periférica).

## Contexto

O ADR 0010 deu a `cabos` um `fabricante_id` e manteve `tipo_cabo` (o nome
comercial) como parte da tabela — cada produto de cada fabricante virava
uma linha própria em `cabos`, e a "genericidade" vinha só de as tabelas de
fato (ampacidade, R/XL, curto-circuito) referenciarem dimensões
compartilhadas (`grupo_termico`, `grupo_construtivo`, `material_isolacao`)
em vez de `cabo_id` diretamente.

Revisitando o desenho: mesmo com essa mitigação, `cabos` continuava
identificado por `(fabricante_id, tipo_cabo)` — ou seja, o nome comercial
do fabricante continuava sendo a chave primária de fato de todo o
catálogo. Isso significa que **duas linhas geometricamente idênticas**
(GSette Easy da Prysmian e HEPR-PVC 0,6/1kV da Nexans — mesmo material de
isolação HEPR, mesma cobertura PVC, mesma tensão 0,6/1kV, mesma classe de
encordoamento) continuavam existindo como **duas linhas separadas** em
`cabos`, só relacionadas indiretamente por compartilharem `grupo_construtivo`.
Isso não é errado, mas também não é a forma mais direta de expressar "estes
dois produtos são, tecnicamente, o mesmo cabo" — e mantém `cabo_id` como
possível chave estrangeira em outras tabelas (como o override de
`resistencia_reatancia_ca` do ADR 0010), reintroduzindo acoplamento ao
nome comercial exatamente onde o ADR 0010 tentava evitá-lo.

## Decisão

`cabos` deixa de ter `fabricante_id` e `tipo_cabo`. Passa a ser
identificada inteiramente por atributos de construção:

```
cabos (
  id,
  norma_abnt,
  tensao_isolamento,
  material_isolacao_id     FK NOT NULL,
  material_cobertura_id    FK NOT NULL,  -- inclui a linha sentinela 'Nenhuma'
  classe_encordoamento_id  FK NOT NULL,  -- rígido (Classe 2) vs flexível (Classe 5)
  grupo_construtivo_id     FK NOT NULL,
  UNIQUE (material_isolacao_id, material_cobertura_id, tensao_isolamento, classe_encordoamento_id)
)
```

Dois pontos técnicos que motivaram colunas específicas nessa chave:

- **`material_cobertura_id` é `NOT NULL`, não nulável.** Um cabo sem
  cobertura (ex.: Superastic) ganha uma linha sentinela `'Nenhuma'` em
  `material_cobertura` em vez de `NULL`. Motivo: `NULL` nunca é igual a
  `NULL` numa constraint `UNIQUE` do Postgres — se a coluna fosse nulável,
  duas linhas de `cabos` com `material_cobertura_id IS NULL` não seriam
  detectadas como duplicatas pelo `UNIQUE`, silenciosamente quebrando a
  garantia de deduplicação que é o objetivo central deste ADR.
- **`classe_encordoamento_id` entrou na chave** porque, sem ela, Superastic
  (rígido) e Superastic Flex (flexível) — e da mesma forma Sintenax/Sintenax
  Flex — teriam exatamente o mesmo `(material_isolacao, material_cobertura,
  tensao_isolamento)` e colapsariam incorretamente na mesma linha, apesar
  de serem produtos genuinamente diferentes (rigidez do encordoamento afeta
  aplicação e manuseio, não é um detalhe cosmético).

`fabricante` continua existindo, mas passa a ser referenciada só por uma
nova tabela periférica:

```
produto_comercial (
  id,
  fabricante_id   FK NOT NULL,
  nome_comercial,
  cabo_id         FK NOT NULL REFERENCES cabos(id),
  UNIQUE (fabricante_id, nome_comercial)
)
```

`produto_comercial` existe só para rastreabilidade/orçamento — "Sintenax é
o nome que a Prysmian dá a este cabo genérico" — e **nenhuma tabela de
fato de cálculo (ampacidade, curto-circuito) a referencia**. A única
exceção é o mecanismo de override em `resistencia_reatancia_ca` (ADR
0010), que passou a apontar para `produto_comercial_id` em vez de
`cabo_id` — porque um valor de R/XL publicado por um fabricante específico
é, por definição, uma característica do produto comercial daquele
fabricante, não da especificação técnica genérica que outros fabricantes
podem compartilhar.

## Consequências

- `GSette Easy` (Prysmian) e `HEPR-PVC 0,6/1kV` (Nexans) passam a resolver
  para a **mesma linha física** em `cabos` — a propriedade que o ADR 0010
  buscava só indiretamente (via `grupo_construtivo` compartilhado) agora é
  direta e literal.
- `cabo_numero_condutores` (nº de condutores por variante) e qualquer join
  de ampacidade/queda de tensão feito a partir de um cabo passam a ser
  automaticamente compartilhados entre fabricantes equivalentes, sem
  nenhuma duplicação de dado — cadastrar o Nexans HEPR-PVC como
  `produto_comercial` apontando para a linha existente do GSette Easy não
  exigiu nenhuma nova linha em `cabo_numero_condutores`.
- Cadastrar um fabricante novo com um produto tecnicamente idêntico a um
  já existente vira **só uma linha em `produto_comercial`** — nenhuma
  tabela de fato precisa de dado novo.
- Cadastrar um fabricante com um produto tecnicamente novo (combinação
  inédita de material/cobertura/tensão/classe) exige uma linha nova em
  `cabos` (a especificação) mais uma em `produto_comercial` (quem vende) —
  dois passos em vez de um, aceito como custo direto de separar as duas
  responsabilidades.
- `resistencia_reatancia_ca.produto_comercial_id` (não mais `cabo_id`) é
  onde um override específico de fabricante deve ser registrado — reforça
  que overrides são uma característica do produto comercial, nunca da
  especificação técnica compartilhada.
