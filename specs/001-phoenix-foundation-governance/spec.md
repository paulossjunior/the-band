# Feature Specification: Fundação e governança da plataforma

**Feature Branch**: `feature/001-phoenix-foundation-governance`

**Created**: 2026-08-03

**Status**: Draft

**Input**: User description: "Fundação Phoenix e governança do The Band. Criar a fundação mínima e verificável do monólito modular multitenant, sem implementar nenhuma ontologia, nenhum YAML de domínio e nenhum conector externo."

## Terminologia canônica

Esta especificação usa os termos abaixo de forma estrita. A distinção não é estilística:
confundir os dois primeiros funde dois conceitos diferentes e contamina todas as features
seguintes.

| Termo | Significado | Onde vive |
|---|---|---|
| **Tenant** | Unidade de isolamento da instalação. Quem contrata e opera esta instalação do The Band. Delimita quais dados nunca podem se misturar com dados de outro contratante. | Esta feature. Coluna `tenant_id`. |
| **Organização** | Organização do mundo real cujo desenvolvimento de software é analisado — objeto social do domínio, conceito `eo.organization`. | Feature 005, ontologia EO. **Fora do escopo desta feature.** |
| **Evento operacional** | Fato registrado sobre a execução da própria plataforma, pertencente a um Tenant. | Esta feature. |

Um Tenant pode conter várias Organizações. Exemplo: uma consultoria contrata o The Band
(1 Tenant) para analisar o desenvolvimento de software de doze clientes (12 Organizações).
Se os conceitos forem fundidos, a consultoria precisaria de doze instalações isoladas e
perderia justamente a capacidade de comparar seus clientes entre si.

A palavra "organização" **não** é usada nesta especificação como sinônimo de Tenant.

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
   **Then** a plataforma responde na verificação de saúde pública indicando que está viva.
2. **Given** plataforma em execução, **When** a verificação de saúde pública é consultada
   sem credencial, **Then** a resposta informa apenas se a plataforma está viva, sem
   nomear componentes internos nem seus estados.
3. **Given** plataforma em execução, **When** a verificação de saúde detalhada é consultada
   com credencial de operação válida, **Then** a resposta informa separadamente a
   conectividade com o armazenamento de dados e com o mecanismo de trabalho assíncrono.
4. **Given** plataforma em execução, **When** a verificação de saúde detalhada é consultada
   sem credencial ou com credencial inválida, **Then** o acesso é recusado e nenhum estado
   de componente é revelado.
5. **Given** armazenamento de dados indisponível, **When** a verificação de saúde detalhada
   é consultada com credencial válida, **Then** a resposta indica estado não saudável e
   identifica o componente com falha, sem expor credenciais, host interno ou detalhe
   sensível.
6. **Given** repositório recém-clonado, **When** a pessoa procura instruções de
   configuração, **Then** encontra um arquivo de exemplo de variáveis de ambiente sem
   nenhum valor real de credencial.
7. **Given** ambiente local inicializado, **When** a estrutura de dados inicial é
   aplicada e em seguida revertida, **Then** ambas as operações concluem sem erro e o
   armazenamento volta ao estado anterior.

---

### User Story 2 - Garantir isolamento entre Tenants desde o primeiro dado (Priority: P1)

A plataforma atende múltiplos Tenants na mesma instalação. Quem opera precisa da garantia
de que dado de um Tenant nunca é visível, contável ou alterável a partir do contexto de
outro Tenant — e essa garantia precisa existir antes de qualquer dado real entrar no
sistema.

**Why this priority**: Isolamento retroencaixado é a fonte clássica de vazamento entre
contratantes. Adicioná-lo depois exigiria revisar todo acesso a dados já escrito. Precisa
ser a primeira restrição estrutural, não a última.

**Independent Test**: Cadastrar dois Tenants, gravar eventos operacionais em cada um, e
provar por teste automatizado que uma consulta feita no contexto do Tenant A nunca
retorna, conta ou altera evento do Tenant B.

**Acceptance Scenarios**:

1. **Given** dois Tenants cadastrados, cada um com eventos operacionais próprios,
   **When** uma consulta é feita no contexto do Tenant A, **Then** nenhum evento do
   Tenant B é retornado.
2. **Given** dois Tenants com eventos próprios, **When** uma contagem é feita no contexto
   do Tenant A, **Then** o total desconsidera integralmente os eventos do Tenant B.
3. **Given** dois Tenants cadastrados, **When** uma tentativa de alteração ou remoção
   aponta para registro de outro Tenant, **Then** a operação é rejeitada e nenhum dado é
   modificado.
4. **Given** um acesso a dados da fundação, **When** o contexto de Tenant está ausente,
   **Then** a operação é rejeitada com erro explícito em vez de operar sobre todos os
   Tenants.
5. **Given** o código-fonte da fundação, **When** o time verifica os pontos de acesso ao
   armazenamento, **Then** todos passam pela abstração única de escopo de Tenant,
   verificável automaticamente.
6. **Given** identificador de Tenant inexistente, **When** usado como contexto, **Then**
   a operação é rejeitada sem criar Tenant implicitamente.
7. **Given** Tenant desativado, **When** usado como contexto de acesso comum, **Then** a
   operação é rejeitada; **e** seus dados permanecem existentes e legíveis por rotina
   administrativa explícita.
8. **Given** um Tenant criado, **When** há tentativa de alterar seu identificador legível,
   **Then** a alteração é rejeitada.
9. **Given** um Tenant existente com determinado identificador legível, **When** há
   tentativa de criar outro Tenant com o mesmo identificador legível, **Then** a criação é
   rejeitada.

---

### User Story 3 - Executar trabalho assíncrono confiável e rastreável (Priority: P2)

A plataforma precisa executar coleta, transformação e cálculo em segundo plano. Quem
opera precisa que cada unidade de trabalho declare a qual Tenant pertence, seja
reexecutável sem efeito colateral duplicado, e deixe rastro suficiente para diagnóstico.

**Why this priority**: Toda integração futura depende deste mecanismo. Sem a validação
de contexto de Tenant e sem rastro correlacionável, os conectores nascem inseguros
e indepuráveis. Vem depois de US1 e US2 porque depende de ambiente e de isolamento.

**Independent Test**: Enfileirar uma unidade de trabalho de verificação com Tenant válido
e observar sua conclusão bem-sucedida; enfileirar a mesma unidade sem Tenant e observar
rejeição registrada.

**Acceptance Scenarios**:

1. **Given** mecanismo de trabalho assíncrono em execução, **When** uma unidade de
   verificação é enfileirada com Tenant válido, **Then** ela conclui com sucesso e o
   resultado fica consultável.
2. **Given** mecanismo em execução, **When** uma unidade é enfileirada sem Tenant
   declarado, **Then** ela é rejeitada com erro explícito e não é reexecutada
   indefinidamente.
3. **Given** unidade de trabalho enfileirada para um Tenant que é desativado antes da
   execução, **When** a unidade é retirada da fila, **Then** ela falha permanentemente com
   motivo que identifica Tenant inativo, sem nova tentativa, permanecendo consultável para
   diagnóstico.
4. **Given** unidade de trabalho que falha por causa transitória, **When** o mecanismo
   reprocessa, **Then** novas tentativas ocorrem com espera crescente e limite máximo
   definido.
5. **Given** a mesma unidade de trabalho executada duas vezes com a mesma entrada,
   **Then** o estado resultante é idêntico ao de uma única execução.
6. **Given** unidade concluída ou falha, **When** o registro operacional é inspecionado,
   **Then** contém Tenant, identificador de correlação, identificador da unidade,
   número da tentativa, duração e situação final.

---

### User Story 4 - Impedir que mudança não verificada entre na linha principal (Priority: P2)

Quem mantém o repositório precisa da garantia de que nenhuma mudança chega à linha
principal sem passar por verificação automática de formatação, compilação sem alerta,
análise estática, análise de tipos e testes, todas registradas como obrigatórias no
servidor — e, quando houver mais de uma pessoa mantenedora, sem revisão de outra pessoa.

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
6. **Given** proposta de mudança com qualquer verificação obrigatória reprovada, ausente ou
   pendente, **When** se tenta incorporar, **Then** o servidor bloqueia a incorporação.
7. **Given** repositório com mais de uma pessoa com permissão de escrita e proposta
   aprovada em todas as verificações, **When** ninguém revisou, **Then** a incorporação é
   impedida.
8. **Given** tentativa de escrita direta na linha principal, **When** o envio é executado,
   **Then** o servidor o rejeita, inclusive para quem administra o repositório.
9. **Given** todas as verificações executando, **When** o tempo total é medido, **Then**
   fica dentro do limite definido em Success Criteria.

---

### User Story 5 - Recuperar por que a fundação foi decidida assim (Priority: P3)

Uma pessoa que entra no projeto meses depois precisa entender, sem perguntar a ninguém,
por que a plataforma é um sistema único modular em vez de vários serviços, e por que o
isolamento entre Tenants foi feito daquela forma — incluindo as alternativas descartadas.

**Why this priority**: Evita retrabalho e reversão acidental de decisão estrutural.
Valor real, mas não bloqueia execução das features seguintes.

**Independent Test**: Pedir a alguém de fora do projeto para localizar e resumir as duas
decisões estruturais e suas alternativas descartadas usando apenas o repositório.

**Acceptance Scenarios**:

1. **Given** repositório, **When** a pessoa procura decisões estruturais, **Then**
   encontra registro datado da decisão de sistema único modular, com contexto,
   alternativas consideradas e consequências.
2. **Given** repositório, **When** a pessoa procura a decisão de isolamento entre
   Tenants, **Then** encontra registro equivalente, incluindo a rejeição explícita
   de base de dados separada por Tenant.
3. **Given** repositório, **When** a pessoa procura por que Tenant e Organização são
   entidades diferentes, **Then** encontra a distinção registrada de forma explícita.
4. **Given** pessoa abrindo a primeira proposta de mudança, **When** consulta o
   repositório, **Then** encontra modelo de proposta e modelos de solicitação que
   exigem evidência, escopo, fora de escopo e critérios de aceitação.
5. **Given** repositório, **When** a pessoa procura os termos de uso do código,
   **Then** encontra a licença aplicável de forma inequívoca.

---

### Edge Cases

- Armazenamento de dados fica indisponível depois da inicialização: a verificação de
  saúde passa a indicar estado não saudável em vez de a plataforma encerrar.
- Contexto de Tenant presente mas apontando para Tenant inexistente: operação rejeitada,
  sem criação implícita.
- Tenant desativado com dados existentes: dados preservados e legíveis apenas por rotina
  administrativa explícita, nunca por acesso comum. Nada é removido pela desativação.
- Tenant desativado com unidades de trabalho já enfileiradas: cada unidade falha
  permanentemente ao ser retirada da fila, sem nova tentativa, e permanece consultável.
  A fila não fica bloqueada nem executa trabalho de Tenant inativo.
- Tenant reativado depois de desativado: dados e histórico voltam a ser acessíveis por
  acesso comum; as unidades de trabalho que falharam por Tenant inativo não são
  reexecutadas automaticamente.
- Duas unidades de trabalho concorrentes sobre o mesmo alvo: resultado equivalente a
  execução serial, sem registro duplicado.
- Unidade de trabalho falha permanentemente: para de ser tentada ao atingir o limite,
  permanecendo consultável para diagnóstico.
- Estrutura de dados inicial aplicada duas vezes: segunda aplicação não tem efeito e não
  falha o processo de inicialização.
- Variável de ambiente obrigatória ausente na inicialização: falha imediata com mensagem
  nomeando a variável, em vez de partir com valor padrão inseguro.
- Credencial de operação da verificação de saúde detalhada não configurada: a verificação
  detalhada recusa todo acesso, em vez de liberar acesso sem credencial.
- Registro operacional recebendo valor sensível: o valor é omitido ou mascarado.
- Verificação automática executada sem acesso ao armazenamento de dados: reprova de
  forma explícita, sem marcar teste como aprovado por ausência.

## Requirements *(mandatory)*

### Functional Requirements

**Ambiente e verificação de saúde**

- **FR-001**: O sistema MUST expor uma verificação de saúde pública que informe apenas se
  a plataforma está viva, sem nomear componentes internos nem revelar seus estados.
- **FR-002**: O sistema MUST expor uma verificação de saúde detalhada que reporte
  separadamente a conectividade com o armazenamento de dados e com o mecanismo de trabalho
  assíncrono.
- **FR-003**: A verificação de saúde detalhada MUST exigir credencial de operação válida e
  MUST recusar acesso sem ela, sem revelar estado de componente na recusa.
- **FR-004**: Nenhuma das verificações de saúde MUST expor credencial, endereço interno,
  versão de dependência ou detalhe de configuração sensível.
- **FR-005**: O sistema MUST poder ser inicializado localmente por comandos documentados,
  a partir de repositório recém-clonado, sem passo manual não documentado.
- **FR-006**: O repositório MUST conter arquivo de exemplo de variáveis de ambiente
  contendo todas as variáveis obrigatórias e nenhum valor real.
- **FR-007**: O sistema MUST falhar a inicialização com mensagem nomeando a variável
  ausente quando uma variável obrigatória não estiver definida.
- **FR-008**: A estrutura de dados inicial MUST poder ser aplicada e revertida sem erro.

**Tenant e isolamento**

- **FR-009**: O sistema MUST registrar Tenant como entidade própria, com identificador
  estável, nome, identificador legível, situação de ativação e momento de criação.
- **FR-010**: O identificador legível do Tenant MUST ser único em toda a instalação,
  imutável após a criação, e restrito ao formato de letras minúsculas, dígitos e hífen,
  com 3 a 63 caracteres.
- **FR-011**: O nome do Tenant MUST ser alterável e MUST NOT exigir unicidade.
- **FR-012**: Toda entidade de dados da fundação, exceto o próprio Tenant, MUST estar
  associada a exatamente um Tenant.
- **FR-013**: Todo acesso a dados da fundação MUST ocorrer através de uma abstração
  única e explícita de escopo de Tenant.
- **FR-014**: O sistema MUST rejeitar acesso a dados quando o contexto de Tenant estiver
  ausente, em vez de operar sobre todos os Tenants.
- **FR-015**: O sistema MUST rejeitar leitura, contagem, alteração e remoção de registro
  pertencente a Tenant diferente do contexto ativo.
- **FR-016**: O sistema MUST rejeitar contexto que aponte para Tenant inexistente ou
  desativado, sem criá-lo implicitamente.
- **FR-017**: Desativar um Tenant MUST preservar integralmente seus dados, mantendo-os
  legíveis apenas por rotina administrativa explícita, nunca por acesso comum, e MUST NOT
  remover nem anonimizar dado algum.

**Evento operacional**

- **FR-018**: O sistema MUST manter registro de eventos operacionais, cada um pertencente
  a exatamente um Tenant, contendo tipo, momento de ocorrência, identificador de
  correlação e dados complementares não sensíveis.
- **FR-019**: Toda gravação e toda consulta de evento operacional MUST ocorrer através da
  abstração de escopo de Tenant.
- **FR-020**: Consulta ou contagem de eventos operacionais no contexto de um Tenant MUST
  NOT retornar nem computar evento de outro Tenant.

**Trabalho assíncrono**

- **FR-021**: O sistema MUST executar unidades de trabalho em segundo plano, de forma
  persistente e observável.
- **FR-022**: Toda unidade de trabalho MUST declarar o Tenant ao qual pertence.
- **FR-023**: O sistema MUST rejeitar unidade de trabalho sem Tenant declarado ou com
  Tenant inexistente, registrando o motivo.
- **FR-024**: Unidade de trabalho cujo Tenant foi desativado após o enfileiramento MUST
  falhar permanentemente na retirada da fila, com motivo que identifique Tenant inativo,
  sem nova tentativa, permanecendo consultável para diagnóstico.
- **FR-025**: O sistema MUST reprocessar falha transitória com espera crescente e limite
  máximo de tentativas.
- **FR-026**: Reexecutar a mesma unidade de trabalho com a mesma entrada MUST produzir o
  mesmo estado final que uma única execução.
- **FR-027**: O sistema MUST manter consultável a situação, tentativa e motivo de falha
  de cada unidade de trabalho.

**Observabilidade**

- **FR-028**: O sistema MUST emitir registro operacional estruturado contendo, quando
  aplicável: Tenant, identificador de correlação, identificador da unidade de trabalho,
  número da tentativa, duração, situação e código de erro.
- **FR-029**: O sistema MUST propagar um identificador de correlação por requisição e por
  unidade de trabalho, permitindo reconstituir a cadeia de execução.
- **FR-030**: O sistema MUST NOT registrar credencial, token nem conteúdo sensível
  completo de payload.

**Verificação automática e governança**

- **FR-031**: O repositório MUST executar verificação automática, a cada proposta de
  mudança, de: padrão de formatação, compilação sem alerta, análise estática, análise de
  tipos e testes.
- **FR-032**: A verificação automática MUST reprovar a proposta quando qualquer uma
  dessas checagens falhar.
- **FR-033**: A verificação automática MUST incluir checagem de segurança que reprove
  credencial versionada e dependência com vulnerabilidade conhecida.
- **FR-034**: A verificação automática MUST executar contra armazenamento de dados real
  provisionado pelo próprio processo de verificação.
- **FR-035**: A incorporação na linha principal MUST ser impossível enquanto qualquer
  verificação obrigatória estiver reprovada, ausente ou pendente. Todas as verificações de
  FR-031 e FR-033 MUST estar registradas no servidor como verificações obrigatórias de
  status, não apenas executadas.
- **FR-036**: A linha principal MUST ser protegida no servidor contra escrita direta,
  reescrita de histórico e remoção, sem ator de exceção — inclusive para quem administra
  o repositório.
- **FR-036a**: Enquanto o repositório tiver mais de uma pessoa com permissão de escrita, a
  incorporação MUST exigir aprovação de pessoa diferente de quem propôs a mudança. Com uma
  única pessoa com permissão de escrita, a exigência de aprovação humana MUST ser
  substituída pela verificação mecânica de FR-035, e MUST NOT ser dispensada sem
  substituto — conforme a cláusula `Mantenedor único` da constituição.
- **FR-037**: O repositório MUST conter modelo de proposta de mudança exigindo escopo,
  fora de escopo, testes, resultado das verificações e evidências.
- **FR-038**: O repositório MUST conter modelos de solicitação para pedido de
  funcionalidade, relato de defeito, tarefa técnica e tarefa de pesquisa.
- **FR-039**: O repositório MUST declarar responsáveis por revisão das áreas do código.
- **FR-040**: O repositório MUST declarar Apache-2.0 como licença aplicável ao código, com
  titular do copyright e ano, em arquivo de licença na raiz.

**Registro de decisões**

- **FR-041**: O repositório MUST registrar a decisão de adotar sistema único modular
  multitenant, com contexto, alternativas consideradas, consequências e data.
- **FR-042**: O repositório MUST registrar a decisão de estratégia de isolamento entre
  Tenants, incluindo a rejeição explícita de base de dados separada por Tenant.
- **FR-043**: O repositório MUST registrar a distinção entre Tenant e Organização,
  explicitando que não devem ser fundidos e que Organização pertence à feature 005.
- **FR-044**: Os registros de decisão MUST usar formato e numeração consistentes,
  permitindo referência estável.

### Key Entities

- **Tenant**: unidade de isolamento da instalação. Representa quem contrata e opera esta
  instalação do The Band. Atributos essenciais: identificador estável, nome (livre,
  alterável, não único), identificador legível (único na instalação, imutável, formato de
  letras minúsculas, dígitos e hífen com 3 a 63 caracteres), situação de ativação, momento
  de criação. Toda outra entidade de dados da fundação referencia exatamente um Tenant.

  **Nota semântica**: esta entidade é a fronteira de isolamento da instalação. Não é o
  conceito `eo.organization` da ontologia EO, que representa a organização como objeto
  social do domínio analisado e será introduzido pela feature 005. Um Tenant pode conter
  várias organizações de domínio. Os dois conceitos não devem ser fundidos.

- **Evento operacional**: fato registrado sobre a execução da própria plataforma,
  pertencente a exatamente um Tenant. Atributos essenciais: identificador, Tenant, tipo,
  momento de ocorrência, identificador de correlação, dados complementares não sensíveis.

  **Nota semântica**: é registro de operação da plataforma, não `spo.performed_activity`
  nem qualquer evento do domínio analisado. Não representa atividade de processo de
  software de nenhum projeto observado.

- **Unidade de trabalho assíncrono**: intenção de executar processamento em segundo
  plano, pertencente a um Tenant. Atributos essenciais: tipo, argumentos, Tenant,
  situação, número da tentativa, momento de agendamento, momento de conclusão, motivo de
  falha.

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
  escopo de Tenant, verificado por checagem automática que reprova a proposta de mudança
  em caso de desvio.
- **SC-003**: **Zero** vazamento entre Tenants: em cenário com dois Tenants e eventos
  operacionais em ambos, nenhuma operação executada no contexto de um retorna, conta ou
  altera dado do outro.
- **SC-004**: **100%** das tentativas de acesso a dados sem contexto de Tenant são
  rejeitadas.
- **SC-005**: **100%** das unidades de trabalho sem Tenant declarado são rejeitadas.
- **SC-006**: **100%** das unidades de trabalho pertencentes a Tenant desativado falham
  permanentemente sem nova tentativa, e **100%** delas permanecem consultáveis com o
  motivo.
- **SC-007**: Reexecutar a mesma unidade de trabalho com a mesma entrada produz estado
  final idêntico em **100%** das repetições de um lote de pelo menos 10 execuções.
- **SC-008**: **Zero** tentativas bem-sucedidas de criar Tenant com identificador legível
  duplicado, de alterar identificador legível existente, ou de criar identificador legível
  fora do formato definido.
- **SC-009**: A verificação de saúde pública **não** revela nome nem estado de nenhum
  componente interno, e a verificação detalhada recusa **100%** dos acessos sem credencial
  de operação válida.
- **SC-010**: Uma proposta de mudança contendo violação deliberada de qualquer uma das
  cinco verificações é reprovada automaticamente em **100%** dos casos.
- **SC-011**: **100%** das tentativas de escrita direta na linha principal são rejeitadas
  pelo servidor, inclusive para quem administra o repositório — verificado por tentativa
  real de envio, não por leitura de configuração.
- **SC-011a**: **100%** das tentativas de incorporação com qualquer verificação obrigatória
  reprovada, ausente ou pendente são bloqueadas pelo servidor — verificado por tentativa
  real de incorporação, não por leitura de configuração. Este critério é o substituto
  mecânico da aprovação humana sob a cláusula `Mantenedor único`; enquanto ele não estiver
  satisfeito, a proteção se reduz a exigir proposta de mudança.
- **SC-012**: O conjunto completo de verificações automáticas conclui em **até 10
  minutos** desde a abertura da proposta de mudança.
- **SC-013**: **Zero** credencial, token, chave ou arquivo de ambiente real versionado,
  verificado por checagem automática de segurança em todo o histórico da mudança. Como o
  repositório é público, qualquer ocorrência conta como incidente, não como achado a
  corrigir depois.
- **SC-014**: Uma pessoa externa ao projeto localiza e resume as decisões estruturais e
  suas alternativas descartadas em **até 10 minutos**, usando somente o repositório.
- **SC-015**: Aplicar e reverter a estrutura de dados inicial conclui sem erro em
  **100%** das execuções, em base vazia e em base já inicializada.
- **SC-016**: **100%** dos registros operacionais de falha permitem identificar Tenant,
  identificador de correlação e unidade de trabalho envolvidos.

## Assumptions

- **Público**: os únicos usuários desta feature são pessoas do time de desenvolvimento e
  de operação. Não há usuário final da plataforma nesta feature; autenticação de usuário
  final está fora de escopo e será tratada em feature própria.
- **Interface**: a interface visual entregue aqui se limita à verificação de saúde. Não
  há tela de gestão, listagem ou navegação.
- **Contexto de Tenant**: nesta feature o contexto de Tenant é fornecido
  programaticamente ou por configuração, já que não há autenticação. A derivação do
  contexto a partir de sessão autenticada é feature futura.
- **Cadastro de Tenants**: criação de Tenant ocorre por semeadura de dados ou tarefa
  administrativa, não por interface visual.
- **Credencial de operação**: a credencial que libera a verificação de saúde detalhada é
  um segredo único de instalação, fornecido por variável de ambiente. Não é usuário, não é
  papel e não implica sistema de autenticação — apenas um segredo compartilhado de
  operação.
- **Rotina administrativa**: leitura de dados de Tenant desativado ocorre por tarefa
  administrativa executada fora do contexto de Tenant, não por interface nem por endereço
  público.
- **Ambiente local**: assume-se conteinerização apenas do armazenamento de dados; a
  plataforma executa no hospedeiro durante o desenvolvimento.
- **Escopo ontológico**: nenhuma ontologia, nenhum conceito de domínio, nenhum arquivo da
  base de conhecimento declarativa e nenhum mapeamento semântico faz parte desta feature.
  Tenant e evento operacional são infraestrutura, não conceito de domínio. Organização,
  equipe, pessoa, vínculo, projeto e processo pertencem às features 005 e 006 e estão
  explicitamente fora desta feature.
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
- **Visibilidade**: o repositório é **público** desde 2026-08-03 (decisão Q1). Todo
  artefato desta feature — código, especificação, mensagem de commit, exemplo e
  documentação — é escrito assumindo leitura externa.

## Dependencies

- Ambiente de bootstrap já concluído: ferramenta de especificação inicializada,
  constituição ratificada, repositório publicado, linguagem, plataforma de execução e
  armazenamento de dados verificados localmente.
- Acesso administrativo ao repositório remoto para configurar proteção da linha principal
  e responsáveis por revisão. **Satisfeita**: conjunto de regras `protect-main` ativo.
- Nenhuma dependência de sistema externo, fornecedor ou credencial de terceiro.

## Clarifications

### Session 2026-08-03

- Q: Como satisfazer proteção da linha principal, se a hospedagem recusa configurá-la em repositório privado no plano da conta? → A: Tornar o repositório público (aplicado).
- Q: Qual licença se aplica ao código do The Band? → A: Apache-2.0.
- Q: Qual entidade da fundação, além do próprio Tenant, deve existir para que o isolamento seja realmente testável? → A: Registro de evento operacional por Tenant.
- Q: O que acontece com os dados existentes e com as unidades de trabalho já enfileiradas quando um Tenant é desativado? → A: Dados preservados e legíveis apenas por rotina administrativa; unidades enfileiradas falham permanentemente sem nova tentativa, permanecendo consultáveis.
- Q: A verificação de saúde é pública ou restrita? → A: Dois níveis — pública informa apenas se está viva; detalhada por componente exige credencial de operação.
- Q: Qual é o termo canônico para a unidade de isolamento? → A: Tenant. "Organização" fica reservado exclusivamente para `eo.organization`, na feature 005.
- Q: O que identifica um Tenant de forma única? → A: Identificador legível único na instalação, imutável, no formato de letras minúsculas, dígitos e hífen com 3 a 63 caracteres; nome livre e alterável.
- Q: Com uma única pessoa com permissão de escrita, como satisfazer a exigência de aprovação por outra pessoa, se a hospedagem não permite aprovar o próprio Pull Request? → A: Emenda da constituição (2.0.0, cláusula `Mantenedor único`): aprovação humana substituída por verificação mecânica obrigatória no servidor. FR-035 reescrito, FR-036a e SC-011a adicionados.

**Nota de renumeração**: a integração destas clarificações adicionou requisitos em blocos
temáticos existentes. Os requisitos funcionais foram renumerados de forma contígua
(FR-001 a FR-044) e os critérios de sucesso também (SC-001 a SC-016). A renumeração foi
feita nesta fase porque ainda não existem `plan.md`, `tasks.md` nem solicitações
referenciando os identificadores antigos. A partir daqui os identificadores são estáveis.

### Registro detalhado: proteção da linha principal

**Context**: FR-035, FR-036, SC-011. A constituição proíbe escrita direta na linha
principal, proíbe incorporação sem revisão e proíbe aprovar a própria mudança.

**Question**: O repositório foi criado privado. No plano da conta, a plataforma de
hospedagem recusa configurar proteção de linha principal e conjuntos de regras em
repositório privado (`403 Upgrade to GitHub Pro or make this repository public`). Como
satisfazer FR-035 e FR-036?

**Decision**: **Repositório público.** Aplicada em 2026-08-03.

**Rationale**: libera proteção de linha principal e conjuntos de regras sem custo
recorrente e sem dependência de plano pago, satisfazendo FR-035, FR-036 e SC-011 por
mecanismo do servidor em vez de convenção de processo. Alternativas descartadas: plano
pago (custo recorrente para benefício idêntico) e manter privado sem proteção (deixaria
FR-036 tecnicamente insatisfeito, com risco residual permanente).

**Consequências assumidas**:

- Código, histórico completo de commits, especificações e constituição passam a ser
  publicamente visíveis e indexáveis. Reverter a visibilidade não desfaz cópias e
  indexações já realizadas.
- O repositório passa a ser artefato público desde o primeiro commit. Todo conteúdo
  futuro — incluindo mensagens de commit, especificações e exemplos — deve ser escrito
  assumindo leitura externa.
- A proibição de versionar credencial deixa de ser boa prática e passa a ser exposição
  imediata. A checagem de segredos de FR-033 torna-se crítica, não preventiva.

**Evidência de aplicação**:

- Varredura de padrões de credencial em todo o histórico antes da mudança de
  visibilidade: 33 arquivos inspecionados, zero ocorrências.
- Visibilidade confirmada como pública.
- Conjunto de regras `protect-main` criado e ativo sobre a linha principal, sem atores de
  exceção, contendo: bloqueio de remoção, bloqueio de reescrita de histórico e exigência
  de proposta de mudança com uma aprovação, descarte de aprovação obsoleta após novo
  envio, aprovação obrigatória do último envio e resolução obrigatória de comentários.
- Regras confirmadas como vigentes sobre a linha principal por consulta ao servidor.

**Verificação pendente**: SC-011 exige provar empiricamente que envio direto à linha
principal é rejeitado. A tentativa de envio direto deve ser executada e registrada como
evidência durante a implementação desta feature, não apenas declarada pela configuração.

### Registro detalhado: licença do código

**Context**: FR-040, US5 cenário 5. A resolução da questão de visibilidade tornou a
questão urgente: em repositório público sem licença declarada, terceiros não recebem
nenhuma permissão de uso, o que contradiz o ato de publicar.

**Decision**: **Apache-2.0.**

**Rationale**: permissiva, com concessão expressa de patente e exigência de aviso de
mudanças. Adequada a uma plataforma que integra ferramentas de terceiros e pretende
adoção externa e contribuição, sem impor abertura de derivados. Alternativas descartadas:
MIT (sem cláusula expressa de patente, relevante em plataforma que pode acumular
propriedade intelectual), AGPL-3.0 (obrigaria abertura de derivados servidos em rede,
restringindo adoção corporativa) e proprietária (incoerente com repositório público).

**Consequências assumidas**:

- Terceiros podem usar, modificar, redistribuir e explorar comercialmente o código,
  inclusive em produto fechado, desde que preservem aviso de copyright, aviso de licença e
  registro de mudanças.
- Concessão de patente é irrevogável para quem contribui, e cessa para quem litigar
  alegando violação de patente sobre a obra.
- Contribuição externa passa a ser possível, o que exige orientação de contribuição e
  responsáveis por revisão declarados — já previstos em FR-037, FR-038 e FR-039.

**Risco residual em aberto**: entre a publicação do repositório e a criação do arquivo de
licença, o conteúdo está público sem permissão de uso concedida. Janela conhecida e
aceita; encerrada pela tarefa de FR-040.

### Registro detalhado: verificação independente com mantenedor único

**Context**: FR-035, FR-036a, SC-011a. A versão anterior de FR-035 exigia aprovação de
pessoa diferente de quem propôs a mudança, espelhando a constituição v1.0.0.

**Problema, detectado pelo `analyze` antes de qualquer código**: o repositório tem **uma
única pessoa** com permissão de escrita. O conjunto de regras da linha principal exige uma
aprovação e não tem ator de exceção, e a hospedagem não permite que a pessoa autora aprove
o próprio Pull Request. Consequência: **nenhuma mudança poderia ser incorporada**. O
requisito, como escrito, não protegia nada — apenas impedia a entrega. Descobrir isso na
última tarefa, com as 90 concluídas e não incorporáveis, seria o pior momento possível.

**Decision**: emenda da constituição para **2.0.0**, cláusula `Mantenedor único`. A
aprovação humana é substituída por verificação mecânica obrigatória no servidor, mais
estrita em tudo que pode ser automatizado.

**Efeito nos requisitos**:

- **FR-035** reescrito: a incorporação é impossível com qualquer verificação obrigatória
  reprovada, ausente ou pendente, e as verificações precisam estar **registradas no
  servidor**, não apenas executadas. Executar localmente deixa de ser suficiente.
- **FR-036a** adicionado: aprovação humana volta a ser exigida automaticamente quando
  houver mais de uma pessoa com permissão de escrita, sem nova emenda.
- **SC-011** dividido: SC-011 cobre a rejeição de escrita direta; **SC-011a** cobre o
  bloqueio de incorporação com verificação pendente — o substituto mecânico da aprovação.

**Compensações obrigatórias**, porque nenhuma pessoa vai ler o diff de novo: todo requisito
verificável precisa de verificação automatizada; a proposta de mudança declara requisito
por requisito qual evidência o cobre; achado `CRITICAL` ou `HIGH` do `analyze` bloqueia a
incorporação; e revisão independente por outro agente antes de incorporar, **sem** tratá-la
como equivalente a revisão humana.

**Alternativas descartadas**:

- Adicionar segunda pessoa com permissão de escrita: preferível se a pessoa existir.
  Registrada como caminho de reversão, coberta por FR-036a.
- Adicionar quem administra como ator de exceção do conjunto de regras: esvaziaria FR-036 e
  SC-011 justamente para quem mais escreve.
- Manter o requisito e não incorporar nada: regra decorativa; contraria o princípio de
  evidência antes de conclusão.

**Risco residual registrado e aceito**: enquanto as verificações obrigatórias de status não
existirem no servidor, a proteção se reduz a exigir proposta de mudança. Estado transitório,
encerrado pelas tarefas que criam a verificação automática e registram os portões como
obrigatórios.

### Registro detalhado: entidade que prova o isolamento

**Context**: FR-012, FR-013, SC-003. A versão anterior da especificação exigia que toda
entidade de dados pertencesse a um Tenant e exigia provar ausência de vazamento, mas
definia apenas a entidade Tenant — que não pertence a si mesma. O requisito não tinha
sujeito e o critério de sucesso não tinha objeto de teste.

**Decision**: **Registro de evento operacional por Tenant.**

**Rationale**: é a única alternativa que já é necessária de forma independente — FR-028 e
FR-029 exigem registro operacional correlacionável com Tenant, e a estrutura do projeto já
prevê módulo de auditoria. Pertence de fato a um Tenant, exercita `tenant_id` como chave
de escopo real, e não é conceito de domínio ontológico.

**Alternativas descartadas**:

- Nenhuma entidade nova, testando isolamento apenas entre registros de Tenant: prova
  fraca, porque não exercita a coluna de escopo.
- Entidade de fonte externa cadastrada: já é tenant-scoped e real, mas antecipa a feature
  024 e amplia escopo silenciosamente.
- Entidade técnica criada só para o teste e removida depois: polui o esquema de produção
  com artefato de teste.
- Entidades de EO — organização de domínio, equipe, pessoa, vínculo: fariam a fundação
  implementar ontologia antes da feature 003 (infraestrutura comum de ontologias) existir,
  invertendo a ordem do roteiro e forçando modelagem apressada de EO. Registrado como
  proposta válida para as features 005 e 006, não para esta.

### Registro detalhado: desativação de Tenant

**Context**: FR-016, FR-017, FR-024, SC-006. A versão anterior rejeitava contexto de
Tenant desativado, mas não dizia o que acontece com os dados existentes nem com as
unidades de trabalho já enfileiradas.

**Decision**: **Dados preservados e legíveis apenas por rotina administrativa explícita;
unidades de trabalho já enfileiradas falham permanentemente ao serem retiradas da fila,
sem nova tentativa, permanecendo consultáveis com o motivo.**

**Rationale**: comportamento previsível e auditável. Preservar dados mantém a auditoria e
torna a reativação possível. Falhar rápido e definitivamente evita fila entupida e evita
executar trabalho de Tenant inativo.

**Alternativas descartadas**:

- Manter unidades em espera indefinida até reativação: entope a fila e, ao reativar,
  executa trabalho antigo sobre dados obsoletos.
- Cancelar a fila e tornar os dados inacessíveis ou removê-los: destrói auditoria e
  impossibilita reativação.

### Registro detalhado: exposição da verificação de saúde

**Context**: FR-001 a FR-004, SC-009. A versão anterior exigia reportar o estado de cada
componente, mas não dizia quem pode consultar. Com repositório público, o endereço fica
documentado publicamente, e resposta detalhada por componente entrega reconhecimento de
infraestrutura a qualquer pessoa.

**Decision**: **Dois níveis. Verificação pública informa apenas se a plataforma está
viva. Verificação detalhada por componente exige credencial de operação.**

**Rationale**: preserva a utilidade operacional — verificação de infraestrutura continua
funcionando sem credencial — sem publicar topologia interna nem estado de dependências.

**Alternativas descartadas**:

- Tudo público sem detalhe por componente: deixaria FR-002 insatisfeito.
- Tudo público com detalhe: mais simples de operar, mas expõe topologia e estado de
  dependências a qualquer pessoa.

### Registro detalhado: termo canônico da unidade de isolamento

**Context**: FR-009 a FR-020 e a seção `Terminologia canônica`. A versão anterior usava
"organização atendida", "tenant" e "organização" como sinônimos para a unidade de
isolamento, enquanto `eo.organization` chega na feature 005 com o mesmo nome.

**Decision**: **Tenant** é o termo canônico. `tenant_id` no armazenamento, "Tenant" nas
especificações. "Organização" fica reservado exclusivamente para `eo.organization`.

**Rationale**: o projeto prevê dezenas de features e mais de dez ontologias. Manter
"organização" para os dois conceitos criaria ambiguidade permanente sobre o conceito mais
estrutural do sistema, e o erro que ela produz — fusão de conceitos — é o único que a
constituição autoriza a bloquear uma feature. "Tenant" é termo de indústria, sem colisão
com o vocabulário ontológico.

**Alternativas descartadas**:

- "Organização atendida" em português com `tenant_id` no armazenamento: mantém a palavra
  "organização" em ambos os lados, preservando a ambiguidade na conversa e na revisão.
- "Cliente" / `customer`: sem ambiguidade ontológica, mas sugere relação de faturamento e
  fica incorreto quando o Tenant for interno.

**Efeito**: toda a especificação foi reescrita com o termo canônico, e a seção
`Terminologia canônica` foi adicionada no início como referência normativa. FR-043 exige
registrar a distinção em decisão estrutural.

### Registro detalhado: identidade do Tenant

**Context**: FR-009, FR-010, FR-011, SC-008. A versão anterior listava "identificador
estável, nome, identificador legível" sem definir o que é único, o formato, nem a
mutabilidade.

**Decision**: **Identificador legível único em toda a instalação, imutável após a criação,
no formato de letras minúsculas, dígitos e hífen, com 3 a 63 caracteres. Nome livre,
alterável, sem exigência de unicidade.**

**Rationale**: o identificador legível aparece em endereço, registro operacional e
diagnóstico; torná-lo imutável preserva rastreabilidade histórica. O formato restrito
evita ambiguidade de codificação em endereço e em registro. O nome é rótulo humano e pode
repetir legitimamente — duas organizações homônimas podem contratar a plataforma.

**Alternativas descartadas**:

- Identificador legível alterável com histórico de identificadores anteriores: mais
  flexível, mas exige tabela adicional e complexidade sem necessidade demonstrada.
- Apenas identificador opaco, sem identificador legível: elimina a decisão de formato, mas
  torna endereço e registro operacional ilegíveis, prejudicando diagnóstico.
