# Semantic Requirements Quality Checklist: Infraestrutura da base de conhecimento YAML

**Purpose**: Testar se os requisitos semânticos e ontológicos estão completos, claros,
consistentes e mensuráveis — antes de existir código. Não testa comportamento; testa a
qualidade do que está escrito.

**Created**: 2026-08-05

**Feature**: [spec.md](../spec.md)

**Profundidade**: portão formal. Sob a cláusula `Mantenedor único` as aprovações humanas são
zero, então este checklist não é lembrete de revisão — é a revisão.

**Nota sobre a ordem**: `check-prerequisites.sh` exige `plan.md` para rodar. A constituição
ordena `checklist` **antes** do `plan`, e prevalece. Este checklist foi avaliado contra
`spec.md` apenas, que é o que o portão pretende gatear.

## Proveniência

- [x] CHK001 Os campos que compõem uma declaração de proveniência de arquivo de conhecimento
  estão especificados? [Gap, Spec §FR-007]
- [x] CHK002 A distinção entre proveniência de **arquivo de conhecimento** e proveniência de
  **dado integrado** — que a constituição define no princípio III com sete campos — está
  explícita, para que ninguém aplique a lista errada? [Gap]
- [x] CHK003 O vocabulário de tipo de fonte é fechado ou aberto? Se aberto, a validação não pode
  verificar nada além da presença da chave. [Ambiguity, Spec §FR-007]
- [x] CHK004 A proveniência do próprio conteúdo de exemplo — que é inventado e não deriva de
  fonte alguma — está definida? [Gap, Spec §FR-042]
- [x] CHK005 A exigência de proveniência é imposta a todo arquivo, sem exceção por tipo?
  [Completeness, Spec §FR-007]

## Obrigações de conteúdo dos nove esquemas

- [x] CHK006 O conteúdo mínimo que **cada** um dos nove esquemas exige está especificado, ou
  "existe um esquema para cada tipo" é satisfazível por um esquema vazio? [Gap, Spec §FR-005]
- [x] CHK007 A exigência de classificação ontológica em um conceito — o que distingue objeto,
  evento e agente — está declarada? Sem ela, um esquema de conceito válido permite fundir as
  distinções não negociáveis da constituição. [Gap, Spec §FR-005]
- [x] CHK008 A exigência de que uma medida declare a necessidade de informação que ela responde
  está escrita? O princípio IV da constituição proíbe medida sem necessidade de informação
  declarada. [Gap, Conflict com constituição §IV]
- [x] CHK009 As obrigações de um mapeamento quanto a equivalência parcial, justificativa e
  limitações estão declaradas? O princípio II proíbe transformação sem mapeamento semântico
  explícito. [Gap, Spec §FR-005]
- [x] CHK010 A obrigação de identidade de um mapeamento — caminho do identificador externo e
  chave natural — está declarada? Sem chave natural não há idempotência de escrita, e o
  princípio VII a exige. [Gap, Spec §FR-005]
- [x] CHK011 Um arquivo de glossário, cuja natureza é um termo e sua definição, tem obrigação de
  declarar dependências que faça sentido, ou a exigência de FR-007 produz campo cerimonial?
  [Ambiguity, Spec §FR-007]

## Referências que não têm tipo de arquivo

- [x] CHK012 Uma restrição referenciada por identificador dentro de um conceito tem tipo de
  arquivo entre os nove? Se não tem, é referência pendente sob FR-020, e o exemplo do documento
  de referência não passaria pela própria validação. [Conflict, Spec §FR-020 vs §FR-005]
- [x] CHK013 Os módulos que uma ontologia declara são identificadores sujeitos a FR-020, ou
  nomes livres? [Ambiguity, Spec §FR-020]
- [x] CHK014 O vocabulário de tipo de resposta esperada de uma pergunta de competência está
  especificado, ou é texto livre? [Ambiguity, Spec §FR-005]
- [x] CHK015 A regra que decide **quais** campos de um arquivo são tratados como referência a
  identificador está especificada? Sem ela, FR-020 não tem escopo definido. [Gap, Spec §FR-020]

## Consistência entre conceito e relação

- [x] CHK016 Existe uma notação única de cardinalidade, ou duas? O documento de referência usa
  uma forma dentro do conceito e outra dentro da relação para dizer a mesma coisa.
  [Inconsistency, Spec §FR-005]
- [x] CHK017 A reciprocidade é exigida — uma relação declarada dentro de um conceito precisa
  concordar com origem e destino declarados no arquivo da relação? Sem isso, os dois podem
  afirmar coisas diferentes e ambos passam. [Gap, Spec §FR-005]
- [x] CHK018 A obrigação de declarar a natureza temporal de uma relação está definida? A
  constituição distingue evento de objeto e processo planejado de executado. [Gap, Spec §FR-005]

## Rede de ontologias

- [x] CHK019 As direções permitidas e proibidas de dependência entre ontologias estão declaradas
  de forma verificável, e ambos os conjuntos são exercitados? [Completeness, Spec §FR-022,
  §SC-005]
- [x] CHK020 A exigência de que dependência usada seja dependência declarada está escrita?
  [Completeness, Spec §FR-023]
- [x] CHK021 O que conta como "conteúdo sobre uma ontologia" para a verificação de
  correspondência com o manifesto está definido? Um mapeamento que aponta para uma ontologia
  conta, ou só arquivos que declaram aquela ontologia como sua? [Ambiguity, Spec §FR-006]
- [x] CHK022 A propriedade de um identificador é determinada por um mecanismo único e explícito,
  em vez de inferida do texto? [Clarity, Spec §FR-052]
- [x] CHK023 A proibição de duplicar conceito entre ontologias — princípio II — tem requisito que
  a imponha, ou depende de revisão humana? [Coverage, Spec §FR-019]

## Reuso e não duplicação

- [ ] CHK024 A regra que a constituição enuncia — conceito que já existe em ontologia mais geral
  é reutilizado, não duplicado — tem requisito verificável, ou só identificador duplicado literal
  é detectado? Dois conceitos com identificadores diferentes e a mesma definição passam.
  [Gap, Spec §FR-019]
- [x] CHK025 A especialização de um conceito é declarável por referência ao conceito mais geral?
  [Completeness, Spec §FR-005]

## Estado, descontinuação e compatibilidade

- [x] CHK026 Os três estados de maturidade e o efeito de cada um sobre a base compilada estão
  especificados sem ambiguidade? [Clarity, Spec §FR-066, §FR-067]
- [x] CHK027 A definição de mudança incompatível é objetiva o bastante para ser classificada por
  máquina? [Measurability, Spec §FR-037]
- [x] CHK028 O caso de um arquivo obsoleto cujas dependências apontam para outro arquivo obsoleto
  está tratado? FR-069 proíbe referenciar obsoleto, e um obsoleto que dependia de outro passaria a
  reprovar retroativamente. [Coverage, Gap, Spec §FR-069]

## Notas

**Primeira passagem, 2026-08-05: 8 de 28 passaram.** Vinte achados reais — nenhuma pendência
administrativa. Cada um era um lugar onde o requisito escrito não sustentava o que a constituição
exige, ou onde o exemplo do documento de referência não passaria pela própria validação.

**Segunda passagem: 27 de 28.** A especificação passou de 72 para 92 requisitos funcionais e de 20
para 24 critérios de sucesso, por causa destes achados.

### Os três mais graves, e o que cada um custou

**CHK008 — medida sem necessidade de informação.** O princípio IV da constituição proíbe medida sem
necessidade de informação declarada. A especificação criava os dois tipos de arquivo e deixava a
ligação entre eles ao critério de quem escreve. Era violação constitucional, não imprecisão.
→ FR-077.

**CHK012 — restrição referenciada por identificador.** O exemplo de conceito do documento de
referência declara `constraints: [- id: sro.user_story.must_describe_requirement]`, e nenhum dos
nove tipos de arquivo pode conter essa restrição. Sob FR-020 ela seria referência pendente: **o
próprio exemplo da fonte não passaria pela validação que esta feature constrói.** Resolvido
declarando restrição inline, e não por identificador. → FR-083.

**CHK006 — nove esquemas vazios.** FR-005 exigia "um esquema para cada tipo" sem dizer o que cada
esquema exige. Era satisfazível por nove arquivos vazios, e a feature entregaria a maquinaria sem o
que ela deve impor. → FR-075 a FR-081.

### O que segue aberto

**CHK024 — duplicação semântica não é mecanizável.** Dois conceitos com identificadores diferentes
e a mesma definição passam por FR-019 e por FR-076. Fechar exigiria comparar significado, não
texto. Permanece sob revisão semântica humana, **registrado como limitação aceita** em Assumptions
da especificação em vez de tratado como coberto.
