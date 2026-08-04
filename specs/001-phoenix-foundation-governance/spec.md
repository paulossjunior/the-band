# Feature Specification: Fundação e governança da plataforma

**Feature Branch**: `feature/001-phoenix-foundation-governance`

**Created**: 2026-08-03

**Status**: Draft

**Input**: User description: "Fundação Phoenix e governança do The Band. Criar a fundação mínima e verificável do monólito modular multitenant, sem implementar nenhuma ontologia, nenhum YAML de domínio e nenhum conector externo."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Subir a plataforma localmente e confirmar que está saudável (Priority: P1)

Uma pessoa do time de desenvolvimento clona o repositório em uma máquina limpa, segue
as instruções do README, sobe o ambiente local e obtém confirmação de que a plataforma
está funcionando e conectada ao seu armazenamento de dados.

**Why this priority**: Sem ambiente reproduzível não há como verificar nada. Todas as
demais features dependem deste ponto de partida. É o único item que, entregue
isoladamente, já produz valor: um ambiente de trabalho compartilhado e idêntico entre
pessoas do time.

**Independent Test**: Em máquina sem estado prévio do projeto, executar os passos
documentados e consultar o endereço de verificação de saúde. Entrega valor mesmo sem
nenhuma das outras histórias.

**Acceptance Scenarios**:

1. **Given** máquina com os pré-requisitos documentados instalados e repositório
   recém-clonado, **When** a pessoa executa os passos de inicialização do README,
   **Then** a plataforma responde no endereço de verificação de saúde indicando estado
   saudável.
2. **Given** plataforma em execução, **When** a verificação de saúde é consultada,
   **Then** a resposta informa a conectividade com o armazenamento de dados e com o
   mecanismo de trabalho assíncrono.
3. **Given** armazenamento de dados indisponível, **When** a verificação de saúde é
   consultada, **Then** a resposta indica estado não saudável e identifica o componente
   com falha, sem expor credenciais, host interno ou detalhe sensível.
4. **Given** repositório recém-clonado, **When** a pessoa procura instruções de
   configuração, **Then** encontra um arquivo de exemplo de variáveis de ambiente sem
   nenhum valor real de credencial.
5. **Given** ambiente local inicializado, **When** a estrutura de dados inicial é
   aplicada e em seguida revertida, **Then** ambas as operações concluem sem erro e o
   armazenamento volta ao estado anterior.

---

### User Story 2 - Garantir isolamento entre organizações desde o primeiro dado (Priority: P1)

A plataforma atende múltiplas organizações na mesma instalação. Quem opera precisa da
garantia de que dado de uma organização nunca é visível, contável ou alterável a partir
do contexto de outra organização — e essa garantia precisa existir antes de qualquer
dado real entrar no sistema.

**Why this priority**: Isolamento retroencaixado é a fonte clássica de vazamento entre
clientes. Adicioná-lo depois exigiria revisar todo acesso a dados já escrito. Precisa
ser a primeira restrição estrutural, não a última.

**Independent Test**: Cadastrar duas organizações, criar dados em cada uma, e provar por
teste automatizado que uma consulta feita no contexto da organização A nunca retorna,
conta ou altera dado da organização B.

**Acceptance Scenarios**:

1. **Given** duas organizações cadastradas com dados próprios, **When** uma consulta é
   feita no contexto da organização A, **Then** nenhum registro da organização B é
   retornado.
2. **Given** duas organizações cadastradas, **When** uma tentativa de alteração aponta
   para registro de outra organização, **Then** a operação é rejeitada e nenhum dado é
   modificado.
3. **Given** um acesso a dados de fundação, **When** o contexto de organização está
   ausente, **Then** a operação é rejeitada com erro explícito em vez de retornar dados
   de todas as organizações.
4. **Given** o código-fonte da fundação, **When** o time verifica os pontos de acesso ao
   armazenamento, **Then** todos passam pela abstração única de escopo de organização,
   verificável automaticamente.
5. **Given** identificador de organização inexistente, **When** usado como contexto,
   **Then** a operação é rejeitada sem criar organização implicitamente.

---

### User Story 3 - Executar trabalho assíncrono confiável e rastreável (Priority: P2)

A plataforma precisa executar coleta, transformação e cálculo em segundo plano. Quem
opera precisa que cada unidade de trabalho declare a qual organização pertence, seja
reexecutável sem efeito colateral duplicado, e deixe rastro suficiente para diagnóstico.

**Why this priority**: Toda integração futura depende deste mecanismo. Sem a validação
de contexto de organização e sem rastro correlacionável, os conectores nascem inseguros
e indepuráveis. Vem depois de US1 e US2 porque depende de ambiente e de isolamento.

**Independent Test**: Enfileirar uma unidade de trabalho de verificação com contexto de
organização válido e observar sua conclusão bem-sucedida; enfileirar a mesma unidade sem
contexto de organização e observar rejeição registrada.

**Acceptance Scenarios**:

1. **Given** mecanismo de trabalho assíncrono em execução, **When** uma unidade de
   verificação é enfileirada com contexto de organização válido, **Then** ela conclui com
   sucesso e o resultado fica consultável.
2. **Given** mecanismo em execução, **When** uma unidade é enfileirada sem contexto de
   organização, **Then** ela é rejeitada com erro explícito e não é reexecutada
   indefinidamente.
3. **Given** unidade de trabalho que falha por causa transitória, **When** o mecanismo
   reprocessa, **Then** novas tentativas ocorrem com espera crescente e limite máximo
   definido.
4. **Given** a mesma unidade de trabalho executada duas vezes com a mesma entrada,
   **Then** o estado resultante é idêntico ao de uma única execução.
5. **Given** unidade concluída ou falha, **When** o registro operacional é inspecionado,
   **Then** contêm organização, identificador de correlação, identificador da unidade,
   número da tentativa, duração e situação final.

---

### User Story 4 - Impedir que mudança não verificada entre na linha principal (Priority: P2)

Quem mantém o repositório precisa da garantia de que nenhuma mudança chega à linha
principal sem passar por verificação automática de formatação, compilação sem alerta,
análise estática, análise de tipos e testes — e sem revisão de outra pessoa.

**Why this priority**: É o mecanismo que converte os princípios do projeto em obrigação
executável em vez de recomendação. Sem ele, os princípios são texto.

**Independent Test**: Abrir uma proposta de mudança contendo uma violação deliberada de
cada verificação e observar a reprovação automática; corrigir e observar a aprovação.

**Acceptance Scenarios**:

1. **Given** proposta de mudança com código fora do padrão de formatação, **When** a
   verificação automática executa, **Then** ela reprova e indica o arquivo em desacordo.
2. **Given** proposta de mudança que produz alerta de compilação, **When** a verificação
   executa, **Then** ela reprova.
3. **Given** proposta de mudança com violação de análise estática ou de tipos,
   **When** a verificação executa, **Then** ela reprova.
4. **Given** proposta de mudança com teste falhando, **When** a verificação executa,
   **Then** ela reprova e o resultado do teste fica visível.
5. **Given** proposta de mudança que introduz credencial ou dependência com
   vulnerabilidade conhecida, **When** a verificação de segurança executa, **Then** ela
   reprova e identifica o achado.
6. **Given** proposta de mudança aprovada em todas as verificações, **When** ninguém
   revisou, **Then** a incorporação na linha principal é impedida.
7. **Given** todas as verificações executando, **When** o tempo total é medido, **Then**
   fica dentro do limite definido em Success Criteria.

---

### User Story 5 - Recuperar por que a fundação foi decidida assim (Priority: P3)

Uma pessoa que entra no projeto meses depois precisa entender, sem perguntar a ninguém,
por que a plataforma é um sistema único modular em vez de vários serviços, e por que o
isolamento entre organizações foi feito daquela forma — incluindo as alternativas
descartadas.

**Why this priority**: Evita retrabalho e reversão acidental de decisão estrutural.
Valor real, mas não bloqueia execução das features seguintes.

**Independent Test**: Pedir a alguém de fora do projeto para localizar e resumir as duas
decisões estruturais e suas alternativas descartadas usando apenas o repositório.

**Acceptance Scenarios**:

1. **Given** repositório, **When** a pessoa procura decisões estruturais, **Then**
   encontra registro datado da decisão de sistema único modular, com contexto,
   alternativas consideradas e consequências.
2. **Given** repositório, **When** a pessoa procura a decisão de isolamento entre
   organizações, **Then** encontra registro equivalente, incluindo a rejeição explícita
   de base de dados separada por organização.
3. **Given** pessoa abrindo a primeira proposta de mudança, **When** consulta o
   repositório, **Then** encontra modelo de proposta e modelos de solicitação que
   exigem evidência, escopo, fora de escopo e critérios de aceitação.
4. **Given** repositório, **When** a pessoa procura os termos de uso do código,
   **Then** encontra a licença aplicável de forma inequívoca.

---

### Edge Cases

- Armazenamento de dados fica indisponível depois da inicialização: a verificação de
  saúde passa a indicar estado não saudável em vez de a plataforma encerrar.
- Contexto de organização presente mas apontando para organização inexistente ou
  desativada: operação rejeitada, sem criação implícita.
- Duas unidades de trabalho concorrentes sobre o mesmo alvo: resultado equivalente a
  execução serial, sem registro duplicado.
- Unidade de trabalho falha permanentemente: para de ser tentada ao atingir o limite,
  permanecendo consultável para diagnóstico.
- Estrutura de dados inicial aplicada duas vezes: segunda aplicação não tem efeito e não
  falha o processo de inicialização.
- Variável de ambiente obrigatória ausente na inicialização: falha imediata com mensagem
  nomeando a variável, em vez de partir com valor padrão inseguro.
- Registro operacional recebendo valor sensível: o valor é omitido ou mascarado.
- Verificação automática executada sem acesso ao armazenamento de dados: reprova de
  forma explícita, sem marcar teste como aprovado por ausência.

## Requirements *(mandatory)*

### Functional Requirements

**Ambiente e verificação de saúde**

- **FR-001**: O sistema MUST expor um endereço de verificação de saúde que responda
  sucesso quando a plataforma estiver operacional.
- **FR-002**: A verificação de saúde MUST reportar separadamente a conectividade com o
  armazenamento de dados e com o mecanismo de trabalho assíncrono.
- **FR-003**: A verificação de saúde MUST NOT expor credencial, endereço interno, versão
  de dependência ou detalhe de configuração sensível.
- **FR-004**: O sistema MUST poder ser inicializado localmente por comandos documentados,
  a partir de repositório recém-clonado, sem passo manual não documentado.
- **FR-005**: O repositório MUST conter arquivo de exemplo de variáveis de ambiente
  contendo todas as variáveis obrigatórias e nenhum valor real.
- **FR-006**: O sistema MUST falhar a inicialização com mensagem nomeando a variável
  ausente quando uma variável obrigatória não estiver definida.
- **FR-007**: A estrutura de dados inicial MUST poder ser aplicada e revertida sem erro.

**Isolamento entre organizações**

- **FR-008**: O sistema MUST registrar organizações atendidas como entidade própria, com
  identificador estável e situação de ativação.
- **FR-009**: Toda entidade de dados da fundação MUST estar associada a exatamente uma
  organização.
- **FR-010**: Todo acesso a dados da fundação MUST ocorrer através de uma abstração
  única e explícita de escopo de organização.
- **FR-011**: O sistema MUST rejeitar acesso a dados quando o contexto de organização
  estiver ausente, em vez de operar sobre todas as organizações.
- **FR-012**: O sistema MUST rejeitar leitura, alteração e remoção de registro
  pertencente a organização diferente da do contexto ativo.
- **FR-013**: O sistema MUST rejeitar contexto que aponte para organização inexistente ou
  desativada, sem criá-la implicitamente.

**Trabalho assíncrono**

- **FR-014**: O sistema MUST executar unidades de trabalho em segundo plano, de forma
  persistente e observável.
- **FR-015**: Toda unidade de trabalho MUST declarar a organização à qual pertence.
- **FR-016**: O sistema MUST rejeitar unidade de trabalho sem organização declarada ou
  com organização inválida, registrando o motivo.
- **FR-017**: O sistema MUST reprocessar falha transitória com espera crescente e limite
  máximo de tentativas.
- **FR-018**: Reexecutar a mesma unidade de trabalho com a mesma entrada MUST produzir o
  mesmo estado final que uma única execução.
- **FR-019**: O sistema MUST manter consultável a situação, tentativa e motivo de falha
  de cada unidade de trabalho.

**Observabilidade**

- **FR-020**: O sistema MUST emitir registro operacional estruturado contendo, quando
  aplicável: organização, identificador de correlação, identificador da unidade de
  trabalho, número da tentativa, duração, situação e código de erro.
- **FR-021**: O sistema MUST propagar um identificador de correlação por requisição e por
  unidade de trabalho, permitindo reconstituir a cadeia de execução.
- **FR-022**: O sistema MUST NOT registrar credencial, token nem conteúdo sensível
  completo de payload.

**Verificação automática e governança**

- **FR-023**: O repositório MUST executar verificação automática, a cada proposta de
  mudança, de: padrão de formatação, compilação sem alerta, análise estática, análise de
  tipos e testes.
- **FR-024**: A verificação automática MUST reprovar a proposta quando qualquer uma
  dessas checagens falhar.
- **FR-025**: A verificação automática MUST incluir checagem de segurança que reprove
  credencial versionada e dependência com vulnerabilidade conhecida.
- **FR-026**: A verificação automática MUST executar contra armazenamento de dados real
  provisionado pelo próprio processo de verificação.
- **FR-027**: A incorporação na linha principal MUST exigir aprovação de pessoa diferente
  de quem propôs a mudança.
- **FR-028**: A linha principal MUST ser protegida contra escrita direta, reescrita de
  histórico e remoção.
- **FR-029**: O repositório MUST conter modelo de proposta de mudança exigindo escopo,
  fora de escopo, testes, resultado das verificações e evidências.
- **FR-030**: O repositório MUST conter modelos de solicitação para pedido de
  funcionalidade, relato de defeito, tarefa técnica e tarefa de pesquisa.
- **FR-031**: O repositório MUST declarar responsáveis por revisão das áreas do código.
- **FR-032**: O repositório MUST declarar a licença aplicável ao código.

**Registro de decisões**

- **FR-033**: O repositório MUST registrar a decisão de adotar sistema único modular
  multiorganização, com contexto, alternativas consideradas, consequências e data.
- **FR-034**: O repositório MUST registrar a decisão de estratégia de isolamento entre
  organizações, incluindo a rejeição explícita de base de dados separada por organização.
- **FR-035**: Os registros de decisão MUST usar formato e numeração consistentes,
  permitindo referência estável.

### Key Entities

- **Organização atendida (tenant)**: unidade de isolamento da plataforma. Representa a
  organização cliente cujos dados são coletados e analisados. Atributos essenciais:
  identificador estável, nome, identificador legível, situação de ativação, momento de
  criação. Toda entidade de dados da fundação referencia exatamente uma organização
  atendida.

  **Nota semântica**: esta entidade é a fronteira de isolamento da instalação. Não é o
  conceito `Organization` da ontologia EO, que representa a organização como objeto
  social do domínio analisado e será introduzido pela feature 005. Uma organização
  atendida pode conter várias organizações de domínio. Os dois conceitos não devem ser
  fundidos.

- **Unidade de trabalho assíncrono**: intenção de executar processamento em segundo
  plano, pertencente a uma organização atendida. Atributos essenciais: tipo, argumentos,
  organização, situação, número da tentativa, momento de agendamento, momento de
  conclusão, motivo de falha.

  **Nota semântica**: é registro operacional de execução da plataforma, não uma
  `Performed Activity` da ontologia SPO. Não confundir com atividade de processo de
  software do domínio analisado.

- **Registro de decisão estrutural**: documento datado e numerado que registra uma
  decisão de arquitetura, seu contexto, as alternativas consideradas, a decisão tomada e
  suas consequências.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em máquina limpa com os pré-requisitos instalados, uma pessoa do time sobe
  a plataforma e obtém resposta saudável na verificação de saúde em **até 15 minutos**,
  seguindo somente o README, sem consultar outra pessoa.
- **SC-002**: **100%** dos pontos de acesso a dados da fundação passam pela abstração de
  escopo de organização, verificado por checagem automática que reprova a proposta de
  mudança em caso de desvio.
- **SC-003**: **Zero** vazamento entre organizações: em cenário com duas organizações e
  dados em ambas, nenhuma operação executada no contexto de uma retorna, conta ou altera
  dado da outra.
- **SC-004**: **100%** das unidades de trabalho sem organização declarada são rejeitadas.
- **SC-005**: Reexecutar a mesma unidade de trabalho com a mesma entrada produz estado
  final idêntico em **100%** das repetições de um lote de pelo menos 10 execuções.
- **SC-006**: Uma proposta de mudança contendo violação deliberada de qualquer uma das
  cinco verificações é reprovada automaticamente em **100%** dos casos.
- **SC-007**: Nenhuma mudança alcança a linha principal sem aprovação de outra pessoa,
  verificado tentando incorporar sem revisão.
- **SC-008**: O conjunto completo de verificações automáticas conclui em **até 10
  minutos** desde a abertura da proposta de mudança.
- **SC-009**: **Zero** credencial, token, chave ou arquivo de ambiente real versionado,
  verificado por checagem automática de segurança em todo o histórico da mudança.
- **SC-010**: Uma pessoa externa ao projeto localiza e resume as duas decisões
  estruturais e suas alternativas descartadas em **até 10 minutos**, usando somente o
  repositório.
- **SC-011**: Aplicar e reverter a estrutura de dados inicial conclui sem erro em
  **100%** das execuções, em base vazia e em base já inicializada.
- **SC-012**: **100%** dos registros operacionais de falha permitem identificar
  organização, identificador de correlação e unidade de trabalho envolvidos.

## Assumptions

- **Público**: os únicos usuários desta feature são pessoas do time de desenvolvimento e
  de operação. Não há usuário final da plataforma nesta feature; autenticação de usuário
  final está fora de escopo e será tratada em feature própria.
- **Interface**: a interface visual entregue aqui se limita à verificação de saúde. Não
  há tela de gestão, listagem ou navegação.
- **Contexto de organização**: nesta feature o contexto de organização é fornecido
  programaticamente ou por configuração, já que não há autenticação. A derivação do
  contexto a partir de sessão autenticada é feature futura.
- **Cadastro de organizações**: criação de organização atendida ocorre por semeadura de
  dados ou tarefa administrativa, não por interface visual.
- **Verificação de saúde**: assume-se distinção entre "processo vivo" e "pronto para
  atender", ambas cobertas pelo mesmo endereço com detalhamento por componente.
- **Ambiente local**: assume-se conteinerização apenas do armazenamento de dados; a
  plataforma executa no hospedeiro durante o desenvolvimento.
- **Escopo ontológico**: nenhuma ontologia, nenhum conceito de domínio, nenhum arquivo da
  base de conhecimento declarativa e nenhum mapeamento semântico faz parte desta feature.
  A entidade de organização atendida é infraestrutura de isolamento, não conceito de
  domínio.
- **Escopo de integração**: nenhum conector externo, nenhuma consulta a fornecedor e
  nenhuma medida ou indicador faz parte desta feature.
- **Entrega**: publicação em ambiente produtivo, orquestração de contêineres e
  observabilidade externa estão fora de escopo; apenas o esqueleto de registro
  operacional é entregue.
- **Versões de base**: assume-se o uso das versões de linguagem, plataforma de execução e
  armazenamento já instaladas e verificadas no ambiente de bootstrap; a confirmação de
  compatibilidade entre elas e as bibliotecas obrigatórias é atividade do plano.
- **Numeração de branch**: na fase de especificação ainda não existe solicitação
  registrada, então a branch usa o número da feature no lugar do número da solicitação.
  As branches de implementação usarão o número da solicitação, conforme a constituição.

## Dependencies

- Ambiente de bootstrap já concluído: ferramenta de especificação inicializada,
  constituição ratificada, repositório publicado, linguagem, plataforma de execução e
  armazenamento de dados verificados localmente.
- Acesso administrativo ao repositório remoto para configurar proteção da linha principal
  e responsáveis por revisão.
- Nenhuma dependência de sistema externo, fornecedor ou credencial de terceiro.

## Clarifications Needed

Duas decisões não têm padrão razoável e afetam critérios de aceitação desta feature.

### Q1: Proteção da linha principal em repositório privado

**Context**: FR-027, FR-028, SC-007. A constituição proíbe escrita direta na linha
principal, proíbe incorporação sem revisão e proíbe aprovar a própria mudança.

**What we need to know**: O repositório foi criado privado. No plano atual da conta, a
plataforma de hospedagem recusa configurar proteção de linha principal e conjuntos de
regras em repositório privado — a tentativa retorna erro exigindo plano pago ou
repositório público. Como satisfazer FR-027 e FR-028?

**Suggested Answers**:

| Option | Answer | Implications |
|--------|--------|--------------|
| A | Tornar o repositório público | Proteção e conjuntos de regras liberados sem custo; FR-027, FR-028 e SC-007 plenamente atendidos. Código, histórico e especificações passam a ser visíveis e indexáveis publicamente, de forma difícil de reverter na prática. |
| B | Assinar plano pago da hospedagem | Repositório segue privado e proteção plena é ativada. Introduz custo recorrente e dependência de plano. |
| C | Manter privado sem proteção no servidor, compensando com verificação automática obrigatória e disciplina de processo | Sem custo e sem exposição. FR-028 fica tecnicamente insatisfeito: nada impede escrita direta na linha principal além de convenção. Deve ser registrado como risco residual aceito e reavaliado. |
| Custom | Outra combinação | Ex.: manter privado agora e tornar público apenas quando houver conteúdo publicável; ou usar espelho protegido. Descrever o arranjo desejado. |

**Your choice**: _aguardando resposta_

### Q2: Licença do código

**Context**: FR-032, US5 cenário 4. A licença está no escopo desta feature, mas o
conteúdo não foi definido e não há padrão razoável — a escolha é jurídica e estratégica,
não técnica.

**What we need to know**: Qual licença se aplica ao código do The Band?

**Suggested Answers**:

| Option | Answer | Implications |
|--------|--------|--------------|
| A | Apache-2.0 | Permissiva com concessão expressa de patente e exigência de aviso de mudanças. Comum em plataforma corporativa que pretende adoção externa. |
| B | MIT | Permissiva, mínima e amplamente compreendida. Sem cláusula expressa de patente. |
| C | Proprietária / todos os direitos reservados | Nenhuma concessão de uso a terceiros. Coerente com repositório privado, mas impede contribuição e uso externos. |
| Custom | Outra licença | Ex.: AGPL-3.0 para forçar abertura de derivados de serviço, ou licença dupla. Indicar qual e por quê. |

**Your choice**: _aguardando resposta_
