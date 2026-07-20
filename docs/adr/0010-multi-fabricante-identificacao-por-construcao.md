# 0010 — Catálogo multi-fabricante: identidade pelo material de isolação/cobertura, não pelo nome comercial

## Status
Aceito. Revisa/estende os ADRs 0002, 0004 e 0008.

## Contexto

Os ADRs anteriores (0002, 0004, 0008) já assumiam implicitamente um único
fabricante (Prysmian) como fonte de todo o catálogo `cabos`. O repositório
passou a ter catálogos de referência de outros fabricantes
(`docs_refs/Nexans_*.pdf`, `docs_refs/ALUBAR_COPPERTEC_CATALOGO_DE_CABOS.pdf`,
`docs_refs/INDUSCABOS_Catalogo-Cabos-de-Baixa-Tensao.pdf`), o que expôs três
problemas de acoplamento ao nome comercial Prysmian:

1. `cabos` não tinha nenhuma noção de fabricante — nada distinguiria um
   "Sintenax" (Prysmian) de um produto equivalente de outro fabricante além
   do nome, e `tipo_cabo` era `UNIQUE` globalmente.
2. `cabos.material_isolacao` e `cabos.material_cobertura` eram texto livre,
   não uma dimensão normalizada — quebrando o próprio princípio do ADR 0001.
3. `fator_k_curto_circuito` referenciava `cabo_id` diretamente (ADR 0002
   já registrava isso como uma exceção deliberada). Ao verificar o catálogo
   Nexans HEPR-PVC 0,6/1kV, confirmou-se que a tabela de ampacidade
   reproduzida por ele é **idêntica** à da NBR 5410 para a mesma classe de
   isolação (termofixo 90°C), independentemente do fabricante — ou seja,
   `cabo_id` nunca deveria ter sido a chave: o que importa é o material de
   isolação. Manter `cabo_id` ali quebraria assim que um segundo fabricante
   fosse cadastrado (cada produto exigiria sua própria linha de k, duplicando
   uma tabela que é normativa, não proprietária).
4. `cabos_metodo_instalacao` (a junção cabo × método, ADR 0004) guardava
   como dado o que já era 100% derivável de `categoria_cabo`. Conferido
   linha a linha contra os dados originais: os 15 pares do Superastic
   batiam exatamente com os 15 métodos aplicáveis a "Condutor Isolado" em
   `metodo_instalacao_referencia`, e o mesmo padrão se confirmou para as
   demais famílias de produto. Manter essa tabela como dado hard-coded por
   `cabo_id` significava recadastrar manualmente os mesmos pares para cada
   novo fabricante, apesar de a resposta já estar implícita na categoria de
   construção do cabo (que é genérica).

Nem todo fabricante publica os mesmos dados: o catálogo Nexans, por
exemplo, publica ampacidade (idêntica à norma) mas **não publica**
resistência/reatância (R/XL) — dado que só o guia Prysmian tabela
diretamente. O schema precisa de um mecanismo de "valor base com override
opcional", não de exigir o dado completo de todo fabricante.

## Decisão

1. **`fabricante`** (id, nome) — nova tabela. `cabos.fabricante_id` NOT
   NULL. `cabos.tipo_cabo` deixa de ser `UNIQUE` global e passa a
   `UNIQUE(fabricante_id, tipo_cabo)` — nomes comerciais só precisam ser
   únicos dentro do catálogo do próprio fabricante.

2. **`material_isolacao`** (id, nome, `grupo_termico_id`, `temp_curto_circuito_c`)
   e **`material_cobertura`** (id, nome) substituem as colunas de texto
   livre em `cabos`. `cabos.material_isolacao_id` é `NOT NULL`;
   `cabos.material_cobertura_id` é nulável (nem todo cabo tem cobertura).
   `material_isolacao.grupo_termico_id` aponta para o bucket de ampacidade
   compartilhado (PVC e LSHF-A dividem o mesmo grupo térmico 70°C, mas são
   materiais distintos) — `cabos.grupo_termico_id` foi removido por ser
   derivável via `material_isolacao_id → grupo_termico_id` (fonte única).

3. **`fator_k_curto_circuito`** passa a referenciar `material_isolacao_id`
   (+ `material_condutor_id` + `secao_max_mm2`) em vez de `cabo_id`. É uma
   tabela normativa (NBR 5410 Tabela 30) — o mesmo valor vale para qualquer
   fabricante que use o mesmo material de isolação, então a chave correta
   sempre foi o material, nunca o produto comercial.

4. **`cabos_metodo_instalacao` foi removida.** Quais métodos de instalação
   um cabo suporta é derivado via
   `cabos → cabo_numero_condutores → categoria_cabo_id → metodo_instalacao_referencia`,
   sem nenhuma tabela própria por cabo — a consulta de exemplo está
   documentada como comentário em `database/insert_data.sql` no lugar onde
   a tabela existia.

5. **`resistencia_reatancia_ca` ganha `cabo_id` NULÁVEL** (override
   opcional) mantendo `grupo_construtivo_id` como a chave "valor base":
   - Regime **base** (`cabo_id IS NULL`): 1 linha por
     `(grupo_construtivo_id, material_condutor_id, secao_nominal_id,
     numero_condutores_carregados, arranjo_espacamento_id)` — tipicamente
     alimentado pelo guia Prysmian, usado como fallback por qualquer
     fabricante cujo produto caia nesse `grupo_construtivo`.
   - Regime **override** (`cabo_id IS NOT NULL`): 1 linha por
     `(cabo_id, secao_nominal_id, numero_condutores_carregados,
     arranjo_espacamento_id)` — só usada quando um fabricante específico
     publica seu próprio R/XL que deve prevalecer sobre o valor base.
   - Dois índices únicos parciais (`uq_resistencia_reatancia_ca_base` /
     `uq_resistencia_reatancia_ca_override`) impõem essas duas regras de
     unicidade simultaneamente na mesma tabela.
   - Resolução esperada do consumidor: buscar linha com `cabo_id` do
     produto; se não existir, cair para a linha `cabo_id IS NULL` do mesmo
     `grupo_construtivo_id`. Exemplo carregado: o Nexans HEPR-PVC 0,6/1kV
     (que não publica R/XL) cai no `grupo_construtivo` "GSette Easy /
     Afumex Flex" e resolve para o valor base de lá, sem linha própria.

6. `capacidade_conducao_corrente` **não muda** — ampacidade é
   inteiramente normativa (confirmado comparando o guia Prysmian ao
   catálogo Nexans: valores idênticos para o mesmo grupo térmico), então
   `grupo_termico_id` já era a chave certa e nunca precisou de fabricante
   nem de override.

## Consequências

- Cadastrar um produto de um fabricante novo (ex.: Alubar Coppertec, uma
  vez que seu catálogo for transcrito) exige só: uma linha em `cabos`
  apontando fabricante/material_isolacao/material_cobertura/grupo_construtivo
  corretos — nenhuma tabela de fato (ampacidade, R/XL, curto-circuito)
  precisa de linha nova a menos que o fabricante publique valor próprio
  que deva prevalecer sobre o base.
- `fator_k_curto_circuito` e `capacidade_conducao_corrente` nunca duplicam
  dado por fabricante — são tabelas normativas, chaveadas por material,
  não por produto.
- `resistencia_reatancia_ca` é a única tabela de fato com mecanismo de
  override por cabo, porque é a única que é genuinamente dado de catálogo
  (não normativo) e a única com fabricantes que não publicam o dado.
- `cabos_metodo_instalacao` deixou de existir — uma tabela a menos para
  manter, sem perda de informação; a consulta derivada é ligeiramente mais
  verbosa (2 JOINs a mais) em troca de nunca ficar desatualizada em
  relação a `metodo_instalacao_referencia`.

## Atualização (ver [0011](0011-cabos-especificacao-generica-produto-comercial.md))

`cabos` foi além do que este ADR propôs: `fabricante_id` e `tipo_cabo`
saíram completamente da tabela (que passou a ser identificada só por
material de isolação/cobertura/tensão/classe de encordoamento), e o
vínculo com fabricante/nome comercial migrou para uma tabela periférica
nova, `produto_comercial`. O mecanismo de override "valor base vs.
específico" em `resistencia_reatancia_ca` continua existindo como descrito
aqui, só que agora aponta para `produto_comercial_id` em vez de `cabo_id`.
