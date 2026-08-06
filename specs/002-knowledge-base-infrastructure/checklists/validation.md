# Validation Requirements Quality Checklist: Infraestrutura da base de conhecimento YAML

**Purpose**: Testar se os requisitos sobre validação estrita, aceitação silenciosa e contrato de
saída das cinco tarefas estão completos, claros, consistentes e mensuráveis. Não testa
comportamento; testa a qualidade do que está escrito.

**Created**: 2026-08-05

**Feature**: [spec.md](../spec.md)

**Por que este checklist existe**: a classe de defeito número um da feature 001 foi uma ferramenta
que **saiu com código 0 sem ter feito o trabalho** — a análise estática não carregava as checagens
próprias e aprovava. Esta feature entrega cinco ferramentas novas de verificação. Todo item abaixo
pergunta se o requisito escrito fecha esse caminho.

## Aceitação silenciosa

- [x] CHK001 Existe requisito que proíbe aprovação sem ter verificado nada? [Completeness,
  Spec §FR-016]
- [x] CHK002 Existe requisito que proíbe arquivo dentro da base ser silenciosamente ignorado?
  [Completeness, Spec §FR-013]
- [x] CHK003 A única exclusão admitida é declarada como contada e relatada, em vez de silenciosa?
  [Consistency, Spec §FR-013, §FR-072]
- [x] CHK004 Existe requisito que exija verificar que **todos os nove esquemas foram carregados**
  antes de a validação poder aprovar? Se um esquema falhar ao carregar, os arquivos daquele tipo
  podem ser pulados e a contagem de FR-016 continua maior que zero. É exatamente a falha da
  feature 001, transposta. [Gap, Spec §FR-016]
- [x] CHK005 Existe requisito que proíba desligar qualquer verificação por variável de ambiente,
  argumento de linha de comando ou arquivo de configuração? FR-004 fecha só o manifesto.
  [Gap, Spec §FR-004]
- [x] CHK006 A rejeição de campo desconhecido é exigida em qualquer nível de aninhamento, e não
  apenas na raiz? [Completeness, Spec §FR-008]
- [x] CHK007 A ordem entre expansão de apelidos e verificação de campo desconhecido está decidida,
  em vez de deixada ao acaso da biblioteca? [Clarity, Spec §FR-011]

## Contrato de saída das cinco tarefas

- [x] CHK008 O contrato de código de saída está especificado para **as cinco** tarefas, ou apenas
  para a validação? FR-017 fala só da validação; três das cinco são verificações obrigatórias de
  status, e um código de saída não especificado é um portão não especificado. [Gap, Spec §FR-017]
- [x] CHK009 Existe requisito de que cada tarefa relate **quanto trabalho fez** — não só se
  passou? A contagem existe para a validação (FR-016); a verificação de grafo, a de perguntas de
  competência e a comparação não têm equivalente. [Gap, Spec §FR-016]
- [x] CHK010 A saída das tarefas é exigida determinística e ordenada, para que a evidência de duas
  execuções seja comparável? Sem isso, a matriz de evidência registra ruído. [Gap]
- [x] CHK011 Existe requisito de que a compilação reprove em vez de produzir resultado parcial?
  [Completeness, Spec §FR-028]
- [x] CHK012 A distinção entre "resultado parcial proibido" e "exclusão deliberada por estado"
  está escrita, em vez de deixada para a leitura resolver? [Consistency, Spec §FR-067]

## Mensurabilidade dos critérios

- [x] CHK013 O critério sobre leitura de disco é objetivamente mensurável, ou depende de
  "um número de consultas grande o bastante"? [Measurability, Spec §SC-010]
- [x] CHK014 O número de arquivos que a base suporta dentro do orçamento de tempo está declarado
  como aberto e atribuído a uma fase, em vez de simplesmente ausente? [Clarity, Spec §SC-012]
- [x] CHK015 O critério sobre mensagem de erro é verificável por quem lê a mensagem, e não por
  inspeção do código que a gera? [Measurability, Spec §SC-013]
- [x] CHK016 A exigência de exercitar as direções de dependência nos **dois** sentidos está
  escrita, impedindo que um recusador indiscriminado passe? [Measurability, Spec §SC-005]
- [x] CHK017 A cobertura exigida pelo critério sobre formas de invalidez é rastreável caso a caso,
  ou "para cada forma listada em Edge Cases" depende de a lista estar completa? [Traceability,
  Spec §SC-002]

## Manifesto submetido às próprias regras

- [x] CHK018 Quais das cinco declarações obrigatórias se aplicam ao manifesto está especificado?
  FR-003 diz "as mesmas exigências", e exigir do manifesto identificador estável, dependências
  declaradas e estado de maturidade produz campos sem sentido — um manifesto proposto ou obsoleto
  é contradição. [Conflict, Spec §FR-003 vs §FR-007, §FR-066]
- [x] CHK019 A exigência bilíngue se aplica ao manifesto, que não tem rótulo nem definição?
  [Ambiguity, Spec §FR-003 vs §FR-058]
- [x] CHK020 A política de validação do manifesto é declarada incondicional, e valor divergente
  recusa o próprio manifesto? [Clarity, Spec §FR-004]

## Mensagem de erro como requisito

- [x] CHK021 A exigência de relatar todas as violações de uma execução, e não apenas a primeira,
  está escrita? [Completeness, Spec §FR-015]
- [x] CHK022 A exigência de distinguir "campo não declarado" de "campo declarado sem valor" está
  escrita? [Clarity, Spec §FR-007]
- [x] CHK023 A proibição de reproduzir valor suspeito de segredo na mensagem está escrita, com a
  razão registrada? [Completeness, Spec §FR-025]
- [x] CHK024 A mensagem de erro tem exigência de apontar **linha e coluna**, ou apenas "posição"?
  "Posição" não é verificável sem definição. [Ambiguity, Spec §FR-009, §SC-013]

## Terminologia

- [x] CHK025 O termo usado para acesso à base em execução é consistente? FR-027 diz "a cada
  requisição", e esta feature não expõe superfície web alguma — o termo correto é consulta.
  [Inconsistency, Spec §FR-027 vs §SC-010]
- [x] CHK026 A palavra "schema" é desambiguada entre esquema de validação, versão de esquema e
  esquema de persistência? [Clarity, Spec §Terminologia canônica]

## Resistência

- [x] CHK027 A resistência a arquivo cuja expansão consuma memória de forma descontrolada é
  exigida, com a razão de o repositório ser público e aceitar propostas de mudança? [Coverage,
  Spec §FR-018]
- [x] CHK028 Existe requisito de limite de tempo ou de tamanho por arquivo, ou apenas de memória?
  Um arquivo que faz a validação girar sem terminar bloqueia a verificação obrigatória do mesmo
  jeito que um que esgota memória. [Gap, Spec §FR-018]

## Notas

**Primeira passagem, 2026-08-05: 15 de 28 passaram.** Treze achados reais.

**Segunda passagem: 28 de 28.**

### Os três mais graves, e o que cada um custou

**CHK004 — a falha da feature 001, transposta.** A especificação exigia contar arquivos verificados
(FR-016) e **não** exigia confirmar que os nove esquemas carregaram. Um esquema que falha ao
carregar faz os arquivos daquele tipo serem pulados; a contagem permanece maior que zero; a
validação aprova. É exatamente a forma do defeito da 001 — `mix credo` sem compilar, checagem que
não carrega, `Ignoring an undefined check`, código de saída 0 — num lugar novo, e passou pela
`specify` **e** pela `clarify` sem ser vista. → FR-089, e SC-021 exige provar impedindo o
carregamento de um esquema por vez: nove casos, nove reprovações.

**CHK008 — portão sem contrato de saída não é portão.** FR-016 e FR-017 falavam só da validação.
Três das cinco tarefas serão verificações obrigatórias de status no servidor. → os dois requisitos
passaram a valer para as cinco, e SC-022 exige dez medições, não duas.

**CHK018 — contradição que eu mesmo introduzi.** FR-003 submete o manifesto "às mesmas exigências",
e FR-066 passou a exigir estado de maturidade de todo arquivo. Um manifesto "proposto" ou
"obsoleto" é contradição, e um manifesto com rótulo bilíngue é campo cerimonial. → FR-088 declara
explicitamente o que se aplica ao manifesto, e relê FR-003 como "mesmo **rigor**", nunca "mesma
**lista de campos**".

### Achados menores que ainda mudariam a implementação

- **CHK005** — nada proibia um interruptor por variável de ambiente. FR-004 fechava só o manifesto.
  → FR-090.
- **CHK010** — saída não determinística faria a matriz de evidência registrar ruído como mudança.
  → FR-091, SC-023 exige saída idêntica byte a byte.
- **CHK028** — FR-018 cobria memória e não tempo. Arquivo que faz a validação girar sem terminar
  bloqueia a verificação obrigatória do mesmo jeito. → FR-092.
- **CHK013** — SC-010 dizia "grande o bastante para que a diferença seja inequívoca". Não é
  mensurável. → substituído por décima versus milésima consulta, dois números.
- **CHK025** — FR-027 dizia "a cada requisição" numa feature sem superfície web alguma. → consulta.
