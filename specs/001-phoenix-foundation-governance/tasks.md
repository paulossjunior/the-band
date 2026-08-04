---

description: "Task list for feature 001 — Fundação e governança da plataforma"
---

# Tasks: Fundação e governança da plataforma

**Input**: Design documents from `specs/001-phoenix-foundation-governance/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: **OBRIGATÓRIOS.** A constituição exige teste para toda regra relevante, proíbe
reduzir ou remover teste para o pipeline passar, e FR-031 inclui `mix test` entre os
portões. Tarefas de teste vêm antes da implementação correspondente e devem falhar antes
de existir implementação.

**Organization**: agrupadas por user story, na ordem de prioridade da especificação.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência pendente)
- **[Story]**: user story à qual a tarefa pertence (US1…US5)
- Caminho de arquivo exato em toda descrição

## Path Conventions

Aplicação Phoenix na raiz do repositório: `lib/the_band/`, `lib/the_band_web/`,
`test/`, `priv/repo/migrations/`, `config/`, `docs/`, `.github/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: inicializar o projeto e as ferramentas de qualidade, com as versões
verificadas em [research.md](research.md) R1.

- [ ] T001 Gerar aplicação Phoenix na raiz com `echo Y | mix phx.new . --app the_band --module TheBand --no-mailer --no-gettext --no-dashboard`. O `echo Y` é **obrigatório**: em diretório não vazio o gerador pergunta `[Yn]` e **aborta** sem entrada disponível (R1, verificado). Confirmar depois que `.git`, `.github/`, `.specify/`, `.claude/`, `specs/`, `CLAUDE.md`, `README.md` e `.gitignore` sobreviveram, e decidir o que fazer com o `AGENTS.md` que o gerador 1.8.9 cria
- [ ] T002 Fixar em `mix.exs` as versões verificadas em R1: `phoenix ~> 1.8.9`, `phoenix_live_view ~> 1.2`, `ecto_sql ~> 3.14`, `postgrex ~> 0.22`, `oban ~> 2.23`, `req ~> 0.7`, `jason ~> 1.4`, `credo ~> 1.7` e `dialyxir ~> 1.4` (ambos `only: [:dev, :test], runtime: false`), `mox ~> 1.2` (`only: :test`). Não usar `postgrex 1.0.0-rc` nem `jason 1.5.0-alpha` — são pre-release (R1)
- [ ] T003 Declarar `elixir: "~> 1.20"` em `mix.exs` e registrar Elixir 1.20.2 / OTP 29 no `README.md`
- [ ] T004 [P] Configurar `.formatter.exs` incluindo `priv/repo/migrations` e `.credo.exs` nos padrões de entrada
- [ ] T005 [P] Criar `.credo.exs` a partir de `mix credo.gen.config`, ajustando **apenas** `Credo.Check.Design.AliasUsage` com justificativa em comentário no próprio arquivo: em modo estrito o código gerado pelo Phoenix 1.8.9 produz 3 achados e `mix credo --strict` sai com código 2 (R4). Nenhuma outra checagem estrita pode ser afrouxada
- [ ] T006 [P] Criar `.dialyzer_ignore.exs` (pode iniciar vazio) e declarar `dialyzer: [ignore_warnings: ".dialyzer_ignore.exs", plt_add_apps: [:mix, :ex_unit]]` em `mix.exs` — exigido pelo aviso observado em R3
- [ ] T007 [P] Criar `compose.yaml` com **apenas** o serviço PostgreSQL 17 (`postgres:17-alpine`), volume nomeado e verificação de prontidão. A aplicação executa no hospedeiro em desenvolvimento (Assumptions da spec)
- [ ] T008 [P] Criar `.env.example` com todas as variáveis obrigatórias (`DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `PORT`, `THE_BAND_OPERATOR_SECRET`) e **nenhum valor real** — FR-006
- [ ] T009 [P] Criar `LICENSE` com o texto integral de Apache-2.0, titular do copyright e ano — FR-040. Encerra o risco residual de repositório público sem permissão de uso concedida
- [ ] T010 Rodar os cinco portões localmente como linha de base e registrar a saída, **nesta ordem**: `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix credo --strict`, `mix dialyzer`, `mix test`. A ordem não é estética: **`mix credo` não compila o projeto antes de rodar** (R5), e sem a compilação a checagem customizada de SC-002 não carrega e o Credo sai com código 0. `mix credo --strict` só passa com T005 concluída (R4)

**Checkpoint**: projeto compila, os cinco portões passam localmente, licença declarada.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: infraestrutura que **toda** user story depende.

**⚠️ CRÍTICO**: nenhuma user story começa antes desta fase terminar.

- [ ] T011 Configurar `TheBand.Repo` em `lib/the_band/repo.ex` com `binary_id` como tipo de chave primária padrão e `utc_datetime_usec` como tipo de timestamp padrão
- [ ] T012 Implementar validação de variáveis obrigatórias em `config/runtime.exs`, falhando a inicialização com mensagem que **nomeia** a variável ausente — FR-007. Nenhum valor padrão inseguro
- [ ] T013 [P] Teste em `test/the_band/runtime_config_test.exs` verificando que a ausência de cada variável obrigatória produz erro nomeando-a — FR-007
- [ ] T014 Configurar Oban em `config/config.exs` e `config/test.exs` com uma fila `default`, e adicionar `Oban` à árvore de supervisão em `lib/the_band/application.ex`. Em teste usar `testing: :manual`
- [ ] T015 Criar migração `priv/repo/migrations/*_add_oban_jobs.exs` com `Oban.Migration.up(version: 14)` e `Oban.Migration.down(version: 1)`. **v14, não v12**: a pesquisa original testou com `plugins: false`, configuração em que `verify_migrated!/1` aceita v12; com `Oban.Plugins.Pruner` o arranque exige v14 — ver a correção de R1 em [research.md](research.md)
- [ ] T016 [P] Implementar `TheBand.Telemetry.Correlation` em `lib/the_band/telemetry/correlation.ex`: geração e propagação do identificador de correlação — FR-029
- [ ] T017 [P] Implementar plug `TheBandWeb.Plugs.CorrelationId` em `lib/the_band_web/plugs/correlation_id.ex`, propagando o cabeçalho `X-Correlation-Id` recebido ou gerando um, e devolvendo-o na resposta — FR-029
- [ ] T018 Implementar `TheBand.Telemetry.Handler` em `lib/the_band/telemetry/handler.ex` emitindo registro estruturado com Tenant, correlação, identificador do trabalho, tentativa, duração, situação e código de erro — FR-028
- [ ] T019 Implementar lista negra de chaves sensíveis usada pelo registro operacional (`token`, `secret`, `password`, `key`, `credential`, `authorization`) em `lib/the_band/telemetry/handler.ex` — FR-030
- [ ] T020 [P] Teste em `test/the_band/telemetry/handler_test.exs` verificando que valor sob chave sensível é omitido ou mascarado — FR-030
- [ ] T021 [P] Ajustar `test/support/data_case.ex` e `test/support/conn_case.ex` para `Ecto.Adapters.SQL.Sandbox`, e registrar a etiqueta `:integration` como excluída por padrão em `test/test_helper.exs`
- [ ] T022 [P] Criar `test/support/tenancy_fixtures.ex` com auxiliares para criar Tenant ativo, Tenant inativo e evento operacional. **Executada na issue #4, não na #2**: os auxiliares referenciam `TheBand.Tenancy.Tenant` e `TheBand.Audit.OperationalEvent`, cujos schemas são T045 e T049. O arquivo não compila antes deles. Defeito de ordenação identificado durante a implementação da issue #2 e corrigido aqui em vez de contornado

**Checkpoint**: aplicação sobe, Oban ativo, correlação propagando, base de teste pronta.
T022 fica pendente e migra para a issue #4 por dependência de schema.

---

## Phase 3: User Story 1 — Subir a plataforma e confirmar saúde (Priority: P1) 🎯 MVP

**Goal**: qualquer pessoa do time clona, sobe o ambiente e confirma que a plataforma está
viva, com detalhamento por componente restrito a operação.

**Independent Test**: em máquina sem estado prévio, seguir só o `README.md` e obter
resposta na verificação de saúde pública em até 15 minutos (SC-001).

### Tests for User Story 1

> Escrever primeiro. Devem falhar antes da implementação.

- [ ] T023 [P] [US1] Teste de contrato em `test/contract/health_contract_test.exs` afirmando que `GET /health` devolve `200` com corpo **exatamente** `{"status":"alive"}` e nenhuma outra chave — SC-009, conforme [contracts/health.md](contracts/health.md)
- [ ] T024 [P] [US1] Teste em `test/the_band_web/controllers/health_controller_test.exs` verificando que `GET /health` devolve `200` mesmo com o armazenamento indisponível, porque não consulta dependência — FR-001
- [ ] T025 [P] [US1] Teste em `test/the_band_web/plugs/operator_secret_test.exs` cobrindo os três casos de recusa: sem cabeçalho, com segredo errado, e com segredo ausente da configuração — todos `401` com corpo idêntico — FR-003, SC-009
- [ ] T026 [P] [US1] Teste em `test/contract/health_contract_test.exs` verificando que `GET /health/detail` com segredo válido devolve `200` com `components` contendo `database` e `background_jobs`, e `503` com `database: "down"` quando o armazenamento está indisponível — FR-002, FR-004
- [ ] T027 [P] [US1] Teste de integração em `test/integration/migration_reversibility_test.exs` aplicando e revertendo as migrações em base vazia e em base já inicializada — FR-008, SC-015

### Implementation for User Story 1

- [ ] T028 [US1] Implementar `TheBand.Health` em `lib/the_band/health.ex` com `alive?/0` que não consulta dependência e `detailed/0` que verifica armazenamento e mecanismo de trabalho assíncrono — FR-001, FR-002
- [ ] T029 [US1] Implementar `TheBandWeb.Plugs.OperatorSecret` em `lib/the_band_web/plugs/operator_secret.ex` usando `Plug.Crypto.secure_compare/2`, recusando quando o segredo não está configurado — FR-003, R9
- [ ] T030 [P] [US1] Implementar `TheBandWeb.HealthController` em `lib/the_band_web/controllers/health_controller.ex` para o caminho público — FR-001
- [ ] T031 [P] [US1] Implementar `TheBandWeb.HealthDetailController` em `lib/the_band_web/controllers/health_detail_controller.ex` para o caminho restrito, sem expor credencial, host interno, versão nem rastro de pilha — FR-002, FR-004
- [ ] T032 [US1] Declarar em `lib/the_band_web/router.ex` dois caminhos **distintos**: `/health` público e `/health/detail` atrás do plug de segredo. Caminhos separados, não corpo variável por autorização (R9)
- [ ] T033 [US1] Escrever a seção de inicialização do `README.md` com os comandos exatos do bloco 1 de [quickstart.md](quickstart.md), sem nenhum passo manual não documentado — FR-005, SC-001
- [ ] T034 [US1] Executar o bloco 1 e o bloco 2 de [quickstart.md](quickstart.md) em ambiente limpo, cronometrar, e registrar a evidência — FR-005, SC-001, SC-009

**Checkpoint**: US1 entrega valor isolado — ambiente reproduzível com saúde verificável.

---

## Phase 4: User Story 2 — Isolamento entre Tenants (Priority: P1)

**Goal**: dado de um Tenant nunca é visível, contável ou alterável a partir do contexto de
outro, e ausência de contexto **levanta erro** em vez de devolver vazio.

**Independent Test**: dois Tenants com eventos operacionais próprios; provar por teste
automatizado que nenhuma operação no contexto de um alcança o outro (SC-003).

### Tests for User Story 2

- [ ] T035 [P] [US2] Teste em `test/the_band/tenancy/scope_test.exs` cobrindo a tabela de `scope/1` de [contracts/tenancy.md](contracts/tenancy.md): ativo → `{:ok, scope}`; inativo → `{:error, :tenant_inactive}`; inexistente, `nil` e valor não-UUID → `{:error, :tenant_not_found}`. Nunca cria Tenant implicitamente — FR-013, FR-014, FR-016
- [ ] T036 [P] [US2] Teste em `test/the_band/tenancy_test.exs` para `register_tenant/1`: `slug` duplicado rejeitado, `slug` fora de `^[a-z0-9-]{3,63}$` rejeitado, `name` duplicado **aceito** — FR-010, FR-011, SC-008
- [ ] T037 [P] [US2] Teste em `test/the_band/tenancy_test.exs` provando que `slug` é imutável: nenhum caminho público altera o identificador legível — FR-010, SC-008
- [ ] T038 [P] [US2] Teste em `test/the_band/tenancy_test.exs` para desativação: dados preservados, `scope/1` recusa, e `admin_fetch_tenant/1` continua devolvendo o Tenant — FR-017
- [ ] T039 [P] [US2] Teste em `test/the_band/audit_test.exs` verificando que `record_event/2` ignora `tenant_id` passado nos atributos e usa o do escopo, e que chave sensível em `metadata` é rejeitada — FR-019, FR-030
- [ ] T040 [P] [US2] Teste em `test/the_band/audit_test.exs` verificando que toda função escopada **levanta** quando o primeiro argumento não é `Scope.t()` — nunca devolve `[]` nem `0` — FR-014, SC-004
- [ ] T041 [P] [US2] Teste de integração em `test/integration/tenant_isolation_test.exs` com dois Tenants reais, cobrindo a matriz de [contracts/tenancy.md](contracts/tenancy.md): listar, contar, alterar e remover cruzados, mais acesso sem escopo — FR-015, SC-002, SC-003, SC-004
- [ ] T042 [P] [US2] Teste semântico em `test/the_band/semantic_boundaries_test.exs` verificando que `tenants` não tem coluna de organização de domínio, que `operational_events` não referencia projeto, atividade ou processo, e que nenhum módulo existe sob `lib/the_band/ontology/` nesta entrega — guarda contra fusão de Tenant com `eo.organization` nas features 005 e 006

### Implementation for User Story 2

- [ ] T043 [P] [US2] Criar migração `priv/repo/migrations/*_create_tenants.exs` com `slug varchar(63) NOT NULL`, índice único `tenants_slug_index`, restrição de verificação `slug_format` com `slug ~ '^[a-z0-9-]{3,63}$'`, `name text NOT NULL`, `active boolean NOT NULL DEFAULT true` e timestamps — FR-009, FR-010, verificado em R8
- [ ] T044 [P] [US2] Criar migração `priv/repo/migrations/*_create_operational_events.exs` com `tenant_id NOT NULL` referenciando `tenants(id)` `ON DELETE RESTRICT`, `type`, `correlation_id`, `occurred_at`, `metadata jsonb NOT NULL DEFAULT '{}'`, e índice `(tenant_id, occurred_at)` — FR-012, FR-018, ver [data-model.md](data-model.md)
- [ ] T045 [US2] Implementar schema `TheBand.Tenancy.Tenant` em `lib/the_band/tenancy/tenant.ex`, com `slug` **ausente** da lista de campos permitidos em alteração — é assim que a imutabilidade é imposta (R8)
- [ ] T046 [US2] Implementar `TheBand.Tenancy.Scope` em `lib/the_band/tenancy/scope.ex` como estrutura opaca, não construtível fora de `Tenancy.scope/1` e `scope!/1`
- [ ] T047 [US2] Implementar `TheBand.Tenancy.Queries` em `lib/the_band/tenancy/queries.ex` e `TheBand.Tenancy.Commands` em `lib/the_band/tenancy/commands.ex`
- [ ] T048 [US2] Implementar a API pública `TheBand.Tenancy` em `lib/the_band/tenancy.ex` com as assinaturas exatas de [contracts/tenancy.md](contracts/tenancy.md), incluindo `admin_fetch_tenant/1` para Tenant inativo — FR-009 a FR-017
- [ ] T049 [P] [US2] Implementar schema `TheBand.Audit.OperationalEvent` em `lib/the_band/audit/operational_event.ex` com validação de chave sensível em `metadata` — FR-018, FR-030
- [ ] T050 [US2] Implementar `TheBand.Audit.Queries` e `TheBand.Audit.Commands` em `lib/the_band/audit/`, aplicando filtro por `tenant_id` a partir do escopo em toda consulta e contagem — FR-019, FR-020
- [ ] T051 [US2] Implementar a API pública `TheBand.Audit` em `lib/the_band/audit.ex` recebendo `Scope.t()` como primeiro argumento em toda função escopada, e **levantando** quando não recebe escopo — FR-014, FR-018 a FR-020
- [ ] T052 [US2] Declarar `requires: ["./credo_checks/**/*.ex"]` em `.credo.exs`. **Não** adicionar `credo_checks` a `elixirc_paths`: verificado em R5 que combinar os dois produz `warning: redefining module` a cada execução. `requires` sozinho carrega a checagem com `_build` limpo, o que remove a dependência de ordem entre compilação e análise estática
- [ ] T053 [US2] Implementar checagem customizada de Credo em `credo_checks/no_direct_repo_access.ex` que reprova chamada direta a `TheBand.Repo.<função>` fora de `TheBand.Tenancy.*`, `TheBand.Audit.*`, `TheBand.Repo.Migrations.*` e `Mix.Tasks.TheBand.*`, e registrá-la em `.credo.exs` — SC-002, R5
- [ ] T054 [P] [US2] Teste em `test/the_band/credo_check_test.exs` verificando a própria lista de módulos autorizados, para que ampliá-la seja mudança visível em revisão, **e** afirmando que `TheBand.Credo.Check.NoDirectRepoAccess` está carregável — SC-002
- [ ] T055 [US2] Garantir que `MIX_ENV=prod mix compile` conclui sem incluir nenhum módulo de `credo_checks/` no build de produção — verificado em R5, deve permanecer verdadeiro
- [ ] T056 [US2] **Guarda contra no-op silencioso**: fazer o passo de análise estática reprovar quando a saída do Credo contiver `Ignoring an undefined check`. **Verificado em R5**: `mix credo` não compila antes de rodar, e checagem não carregada apenas imprime aviso e sai com código **0** — sem esta guarda, SC-002 pode deixar de ser verificado sem nada falhar
- [ ] T057 [US2] Escrever `priv/repo/seeds.exs` criando um Tenant de desenvolvimento com `slug` válido — sustenta SC-001 e o bloco 4 de [quickstart.md](quickstart.md)
- [ ] T058 [US2] Executar o bloco 4 de [quickstart.md](quickstart.md) e registrar a evidência, incluindo que `count_events(nil)` levanta em vez de devolver `0` — SC-002 a SC-004, SC-008

**Checkpoint**: isolamento provado por teste automatizado e imposto por análise estática.

---

## Phase 5: User Story 3 — Trabalho assíncrono confiável (Priority: P2)

**Goal**: cada unidade de trabalho declara seu Tenant, é rejeitada definitivamente quando o
Tenant é ausente, inexistente ou inativo, é idempotente e deixa rastro correlacionável.

**Independent Test**: enfileirar unidade com Tenant válido e observar conclusão; enfileirar
sem Tenant e observar `cancelled` com `attempt = 1` (SC-005).

**Depende de US2**: o trabalhador valida Tenant por `Tenancy.scope/1`, e não consulta a
tabela por conta própria — a regra não pode existir em dois lugares. Dependência declarada
na própria especificação da US3.

### Tests for User Story 3

- [ ] T059 [P] [US3] Teste em `test/the_band/jobs/tenant_health_check_test.exs` cobrindo os quatro casos verificados em R6, com `state` e `attempt` esperados: ativo → `completed`/1; sem `tenant_id` → `cancelled`/1; inativo → `cancelled`/1; inexistente → `cancelled`/1 — FR-022, FR-023, FR-024, SC-005, SC-006
- [ ] T060 [P] [US3] Teste em `test/the_band/jobs/tenant_health_check_test.exs` afirmando que o motivo fica persistido em `errors` e é consultável — FR-027
- [ ] T061 [P] [US3] Teste de integração em `test/integration/idempotency_test.exs` executando o mesmo trabalho 10 vezes com a mesma entrada e afirmando estado final idêntico ao de uma única execução — FR-026, SC-007
- [ ] T062 [P] [US3] Teste em `test/integration/idempotency_test.exs` verificando que a segunda inserção com os mesmos argumentos devolve a mesma id com conflito marcado, em vez de criar segundo trabalho — FR-026, R7
- [ ] T063 [P] [US3] Teste em `test/the_band/jobs/tenant_health_check_test.exs` afirmando que todo evento de telemetria do trabalho carrega Tenant, correlação, identificador do trabalho e tentativa — FR-028, SC-016

### Implementation for User Story 3

- [ ] T064 [US3] Implementar `TheBand.Jobs.TenantHealthCheck` em `lib/the_band/jobs/tenant_health_check.ex` seguindo a ordem de validação obrigatória de [contracts/worker.md](contracts/worker.md) e retornando `{:cancel, motivo}` — **nunca** `{:error, motivo}` — para Tenant ausente, inexistente ou inativo, porque `{:error, ...}` retentaria e violaria FR-024 (R6)
- [ ] T065 [US3] Em `lib/the_band/jobs/tenant_health_check.ex`, registrar a execução via `TheBand.Audit.record_event/2` usando o escopo validado — FR-018, FR-021
- [ ] T066 [US3] Anexar os manipuladores de telemetria de `[:the_band, :job, :start | :stop | :exception]` em `lib/the_band/telemetry/handler.ex`, com duração, tentativa, situação e código de erro — FR-028
- [ ] T067 [US3] Definir a política de novas tentativas com espera crescente e limite máximo em `lib/the_band/jobs/tenant_health_check.ex` (`max_attempts` e `backoff/1`) — FR-025
- [ ] T068 [US3] Executar o bloco 5 de [quickstart.md](quickstart.md) e registrar a evidência, incluindo `attempt = 1` em todos os cancelados — SC-005 a SC-007, SC-016

**Checkpoint**: trabalho assíncrono rejeita, não retenta o que não deve, e é idempotente.

---

## Phase 6: User Story 4 — Impedir mudança não verificada na linha principal (Priority: P2)

**Goal**: nenhuma mudança chega à linha principal sem os cinco portões e sem revisão de
outra pessoa.

**Independent Test**: abrir proposta de mudança com violação deliberada de cada portão e
observar a reprovação; corrigir e observar a aprovação (SC-010).

### Implementation for User Story 4

- [ ] T069 [US4] Criar `.github/workflows/ci.yml` com `erlef/setup-beam` fixando Elixir 1.20.2 e OTP 29, PostgreSQL 17 como serviço do fluxo de trabalho, e os cinco portões **nesta ordem**: `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix credo --strict`, `mix dialyzer`, `mix test`. A compilação precisa vir antes do Credo, senão a checagem de SC-002 não carrega (R5, e ver T056) — FR-031, FR-032, FR-034, R10
- [ ] T070 [US4] Configurar no `ci.yml` cache de `deps` e `_build` e cache **separado** do PLT do Dialyzer, com chave incluindo versão de OTP, versão de Elixir e hash de `mix.lock` — o PLT leva 1m40s sem cache e 3s com cache (R3), e sem isso o orçamento de 10 minutos de SC-012 fica comprometido
- [ ] T071 [US4] Incluir no `ci.yml` a execução de `mix ecto.migrate` e `mix test --only integration` contra o serviço PostgreSQL — FR-034
- [ ] T072 [US4] Garantir que `mix deps.compile` **não** use `--warnings-as-errors`: `oban 2.23.1` emite alerta próprio em Elixir 1.20 (`lib/oban/repo.ex:253`), que é da dependência e não do projeto (R1)
- [ ] T073 [US4] Criar `.github/workflows/security.yml` com verificação de credencial versionada e de dependência com vulnerabilidade conhecida (`mix deps.audit` ou equivalente), reprovando a proposta em caso de achado — FR-033
- [ ] T074 [P] [US4] Criar `.github/PULL_REQUEST_TEMPLATE.md` exigindo escopo, fora de escopo, testes, resultado dos portões e evidências — FR-037
- [ ] T075 [P] [US4] Criar `.github/ISSUE_TEMPLATE/feature-request.yml`, `bug-report.yml`, `technical-task.yml` e `research-task.yml` — FR-038
- [ ] T076 [P] [US4] Criar `.github/CODEOWNERS` declarando responsáveis por revisão das áreas do código — FR-039
- [ ] T077 [US4] **Evidência de SC-011**: executar o bloco 7 de [quickstart.md](quickstart.md) — tentativa real de envio direto à linha principal — e anexar a saída de erro ao PR — FR-036. A configuração de `protect-main` já está confirmada no servidor, mas o comportamento ainda **não** foi observado; o princípio V da constituição proíbe declarar sucesso sem evidência
- [ ] T078 [US4] Registrar no conjunto de regras `protect-main` **todas** as verificações de `ci.yml` e `security.yml` como verificações obrigatórias de status (`required_status_checks`), de modo que a incorporação seja impossível com qualquer uma reprovada, ausente ou pendente — FR-035. **Encerra o risco residual** da cláusula `Mantenedor único` da constituição: até esta tarefa, a proteção se reduz a exigir Pull Request
- [ ] T079 [US4] **Evidência de SC-011a**: com uma verificação obrigatória deliberadamente reprovada, e depois com uma pendente, tentar incorporar de fato e confirmar que o servidor bloqueia nos dois casos. Anexar a evidência ao PR — este é o substituto mecânico da aprovação humana; sem ele a cláusula `Mantenedor único` fica sem lastro
- [ ] T080 [US4] Verificar que `bypass_actors` do conjunto de regras permanece **vazio** após T078, inclusive para quem administra o repositório, e registrar no `README.md` a condição de reversão automática: ao entrar a segunda pessoa com permissão de escrita, restaurar `required_approving_review_count: 1` sem nova emenda — FR-036, FR-036a, SC-011. Ver bloco 7.3 e 7.4 de [quickstart.md](quickstart.md)
- [ ] T081 [US4] **Evidência de SC-010**: introduzir uma violação deliberada por portão, conforme a tabela do bloco 6 de [quickstart.md](quickstart.md), confirmar a reprovação de cada um e reverter
- [ ] T082 [US4] Medir o tempo total do fluxo de verificação com cache aquecido e sem cache, e registrar contra o limite de 10 minutos — SC-012

**Checkpoint**: os princípios do projeto passam a ser obrigação executada pelo servidor.

---

## Phase 7: User Story 5 — Recuperar por que a fundação foi decidida assim (Priority: P3)

**Goal**: alguém que entra no projeto meses depois entende as decisões estruturais e as
alternativas descartadas usando só o repositório.

**Independent Test**: pessoa externa ao projeto responde as três perguntas do bloco 9 de
[quickstart.md](quickstart.md) em até 10 minutos (SC-014).

### Implementation for User Story 5

- [ ] T083 [P] [US5] Criar `docs/adr/0001-monolito-modular-multitenant.md` com contexto, alternativas consideradas (microserviços, backend adicional), decisão, consequências e data — FR-041
- [ ] T084 [P] [US5] Criar `docs/adr/0002-estrategia-de-isolamento-por-tenant.md` registrando base única com tabelas compartilhadas e `tenant_id`, a rejeição explícita de banco por Tenant, **e** a evidência de R2: Row Level Security devolve conjunto vazio silenciosamente quando o contexto está ausente, não satisfazendo FR-014, além de exigir papel não-dono e transação em toda leitura. Registrar RLS como feature futura com a evidência já levantada — FR-042
- [ ] T085 [P] [US5] Criar `docs/adr/0003-tenant-nao-e-organizacao.md` explicitando que Tenant é fronteira de instalação e `eo.organization` é objeto social do domínio, que um Tenant contém várias organizações, e que fundi-los destruiria a capacidade de comparar organizações dentro do mesmo contratante — FR-043
- [ ] T086 [P] [US5] Criar `docs/architecture/overview.md` com o fluxo da plataforma, os módulos e a fronteira entre infraestrutura (`tenancy`, `audit`) e o futuro domínio ontológico
- [ ] T087 [US5] Verificar que os três arquivos de `docs/adr/` usam formato e numeração consistentes (mesmo cabeçalho, mesma ordem de seções, numeração `NNNN-`), permitindo referência estável — FR-044
- [ ] T088 [US5] Executar o teste de SC-014 do bloco 9 de [quickstart.md](quickstart.md) com uma pessoa externa ao projeto e registrar o resultado

**Checkpoint**: decisões estruturais recuperáveis sem perguntar a ninguém.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T089 [P] Atualizar `CLAUDE.md` com o estado real após a entrega: aplicação Phoenix existente, módulos disponíveis, comandos de execução
- [ ] T090 [P] Atualizar `README.md` com a licença Apache-2.0 declarada e remover a nota de que ela viria depois
- [ ] T091 Verificar que `lib/the_band/ontology/` e `priv/knowledge_base/` **não** existem nesta entrega — a constituição proíbe criar pasta antes de a feature justificar; pertencem às features 002 e 003
- [ ] T092 Rodar o bloco 8 de [quickstart.md](quickstart.md): varredura de credencial em todo o histórico e conferência de `.env.example` — SC-013
- [ ] T093 Executar [quickstart.md](quickstart.md) do início ao fim e preencher a matriz de cobertura dos 16 critérios com a evidência de cada um
- [ ] T094 Rodar os cinco portões mais `mix ecto.migrate` e `mix test --only integration` e anexar as saídas ao PR — FR-031, FR-032
- [ ] T095 Abrir o Pull Request usando o modelo de T074, com mapeamento de requisito para evidência, e solicitar revisão independente. **Não aprovar o próprio PR** — restrição da constituição

---

## Mapa tarefa → GitHub Issue

Rastreabilidade exigida pela constituição: necessidade → especificação → tarefa → **issue**
→ branch → código → teste → PR → entrega.

| Issue | Fase | Tarefas | Branch |
|---|---|---|---|
| [#2](https://github.com/paulossjunior/the-band/issues/2) Fundação | 1 e 2 | T001–T021 | `feature/2-fundacao-base` |
| [#3](https://github.com/paulossjunior/the-band/issues/3) US1 🎯 MVP | 3 | T023–T034 | `feature/3-ambiente-e-saude` |
| [#4](https://github.com/paulossjunior/the-band/issues/4) US2 | 4 | **T022** + T035–T058 | `feature/4-isolamento-tenant` |
| [#5](https://github.com/paulossjunior/the-band/issues/5) US3 | 5 | T059–T068 | `feature/5-trabalho-assincrono` |
| [#6](https://github.com/paulossjunior/the-band/issues/6) US4 | 6 | T069–T082 | `feature/6-verificacao-obrigatoria` |
| [#7](https://github.com/paulossjunior/the-band/issues/7) US5 | 7 | T083–T088 | `docs/7-adrs` |
| [#8](https://github.com/paulossjunior/the-band/issues/8) Acabamento | 8 | T089–T095 | `chore/8-acabamento` |

Um Pull Request por issue, conforme o princípio VI da constituição — 95 tarefas em um único
PR contrariaria "mudanças pequenas, verificáveis e reversíveis". Commits encerram a issue
com `Closes #N`.

**Bloqueio geral de incorporação**: nenhum PR pode ser incorporado antes do ajuste do
conjunto de regras e da incorporação do PR #1 (emenda da constituição 2.0.0). Código pode
ser escrito e enviado nas branches; apenas o merge está travado.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Fase 1)**: sem dependência
- **Foundational (Fase 2)**: depende da Fase 1 — **bloqueia todas as user stories**
- **US1 (Fase 3)**: depende da Fase 2
- **US2 (Fase 4)**: depende da Fase 2. Independente de US1
- **US3 (Fase 5)**: depende da Fase 2 **e da US2** — usa `Tenancy.scope/1`
- **US4 (Fase 6)**: depende da Fase 2. Fica mais útil depois de US1 a US3 existirem, porque então há testes reais para os portões executarem
- **US5 (Fase 7)**: depende da Fase 2. ADR-0002 fica melhor depois de US2, que produz a evidência
- **Polish (Fase 8)**: depende de todas as anteriores

### User Story Dependencies

```text
Fase 1 → Fase 2 ─┬─► US1 (P1)
                 ├─► US2 (P1) ──► US3 (P2)
                 ├─► US4 (P2)
                 └─► US5 (P3)
```

**Única dependência entre histórias**: US3 → US2. Declarada na especificação e deliberada —
duplicar a validação de Tenant no trabalhador criaria duas fontes da mesma regra.

### Within Each User Story

- Teste escrito e **falhando** antes da implementação
- Migração antes de schema; schema antes de comando e consulta; comando e consulta antes da API pública
- API pública antes do consumidor (camada web, trabalhador)
- Evidência executada por último, e registrada

### Parallel Opportunities

- T004 a T009 em paralelo (arquivos distintos)
- T013, T016, T017, T020, T021, T022 em paralelo dentro da Fase 2
- Todos os testes de uma mesma história em paralelo (T023 a T027; T035 a T042; T059 a T063)
- T043 e T044 em paralelo (migrações independentes)
- T074 a T076 em paralelo; T083 a T086 em paralelo
- Com equipe: US1, US2, US4 e US5 em paralelo depois da Fase 2. US3 espera US2

---

## Parallel Example: User Story 2

```bash
# Todos os testes da US2 juntos (devem falhar antes da implementação):
Task: "Teste de scope/1 em test/the_band/tenancy/scope_test.exs"
Task: "Teste de register_tenant/1 em test/the_band/tenancy_test.exs"
Task: "Teste de imutabilidade de slug em test/the_band/tenancy_test.exs"
Task: "Teste de desativação em test/the_band/tenancy_test.exs"
Task: "Teste de record_event/2 em test/the_band/audit_test.exs"
Task: "Teste de acesso sem escopo em test/the_band/audit_test.exs"
Task: "Teste de isolamento em test/integration/tenant_isolation_test.exs"
Task: "Teste semântico em test/the_band/semantic_boundaries_test.exs"

# As duas migrações juntas:
Task: "Migração create_tenants em priv/repo/migrations/"
Task: "Migração create_operational_events em priv/repo/migrations/"
```

---

## Implementation Strategy

### MVP First (US1 apenas)

1. Fase 1: Setup
2. Fase 2: Foundational — **crítica, bloqueia tudo**
3. Fase 3: US1
4. **PARAR E VALIDAR**: bloco 1 e bloco 2 de [quickstart.md](quickstart.md), cronometrados
5. Já entrega valor: ambiente reproduzível e idêntico entre pessoas do time

### Incremental Delivery

1. Setup + Foundational → fundação pronta
2. US1 → ambiente e saúde verificáveis → **MVP**
3. US2 → isolamento provado e imposto por análise estática
4. US3 → trabalho assíncrono confiável
5. US4 → portões obrigatórios no servidor
6. US5 → decisões recuperáveis
7. Polish → evidência completa dos 16 critérios e PR

**Nota sobre a ordem de US4**: mover US4 para antes de US1 faria o CI existir sem código
significativo para verificar, e as evidências de SC-010 e SC-012 teriam de ser refeitas
depois. Fazê-la depois de US1 a US3 produz evidência válida na primeira execução.

---

## Notas

- Tarefas `[P]` são arquivos diferentes, sem dependência pendente
- Nenhuma tarefa pode ser marcada concluída sem evidência — princípio V da constituição
- **T077 é obrigatória e não pode ser dispensada**: SC-011 é o único critério que a
  especificação e o plano não conseguiram provar; exige tentativa real de envio
- Não reduzir nem remover teste para fazer os portões passarem
- Commit por tarefa ou por grupo lógico coerente; mensagem no padrão
  `tipo(escopo): descrição imperativa`
- Toda tarefa desta lista pertence à mesma feature; não misturar outra feature no mesmo PR
