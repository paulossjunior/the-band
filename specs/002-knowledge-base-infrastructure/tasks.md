# Tarefas — Feature 002, infraestrutura da base de conhecimento YAML

**Branch**: `feature/002-knowledge-base-infrastructure`

**Data**: 2026-08-06

**Artefatos**: [spec.md](spec.md) · [plan.md](plan.md) · [research.md](research.md) ·
[ADR-0005](../../docs/adr/0005-biblioteca-yaml-e-portao-de-tokens.md) ·
[ADR-0006](../../docs/adr/0006-estrategia-de-carregamento-da-base-de-conhecimento.md)

**Cobertura**: 92 requisitos funcionais, 24 critérios de sucesso.

## Como ler

- `[P]` = pode rodar em paralelo com as tarefas vizinhas marcadas igual.
- **Tarefa de mutação** = quebra o código de propósito e confirma que o teste pega. Na feature 001
  isso encontrou dois testes que passavam pelo motivo errado. Não é opcional.
- Cada tarefa serve a **um requisito**, **ou** verifica outra tarefa, **ou** cumpre obrigação da
  constituição — e cita qual. Tarefa que não serve a nenhum dos três é escopo inventado. A primeira
  versão desta regra exigia requisito de **toda** tarefa, e o `analyze` mostrou que ela condenava nove
  tarefas legítimas: mutação, criação de módulo e convergência.
- **Nenhuma tarefa é marcada concluída sem evidência executada** — princípio V.

## Agrupamento em propostas de mudança

Uma proposta por grupo. Nunca misturar grupos.

| PR | Fases | Fecha | Depende de |
|---|---|---|---|
| A | 0, 1 | portão de tokens | — |
| B | 2 | manifesto e nove esquemas | A |
| C | 3 | validação estrita e `knowledge.validate` — **US1** | B |
| D | 4 | varredura de segredo e exceções | C |
| E | 5 | grafo e `knowledge.graph` — **US2** | C |
| F | 6, 7 | exemplos, compilação, arranque — **US4** | C, E |
| G | 8 | `knowledge.test` — **US5** | E, F |
| H | 9 | `knowledge.diff` — **US6** | C |
| I | 10, 11 | verificações obrigatórias — **US3** — e convergência | C, E, **F**, G |

---

## Fase 0 — Preparação

- [ ] **T001** Promover `yaml_elixir` a dependência declarada de runtime no `mix.exs`, e **substituir
  o aviso existente** — que diz que a presença transitiva não é a escolha — por referência à
  ADR-0005. Nenhuma outra dependência é acrescentada. [FR-048]
- [ ] **T002** Confirmar por execução que `mix deps.get` e `mix compile --warnings-as-errors` passam
  com a dependência promovida, e que `mix deps.tree` não trouxe nada além de `yamerl`. [FR-048]
- [ ] **T003** Criar `lib/the_band/knowledge/` e `test/the_band/knowledge/`. **Não** criar
  subdiretório algum de `priv/knowledge_base/` ainda — a constituição proíbe pasta vazia antecipada.
  Verificado por T122. [FR-001]
- [ ] **T004** Substituir o teste que garante a ausência de `priv/knowledge_base/` por um que garanta
  apenas a ausência de `lib/the_band/ontology/` e de módulos sob `TheBand.Ontology`. Confirmar que o
  novo teste **reprova** se um módulo ontológico for criado. [FR-050, SC-015]
- [ ] **T005** [P] Criar `test/support/knowledge_fixtures.ex` com auxiliares para escrever base
  temporária em diretório de teste, para que os casos de recusa nunca toquem `priv/`. [FR-043]

## Fase 1 — Portão de tokens (PR A)

Primeiro porque é a defesa contra o que R6 mediu: 814 bytes matam o processo.

- [ ] **T006** Escrever `TheBand.Knowledge.TokenGate` sobre `:yamerl_parser.string/2` com
  `{:token_fun, fun}`, devolvendo o fluxo de tokens **antes** de qualquer termo ser construído.
  [ADR-0005]
- [ ] **T007** Recusar âncora e apelido pelos tokens `:yamerl_anchor` e `:yamerl_alias`, com linha e
  coluna. [FR-011, FR-018]
- [ ] **T008** Teste que `t: "& e * dentro de texto"` **passa**, e que `a: &x 1` reprova. R10 mediu
  zero falso positivo por token; uma varredura textual travaria conteúdo legítimo, e este teste é o
  que impede alguém trocar tokens por expressão regular depois. [FR-011]
- [ ] **T009** Recusar chave duplicada no mesmo mapeamento, percorrendo `:yamerl_mapping_key` e os
  escalares seguintes, com linha e coluna de **todas** as ocorrências. Cobrir duplicata aninhada.
  [FR-010]
- [ ] **T010** Recusar tabulação na indentação. R7 mediu `"a:\n\tb: 1"` produzindo
  `%{"a" => nil, "b" => 1}` — `b` deveria estar dentro de `a`. [FR-072]
- [ ] **T011** Recusar mais de um documento por arquivo, arquivo vazio, arquivo só com comentário e
  arquivo só com o separador — cada um com mensagem própria. [FR-071]
- [ ] **T012** Tolerar marca de ordem de bytes e fim de linha estilo Windows; recusar byte que não é
  UTF-8 válido; recusar ligação simbólica que aponte para fora da base. [FR-072]
- [ ] **T013** Ignorar arquivo cujo nome começa por ponto, **relatando quantos** foram ignorados.
  Teste que a contagem aparece na saída — exclusão não contada é indistinguível de arquivo não
  encontrado. [FR-072, FR-013]
- [ ] **T014** Recusar arquivo maior que **256 KiB** ou cujo processamento exceda **2 segundos**.
  Valores derivados de R11: o arquivo realista tem 766 bytes e leva 0,27 ms. FR-018 cobre memória;
  arquivo que gira sem terminar bloqueia a verificação do mesmo jeito. [FR-092]
- [ ] **T015** Teste de integração com o **arquivo de bomba de 814 bytes de R6**: recusado pelo
  portão em milissegundos, sem construir termo. Medir o tempo e o tamanho do termo, e registrar.
  [FR-018, SC-002]
- [ ] **T016** Teste que reprova se o fluxo de tokens deixar de expor `:yamerl_anchor`,
  `:yamerl_alias` ou `:yamerl_mapping_key`. O portão depende de interface interna de `yamerl`, e
  **nunca** pode degradar para "não detectou nada" com código de saída zero. [plan.md, riscos]
- [ ] **T017** **Tarefa de mutação**: desligar cada uma das cinco recusas do portão, uma por vez, e
  confirmar que ao menos um teste reprova em cada caso. Cinco mutações, cinco reprovações.

## Fase 2 — Manifesto e nove esquemas (PR B)

- [ ] **T018** Criar `priv/knowledge_base/manifest.yaml` com nome, versão, idioma padrão, idiomas
  exigidos, versão padrão de esquema, ontologias presentes, política de validação e exigência de
  proveniência. [FR-002]
- [ ] **T019** Escrever `TheBand.Knowledge.Manifest`, e declarar **explicitamente** o que se aplica
  ao manifesto. Ele **não** declara identificador estável, dependências, proveniência própria,
  estado de maturidade nem rótulo bilíngue. FR-003 é "mesmo rigor", nunca "mesma lista de campos".
  [FR-003, FR-088]
- [ ] **T020** Recusar manifesto que declare validação não estrita ou que omita rejeição de campo
  desconhecido. Teste que o próprio manifesto é recusado, não que a validação é afrouxada. [FR-004]
- [ ] **T021** Verificar a correspondência manifesto↔conteúdo nos **dois** sentidos: ontologia
  declarada sem conteúdo reprova, conteúdo sobre ontologia não declarada reprova. **Exercitar por
  fixture, não pela base real**: entre o PR B e o PR F a base não tem ontologia de conteúdo alguma, e
  a verificação passaria **vazia** — a classe de defeito que esta feature existe para fechar, e que
  FR-016 proíbe para a contagem de arquivos. [FR-006]
- [ ] **T022** Implementar FR-086: "conteúdo sobre uma ontologia" é arquivo que declara aquela
  ontologia como **sua**. Mapeamento que apenas aponta **não** satisfaz a correspondência. Teste dos
  dois casos. [FR-086]
- [ ] **T023** Exigir versão de esquema igual ao padrão do manifesto; divergência reprova. Uma
  versão viva por esquema. [FR-055, FR-056, SC-017]
- [ ] **T024** Recusar versão de esquema que nenhum esquema implementa, nomeando a declarada e a
  existente. [FR-057]
- [ ] **T025** [P] Escrever os nove esquemas em `priv/knowledge_base/schemas/`, cada um com
  **obrigações próprias de conteúdo** além das cinco declarações comuns. Nove esquemas vazios não
  satisfazem FR-005. [FR-005, FR-075]
- [ ] **T026** Esquema de conceito: exigir classificação ontológica que distingue objeto, evento e
  agente, e permitir declarar o conceito mais geral especializado. Sem isso a validação aprovaria a
  fusão das distinções não negociáveis. [FR-076]
- [ ] **T027** Esquema de medida: exigir a necessidade de informação que a medida responde; medida
  sem o vínculo reprova. É o princípio IV da constituição. [FR-077]
- [ ] **T028** Esquema de mapeamento: exigir grau de equivalência, justificativa semântica,
  limitações, caminho do identificador externo e **chave natural**. Sem chave natural não há
  idempotência de escrita. [FR-078]
- [ ] **T029** Esquema de relação: exigir natureza temporal declarada. [FR-081]
- [ ] **T126** Esquema de conceito: exigir a lista de atributos, cada um com **nome, tipo e
  obrigatoriedade**. Conceito sem atributos reprova. Sem esta lista quem implementa inventa os campos e
  a conferência da feature 003 não tem o que conferir. [FR-093, ADR-0007]
- [ ] **T127** Vocabulário de tipo de atributo **fechado**, cada valor mapeando sem ambiguidade para um
  tipo de persistência. Recusar tipo genérico como "número": inteiro, decimal e ponto flutuante têm
  consequências diferentes em banco, e escolher entre eles é inventar requisito. [FR-094]
- [ ] **T128** Esquema de relação: cardinalidade **obrigatória**, na notação única de FR-079.
  Cardinalidade ausente reprova — é a diferença entre uma coluna e uma tabela de junção. [FR-095]
- [ ] **T129** Axioma e restrição declarados dentro do conceito ou da relação, com identificador estável
  e enunciado nos dois idiomas. **Nenhuma linguagem formal de expressão**, preservando Q3. [FR-096]
- [ ] **T130** Revisar cada um dos nove esquemas contra a pergunta: o que ele exige **basta para
  implementar a persistência sem consultar outra fonte?** Registrar a conferência esquema por esquema.
  [FR-097]
- [ ] **T131** Impor um conceito, uma relação ou uma pergunta de competência **por arquivo**. Recusar
  arquivo com mais de um. [FR-098]
- [ ] **T030** Notação única de cardinalidade em toda a base; duas notações para a mesma afirmação
  reprovam, ainda que ambas sejam legíveis. [FR-079]
- [ ] **T031** Restrição de conceito declarada **dentro** do conceito, nunca referenciada por
  identificador. Teste que o exemplo de conceito do documento de referência, adaptado, passa — hoje
  ele não passaria. [FR-083]
- [ ] **T032** Módulo de ontologia é nome de agrupamento, **não** referência a identificador.
  [FR-084]
- [ ] **T033** Vocabulário fechado de tipo de resposta esperada de pergunta de competência. [FR-085]
- [ ] **T034** Declarar, por esquema, **quais campos** são referência a identificador. Fora da lista,
  nada é interpretado como referência. [FR-082]
- [ ] **T035** Vocabulário fechado de tipo de fonte de proveniência, **com valor próprio para
  conteúdo de exemplo**. Declarar exemplo como derivado de ontologia de referência seria proveniência
  falsa — pior que ausente, porque passa. [FR-073, FR-074]
- [ ] **T036** Registrar no esquema, em comentário, que a proveniência **do conhecimento** é distinta
  da proveniência de **dado integrado** de sete campos do princípio III, que pertence às features de
  coleta. [FR-073]

## Fase 3 — Validação estrita e `knowledge.validate` (PR C, US1)

- [ ] **T123** Escrever `TheBand.Knowledge` como **API pública** do módulo, delegando aos submódulos.
  Nenhum código fora de `TheBand.Knowledge.*` alcança `Validator`, `Graph`, `Compiled` ou `Loader`
  direto. Teste que reprova acesso externo aos submódulos — é o padrão que `CLAUDE.md` exige e que as
  tarefas não cobriam. Achado C1 do `analyze`. [CLAUDE.md, API pública dos módulos]

- [ ] **T037** Escrever `TheBand.Knowledge.Loader` com `YamlElixir.read_all_from_string/2`, exigindo
  lista de tamanho exatamente 1. **Nunca** `read_from_string/2`: R8 mediu que ele devolve só o último
  documento e devolve `%{}` para arquivo vazio. [FR-071, ADR-0005]
- [ ] **T038** Teste que trava a escolha: uma asserção que reprova se `read_from_string/2` aparecer
  no código do módulo. Sem isso, alguém "simplifica" e reintroduz o descarte silencioso.
- [ ] **T124** Escrever `TheBand.Knowledge.Schema`, que carrega e representa os nove esquemas, e
  `TheBand.Knowledge.Validator`, que aplica um esquema a um arquivo. Nomeados no plano e sem tarefa até
  o `analyze` apontar. Achado C2. [FR-005, FR-075]
- [ ] **T039** Exigir as cinco declarações — esquema, versão, identificador estável, dependências,
  proveniência. Cinco casos de omissão, cinco recusas. [FR-007, SC-003]
- [ ] **T040** Tratar campo obrigatório com valor vazio ou nulo como **violação**, não como ausência,
  e distinguir as duas na mensagem. Erros diferentes de quem escreve; confundi-los faz procurar no
  lugar errado. [FR-007]
- [ ] **T041** Recusar campo desconhecido em **qualquer** nível de aninhamento, não só na raiz.
  [FR-008]
- [ ] **T042** Recusar documento cuja raiz não é mapeamento. [FR-071]
- [ ] **T121** Recusar arquivo que não é documento YAML válido, **indicando a posição**, e **nunca**
  tratar erro de sintaxe como arquivo vazio. R9 mediu `%YamlElixir.ParsingError{line: 2, column: 5,
  type: :unfinished_flow_collection}` — linha, coluna e razão tipada. Registrar em teste a limitação
  medida: para byte que não é UTF-8 válido, os dois campos vêm `:undefined`, e a mensagem nomeia
  arquivo e razão sem posição. [FR-009, ADR-0005]
- [ ] **T043** Tratar versão e identificador como texto, e recusar arquivo em que a coerção mudaria o
  significado. Teste com `version: 1.10`, que R3 mediu virando `1.1` — mesma coisa que `1.1`.
  [FR-012]
- [ ] **T044** Impor a gramática do identificador: minúsculas, dígitos, sublinhado, ponto como
  separador, cada segmento começando por letra. Recusar maiúscula, hífen, espaço, barra, acento e
  segmento iniciado por dígito. [FR-051, SC-016]
- [ ] **T045** Derivar a propriedade do identificador do **campo de ontologia declarado**, nunca do
  texto. Onde o arquivo declara ontologia, o primeiro segmento tem de coincidir. Mapeamento,
  necessidade de informação e medida não têm obrigação de prefixo. [FR-052, FR-053, FR-054]
- [ ] **T046** Exigir os dois idiomas em todo rótulo e definição, **derivando a exigência do
  registro do manifesto** em vez de fixá-la no código. Recusar idioma ausente do registro. [FR-058,
  FR-059, FR-061, SC-018]
- [ ] **T047** Exigir estado de maturidade entre proposto, ativo e obsoleto; recusar ausência e
  qualquer outro valor. [FR-066]
- [ ] **T048** Exigir de arquivo obsoleto a versão de descontinuação, a razão e o substituto — ou a
  afirmação explícita de que nada o substitui. [FR-068]
- [ ] **T049** Relatar **todas** as violações de uma execução, não apenas a primeira. Teste com
  arquivo que viola cinco regras: cinco violações no relatório. [FR-015]
- [ ] **T050** Relatar quantos arquivos foram verificados, e **reprovar quando for zero**. Aprovação
  sem ter verificado nada é proibida. [FR-016, SC-001]
- [ ] **T051** **Confirmar que os nove esquemas carregaram antes de aprovar.** Contar arquivos não
  fecha este caminho: esquema que falha ao carregar faz os arquivos daquele tipo serem pulados
  enquanto a contagem segue maior que zero. [FR-089]
- [ ] **T052** Prova de T051: impedir o carregamento de **um esquema por vez** e confirmar que a
  validação reprova. Nove casos, nove reprovações. É a verificação que a feature 001 não tinha.
  [SC-021]
- [ ] **T053** Recusar arquivo dentro da base cujo local ou tipo não é reconhecido. A única exclusão
  admitida é a de FR-072, e ela é contada e relatada. [FR-013]
- [ ] **T054** Considerar as duas extensões usuais de YAML, ou recusar a excluída. Extensão
  silenciosamente ignorada é proibida. [FR-014]
- [ ] **T055** Escrever `TheBand.Knowledge.Report` com saída **determinística e ordenada**. [FR-091]
- [ ] **T056** Escrever `mix knowledge.validate`, com código de falha ao reprovar e de sucesso apenas
  quando verificou a base e não achou violação. [FR-017]
- [ ] **T057** Verificar por busca exaustiva que **nenhuma** variável de ambiente, argumento, arquivo
  de configuração ou campo de manifesto desliga, afrouxa ou reduz o alcance de qualquer verificação.
  [FR-090, SC-024]
- [ ] **T058** Registrar a mensagem de erro produzida por cada classe de recusa e confirmar, **lendo
  as mensagens**, que uma pessoa localiza e corrige sem abrir o código da validação. Verificação por
  leitura da saída, não por inspeção de quem a gera. [SC-013]
- [ ] **T059** Tabela de rastreabilidade ligando **cada linha** de Edge Cases ao caso que a exercita,
  na matriz de evidência. O que não for coberto é declarado não coberto. Total agregado não satisfaz.
  [SC-002]
- [ ] **T060** **Tarefa de mutação**: enfraquecer cada uma das cinco exigências obrigatórias, uma por
  vez, e confirmar reprovação. Cinco mutações, cinco reprovações.

## Fase 4 — Segredo e exceções (PR D)

- [ ] **T061** Escrever `TheBand.Knowledge.SecretScan` recusando valor com forma de token, senha,
  chave privada, credencial ou cadeia de conexão — **inclusive em comentário**. [FR-024]
- [ ] **T062** Mensagem de recusa identifica arquivo e posição e **não reproduz o valor suspeito**.
  Reproduzi-lo o copiaria para o registro de execução, que neste repositório é público. Teste que a
  mensagem não contém o valor. [FR-025]
- [ ] **T063** Exceção declarada **no próprio arquivo**, nomeando o campo exato, com justificativa
  obrigatória. Exceção sem justificativa reprova. [FR-062]
- [ ] **T064** Escopo da exceção é um campo de um arquivo. Recusar exceção por arquivo inteiro, por
  diretório, por padrão textual e global. O que se aplica em massa é interruptor com outro nome.
  [FR-063]
- [ ] **T065** Recusar exceção que aponte para campo inexistente. Exceção órfã continua autorizando o
  que já não precisa de autorização. [FR-064]
- [ ] **T066** Relatar o total de exceções da base em cada execução. Exceção que ninguém conta deixa
  de ser exceção. [FR-065, SC-020]
- [ ] **T067** Medir a taxa de falso positivo do detector sobre o conteúdo real da base, e declarar o
  conjunto de formatos detectados. [SC-007]
- [ ] **T068** **Nunca versionar credencial falsa para provar o detector.** Os casos ficam em
  `test/fixtures/`, gerados em tempo de teste. Confirmar por varredura que nada com forma de
  credencial entrou no histórico desta branch. [SC-007]

## Fase 5 — Grafo e `knowledge.graph` (PR E, US2)

- [ ] **T069** Escrever `TheBand.Knowledge.Graph`. `:digraph` do OTP é opção de implementação; nenhuma
  dependência nova.
- [ ] **T070** Recusar identificador declarado por mais de um arquivo, nomeando o identificador e
  **todos** os arquivos envolvidos. [FR-019, SC-004]
- [ ] **T071** Recusar referência a identificador inexistente, nomeando quem referencia e o que foi
  referenciado. Escopo limitado aos campos declarados em T034. [FR-020, FR-082, SC-004]
- [ ] **T072** Detectar ciclo entre ontologias, exibir o **ciclo completo** e reprovar. [FR-021,
  SC-006]
- [ ] **T073** Recusar dependência em direção proibida pela constituição **e aceitar** as permitidas.
  Ambos os conjuntos exercitados: recusar tudo não passa. [FR-022, SC-005]
- [ ] **T074** Recusar uso de identificador de ontologia que o arquivo não declarou como dependência,
  operando sobre o campo de ontologia. [FR-023, FR-052]
- [ ] **T075** Verificar reciprocidade: relação declarada dentro de um conceito concorda com origem e
  destino no arquivo da relação. Divergência reprova — sem isso os dois arquivos afirmam coisas
  diferentes e os dois passam. [FR-080]
- [ ] **T076** Recusar referência a arquivo obsoleto, **exceto** quando quem referencia também é
  obsoleto. Sem a ressalva, descontinuar um arquivo puniria retroativamente quem seguiu o caminho de
  descontinuação. [FR-069, FR-087]
- [ ] **T077** Escrever `mix knowledge.graph` com contrato de saída e contagem de quanto trabalho
  fez. [FR-016, FR-017, FR-091]
- [ ] **T078** **Tarefa de mutação**: inverter a tabela de direções permitidas e confirmar que os
  testes das direções permitidas reprovam. Um recusador indiscriminado tem de falhar aqui.

## Fase 6 — Conjunto reservado de exemplos (PR F)

- [ ] **T079** Criar `priv/knowledge_base/examples/` exercitando **os nove esquemas** pelo caminho de
  aceitação, com espaço de identificadores reservado, reconhecível como exemplo sem contexto.
  [FR-041, FR-042]
- [ ] **T080** O conjunto exercita os **três** estados de maturidade e os **dois** idiomas
  obrigatórios. [FR-041]
- [ ] **T081** Casos de recusa em `test/fixtures/knowledge_base/`, **fora** de `priv/`. Arquivo
  inválido dentro da base faria a verificação obrigatória reprovar para sempre. [FR-043]
- [ ] **T082** Acrescentar `example` às ontologias presentes do manifesto, fechando a correspondência
  dos dois sentidos de T021. [FR-006]
- [ ] **T122** Confirmar por teste que `priv/knowledge_base/` contém **apenas** subdiretórios com
  conteúdo. Nenhum diretório de ontologia, mapeamento, regra ou fonte é criado vazio. O teste reprova
  se um diretório vazio aparecer — a constituição proíbe, e a proibição sem verificação é convenção.
  [FR-001]

## Fase 7 — Compilação, `:persistent_term`, arranque (PR F, US4)

- [ ] **T083** Escrever `TheBand.Knowledge.Compiled` carregando na inicialização para
  `:persistent_term`. [FR-026, ADR-0006]
- [ ] **T084** Consulta em execução **nunca** toca o disco. Medir leituras na décima e na milésima
  consulta e confirmar número idêntico. [FR-027, SC-010]
- [ ] **T085** Consulta distingue "identificador não existe" de "existe e está vazio". [FR-029]
- [ ] **T086** Compilação reprova com qualquer arquivo inválido e **não** produz representação
  parcial. [FR-028]
- [ ] **T087** Apenas arquivo **ativo** entra na base compilada. Proposto e obsoleto são validados com
  o mesmo rigor e não chegam ao runtime. Registrar em teste que isto **não** é a representação
  parcial que FR-028 proíbe. Os **três** estados exercitados de ponta a ponta, junto com T047, T048,
  T076 e T104. [FR-067, SC-019]
- [ ] **T088** Conteúdo de exemplo ausente da base compilada, verificado por teste. Exclusão não
  verificada é suposição. [FR-044]
- [ ] **T089** **YAML inválido impede o arranque**, com mensagem que nomeia o arquivo. Teste de
  integração: aplicação não sobe, e não sobe com base parcial. [FR-028, ADR-0006]
- [ ] **T090** Caminho de recarga em desenvolvimento reflete mudança de YAML sem reiniciar o
  servidor. É o custo que FR-030 exige declarar. [FR-030]
- [ ] **T091** Escrever `mix knowledge.compile` com contrato de saída e contagem. [FR-017, FR-091]
- [ ] **T092** Medir o tempo de arranque com a base real e registrar. R11 mediu 1,36 s para cinco mil
  arquivos; a base real tem cerca de quinze. [ADR-0006]

## Fase 8 — `knowledge.test` (PR G, US5)

- [ ] **T093** Recusar pergunta de competência que cite conceito ou relação inexistente, nomeando a
  pergunta e o conceito. [FR-031]
- [ ] **T094** Recusar pergunta que cite conceito de ontologia que ela não declara. [FR-032]
- [ ] **T095** Relatar o resultado de **cada** pergunta individualmente. Total esconde qual pergunta
  deixou de se sustentar. [FR-033]
- [ ] **T096** Reprovar quando não houver pergunta a verificar. [FR-034]
- [ ] **T097** O relatório declara **no próprio texto** que a conferência foi estrutural e que
  nenhuma pergunta foi respondida com dados. Sem isso o nome da tarefa promete mais do que ela
  garante. [FR-035]
- [ ] **T098** Escrever `mix knowledge.test` com contrato de saída e contagem. [FR-017, FR-091]

## Fase 9 — `knowledge.diff` (PR H, US6)

- [ ] **T125** Escrever `TheBand.Knowledge.Diff`. Nomeado no plano e sem tarefa até o `analyze`
  apontar. Achado C2. [FR-036]
- [ ] **T099** Reconstruir a base em **duas referências do histórico** e comparar. Sem artefato
  gerado e versionado que descreva o estado semântico. [FR-040]
- [ ] **T100** Relatar adição, remoção, renomeação e alteração de conteúdo. [FR-036]
- [ ] **T101** Classificar cada mudança como compatível ou incompatível; remoção ou renomeação de
  identificador é **incompatível**. [FR-037, SC-011]
- [ ] **T102** **Não** relatar mudança quando a diferença é apenas formatação, ordem de chaves ou
  comentário. [FR-038, SC-011]
- [ ] **T103** Sinalizar mudança incompatível cuja versão declarada não foi elevada de forma
  condizente. [FR-039]
- [ ] **T104** Sinalizar remoção de arquivo que não passou pelo estado obsoleto. O caminho de
  descontinuação existe para avisar antes de quebrar. [FR-070]
- [ ] **T105** Classificar como **incompatível** a remoção de um idioma do conjunto exigido. Sem
  isso, o registro do manifesto seria interruptor. [FR-060]
- [ ] **T106** Escrever `mix knowledge.diff` com contrato de saída e contagem. [FR-017, FR-091]

## Fase 10 — Verificações obrigatórias no servidor (PR I, US3)

- [ ] **T107** Acrescentar `knowledge.validate`, `knowledge.graph` e `knowledge.test` ao `mix gates`,
  **depois** dos cinco existentes, e ao fluxo de verificação automática. [FR-045]
- [ ] **T108** As três executam em **toda** proposta de mudança, independentemente de ela tocar
  arquivo de conhecimento. Condicioná-las ao conteúdo criaria o caminho para desativá-las. [FR-047]
- [ ] **T109** Registrar as três como verificações obrigatórias de status no servidor, somando às
  cinco existentes — oito no total. [FR-045]
- [ ] **T110** Provar por **tentativa real de incorporação** que a incorporação é bloqueada com
  verificação reprovada, ausente e pendente. Leitura de configuração não é evidência. [FR-046,
  SC-009]
- [ ] **T111** Contrato de código de saída verificado nos **dois** caminhos para as cinco tarefas, e
  cada uma relata quanto trabalho fez. **Dez medições, não duas.** Nenhuma das cinco sai com código
  de sucesso quando não conseguiu fazer o que se propõe — é a classe de defeito da feature 001.
  [FR-016, FR-017, SC-008, SC-022]
- [ ] **T112** Duas execuções de cada tarefa sobre a mesma base produzem saída **idêntica byte a
  byte**. Sem isso a matriz de evidência registra ruído como mudança. [FR-091, SC-023]
- [ ] **T113** Medir a execução completa dos oito portões em ambiente sem cache e confirmar que
  continua dentro de dez minutos. Se não couber, mudar a ordem — **nunca** reduzir o que é
  verificado. [SC-012]

## Fase 11 — Convergência (PR I)

- [ ] **T114** Escrever `evidence.md` com matriz **requisito por requisito**, 92 FR e 24 SC, cada
  linha apontando evidência executada. O que não foi provado é declarado não provado, com o que
  falta. [princípio V, `Mantenedor único`]
- [ ] **T115** Registrar em `evidence.md` o que a execução mudou no plano, e **como cada achado
  apareceu** — teste, execução, auto-revisão, mutação ou revisão independente.
- [ ] **T116** Registrar os alarmes falsos próprios com a causa de cada um. A causa se reaproveita;
  na feature 001 foram quatro, nenhum defeito de código.
- [ ] **T117** Rodar `/speckit-analyze` e resolver todo achado. `CRITICAL` ou `HIGH` bloqueia a
  incorporação. [`Mantenedor único`]
- [ ] **T118** Atualizar `CLAUDE.md`, `README.md` e `docs/architecture/overview.md`: a base de
  conhecimento passa de **ausente** a existente, e as verificações passam de três para oito.
- [ ] **T119** Revisão independente por outro agente, com resultado anexado ao PR e registrada como
  **não equivalente** a revisão humana.
- [ ] **T120** Confirmar por varredura que nenhuma credencial entrou no histórico desta branch, e que
  nenhum YAML da base contém segredo. [SC-007]

---

## Rastreabilidade: requisitos sem tarefa

**Nenhum — verificado mecanicamente, não afirmado.** Os 92 requisitos funcionais e os 24 critérios de
sucesso são citados por ao menos uma tarefa.

A primeira versão desta decomposição **afirmou** cobertura total e a verificação por comparação de
conjuntos encontrou quatro descobertos: FR-009 e FR-001 sem tarefa alguma, e SC-008 e SC-019 cobertos
por tarefas existentes mas sem citação — rastreabilidade quebrada, que é indistinguível de lacuna para
quem audita. Corrigido por T121, T122 e citação em T087, T111 e T003.

FR-009 era o achado sério: recusar YAML inválido com posição, e nunca tratar erro de sintaxe como
arquivo vazio, é requisito central da validação e não tinha tarefa.

T121 e T122 recebem números novos em vez de renumerar as 120 anteriores, pela mesma razão que a
feature 039 não renumerou a 025: numeração é referência, e renumerar quebra tudo que já aponta. Estão
posicionados nas fases a que pertencem.

Quatro requisitos são fechados por artefato já entregue, e não por tarefa de código:

| Requisito | Fechado por |
|---|---|
| FR-030 | ADR-0006, mais T090 para o custo declarado |
| FR-048 | ADR-0005, mais T001 |
| FR-049 | `research.md`, R1 a R11 |
| SC-014 | ADR-0005 e ADR-0006 |

## Riscos de execução, herdados do plano

| Risco | Tarefa que o cobre |
|---|---|
| `:yamerl_parser` é interface interna | T016 |
| Ferramenta que aprova sem ter feito o trabalho | T051, T052, T111 |
| Âncoras proibidas custam reuso | T008 impede a troca por expressão regular |
| Sem linha e coluna para byte inválido | T012 registra a limitação |
| Orçamento de dez minutos com oito verificações | T113 |
