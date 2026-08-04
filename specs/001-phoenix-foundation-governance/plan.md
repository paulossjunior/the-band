# Implementation Plan: Fundação e governança da plataforma

**Branch**: `feature/001-phoenix-foundation-governance` | **Date**: 2026-08-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-phoenix-foundation-governance/spec.md`

## Summary

Entregar a fundação mínima verificável do The Band: aplicação Phoenix com LiveView,
PostgreSQL via Ecto, Oban, Req, verificação de saúde em dois níveis, isolamento por
Tenant imposto por abstração única de escopo, esqueleto de observabilidade com correlação,
verificação automática de cinco portões de qualidade no CI, governança de repositório e
três registros de decisão arquitetural.

Nenhuma ontologia, nenhum arquivo da base de conhecimento declarativa, nenhum conector
externo e nenhuma medida fazem parte desta feature.

Abordagem técnica derivada da pesquisa ([research.md](research.md)), toda verificada por
execução no ambiente real: escopo de Tenant em camada de aplicação que **levanta erro** na
ausência de contexto — Row Level Security foi testada e descartada para esta feature
porque devolve conjunto vazio silenciosamente em vez de rejeitar, não satisfazendo FR-014;
`{:cancel, motivo}` do Oban para rejeição definitiva sem nova tentativa; unicidade nativa
do Oban para idempotência de enfileiramento; checagem customizada de Credo para provar
SC-002 automaticamente.

## Technical Context

**Language/Version**: Elixir 1.20.2, Erlang/OTP 29 (erts-17.0.4) — verificados em execução

**Primary Dependencies**: `phoenix 1.8.9`, `phoenix_live_view 1.2.8`, `ecto_sql 3.14.0`,
`postgrex 0.22.3`, `oban 2.23.1`, `req 0.7.2`, `bandit 1.12.4`, `jason 1.4.5`,
`telemetry_metrics 1.1.0`; ferramentas de desenvolvimento `credo 1.7.19`,
`dialyxir 1.4.7`, `mox 1.2.0`. Versões resolvidas e compiladas com sucesso — ver R1.

**Storage**: PostgreSQL 17.10, base única com tabelas compartilhadas e coluna `tenant_id`

**Testing**: ExUnit; `Mox` para contratos de fronteira; `Ecto.Adapters.SQL.Sandbox` para
isolamento; testes de integração marcados com etiqueta `:integration`

**Target Platform**: servidor Linux; desenvolvimento local em macOS e Linux com
PostgreSQL em contêiner

**Project Type**: aplicação web monolítica modular (serviço único com interface LiveView)

**Performance Goals**: não definidos pela especificação. A verificação de saúde pública
não consulta dependência alguma, portanto é barata por construção. Alvos de latência e
volume pertencem a feature de capacidade futura.

**Constraints**: verificação automática completa em até 10 minutos (SC-012); inicialização
local até resposta saudável em até 15 minutos (SC-001); Dialyzer medido em 1m40s sem cache
e 3s com PLT cacheado — cache de PLT é obrigatório no CI

**Scale/Scope**: fundação. Duas tabelas de domínio próprio (`tenants`,
`operational_events`) mais as tabelas do Oban. Uma rota pública, uma rota autenticada por
segredo de operação, um trabalhador assíncrono de verificação.

## Constitution Check

*GATE: deve passar antes da pesquisa da Fase 0. Reavaliado após o desenho da Fase 1.*

| Princípio da constituição | Situação | Evidência |
|---|---|---|
| I — Especificação antes de código | **PASSA** | `spec.md` escrito, `clarify` concluído com 7 decisões registradas, checklist 15/16 |
| II — Semântica primeiro, ferramenta depois | **PASSA** | Nenhuma ontologia nesta feature. Seção `Terminologia canônica` separa Tenant de `eo.organization`. Notas semânticas impedem fusão de `operational_events` com `spo.performed_activity` |
| III — Proveniência e rastreabilidade | **PASSA (parcial por escopo)** | Correlação e Tenant em todo registro operacional (FR-028, FR-029). Proveniência de dado externo não se aplica: não há integração nesta feature |
| IV — Nenhuma métrica sem necessidade de informação | **PASSA** | Nenhuma medida, indicador ou painel nesta feature |
| V — Evidência antes de conclusão | **PASSA** | Toda decisão da pesquisa verificada por execução. SC-011 permanece reprovado no checklist por falta de evidência empírica |
| VI — Simplicidade evolutiva | **PASSA** | Monólito único. RLS adiada em vez de somada. Nenhuma tecnologia fora da stack obrigatória |
| VII — Idempotência | **PASSA** | FR-026 com unicidade do Oban e escrita por chave natural, verificado em R7 |
| VIII — Base de conhecimento como artefato de domínio | **N/A** | Nenhum YAML de conhecimento nesta feature; pertence à 002 |
| Restrição de stack | **PASSA** | Nenhuma tecnologia da lista proibida. Nenhuma biblioteca além da stack obrigatória |
| Multitenancy | **PASSA** | Base única, tabelas compartilhadas, `tenant_id`, trabalho assíncrono valida Tenant |
| Segurança | **PASSA** | Nenhum segredo versionado, `.env.example` sem valor real, segredo de operação por variável de ambiente |
| ADR obrigatório | **PASSA** | ADR-0001, 0002 e 0003 previstos — ver seção de documentação |
| Fluxo de trabalho | **PASSA** | Branch própria, PR obrigatório, `protect-main` ativo sem ator de exceção |

**Nenhuma violação a justificar.** A seção `Complexity Tracking` fica vazia.

**Reavaliação após Fase 1**: mantida. O desenho não introduziu módulo, dependência ou
mecanismo além dos verificados na pesquisa.

## Project Structure

### Documentation (this feature)

```text
specs/001-phoenix-foundation-governance/
├── spec.md               # Especificação (concluída)
├── plan.md               # Este arquivo
├── research.md           # Fase 0 (concluída)
├── data-model.md         # Fase 1
├── quickstart.md         # Fase 1
├── contracts/            # Fase 1
│   ├── health.md
│   ├── tenancy.md
│   └── worker.md
├── checklists/
│   └── requirements.md   # 15/16
└── tasks.md              # Fase 2 — gerado por /speckit-tasks, NÃO por /speckit-plan
```

### Source Code (repository root)

```text
the-band/
├── mix.exs
├── mix.lock
├── compose.yaml                       # apenas PostgreSQL
├── .env.example                       # sem valor real
├── .formatter.exs
├── .credo.exs                         # ajuste justificado de Design.AliasUsage (R4)
├── .dialyzer_ignore.exs               # exigido por dialyxir (R3)
├── LICENSE                            # Apache-2.0 (FR-040)
│
├── credo_checks/                      # carregado por `requires:` no .credo.exs (R5)
│   └── no_direct_repo_access.ex       # SC-002 — fora de lib/ para não quebrar prod
│
├── .github/
│   ├── CODEOWNERS
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── ISSUE_TEMPLATE/
│   │   ├── feature-request.yml
│   │   ├── bug-report.yml
│   │   ├── technical-task.yml
│   │   └── research-task.yml
│   └── workflows/
│       ├── ci.yml                     # 5 portões + PostgreSQL como serviço
│       └── security.yml               # segredos + dependências vulneráveis
│
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── test.exs
│   ├── prod.exs
│   └── runtime.exs                    # falha nomeando variável ausente (FR-007)
│
├── docs/
│   ├── architecture/
│   │   └── overview.md
│   └── adr/
│       ├── 0001-monolito-modular-multitenant.md
│       ├── 0002-estrategia-de-isolamento-por-tenant.md
│       └── 0003-tenant-nao-e-organizacao.md
│
├── lib/
│   ├── the_band.ex
│   ├── the_band/
│   │   ├── application.ex
│   │   ├── repo.ex
│   │   ├── tenancy.ex                 # API pública do isolamento
│   │   ├── tenancy/
│   │   │   ├── scope.ex               # escopo validado, levanta na ausência
│   │   │   ├── tenant.ex              # schema Ecto
│   │   │   ├── commands.ex
│   │   │   └── queries.ex
│   │   ├── audit.ex                   # API pública de evento operacional
│   │   ├── audit/
│   │   │   ├── operational_event.ex   # schema Ecto
│   │   │   ├── commands.ex
│   │   │   └── queries.ex
│   │   ├── jobs/
│   │   │   └── tenant_health_check.ex # trabalhador de verificação
│   │   ├── telemetry/
│   │   │   ├── handler.ex
│   │   │   └── correlation.ex
│   │   └── health.ex                  # agregação de estado por componente
│   │
│   └── the_band_web/
│       ├── endpoint.ex
│       ├── router.ex
│       ├── telemetry.ex
│       ├── plugs/
│       │   ├── correlation_id.ex
│       │   └── operator_secret.ex     # segredo em tempo constante
│       ├── controllers/
│       │   ├── health_controller.ex   # público: apenas vivacidade
│       │   └── health_detail_controller.ex
│       └── components/
│
├── priv/repo/
│   ├── migrations/
│   │   ├── ..._create_tenants.exs
│   │   ├── ..._create_operational_events.exs
│   │   └── ..._add_oban_jobs.exs
│   └── seeds.exs                      # cria Tenant de desenvolvimento
│
└── test/
    ├── support/
    │   ├── conn_case.ex
    │   ├── data_case.ex
    │   └── tenancy_fixtures.ex
    ├── the_band/
    │   ├── tenancy_test.exs
    │   ├── tenancy/scope_test.exs
    │   ├── audit_test.exs
    │   └── jobs/tenant_health_check_test.exs
    ├── the_band_web/
    │   ├── health_controller_test.exs
    │   └── plugs/operator_secret_test.exs
    ├── contract/
    │   └── health_contract_test.exs
    └── integration/
        ├── tenant_isolation_test.exs         # SC-003, SC-004
        ├── idempotency_test.exs              # SC-007, lote de 10
        └── migration_reversibility_test.exs  # SC-015
```

**Por que `credo_checks/` na raiz e não em `test/` nem em `lib/`** — verificado por execução
(R5): `test/credo/` não é compilado em nenhum ambiente, porque `elixirc_paths(:test)` inclui
apenas `["lib", "test/support"]`; e um módulo em `lib/` que usa `Credo.Check` **quebra
`MIX_ENV=prod`**, porque `credo` é `only: [:dev, :test]`.

**Mecanismo de carregamento: `requires:` no `.credo.exs`**, não `elixirc_paths`.

```elixir
# .credo.exs
requires: ["./credo_checks/**/*.ex"]
```

Verificado com `_build` limpo: o Credo lê o código-fonte da checagem, detecta a violação e
sai com código 16, **sem** o diretório estar em `elixirc_paths`. Isso remove a dependência
de ordem entre compilação e análise estática.

Adicionar o diretório a `elixirc_paths` **além** de `requires` produz
`warning: redefining module` em cada execução, porque a checagem passaria a ser compilada e
requerida. Portanto: `requires` sozinho.

**Risco residual que permanece**: se o diretório for renomeado, ou o nome do módulo divergir
do declarado em `checks.enabled`, o Credo emite `Ignoring an undefined check` e sai com
código **0**. Verificado. É por isso que a guarda contra no-op silencioso continua
obrigatória.

**Structure Decision**: estrutura padrão de aplicação Phoenix com `lib/the_band` para o
domínio e `lib/the_band_web` para a interface, conforme a organização de monorepo definida
na constituição. As pastas de ontologia (`lib/the_band/ontology/**`) e de base de
conhecimento (`priv/knowledge_base/`) **não** são criadas nesta feature — a constituição
proíbe criar pasta vazia antes de a feature justificar.

`tenancy` e `audit` são módulos de infraestrutura, deliberadamente fora de
`lib/the_band/ontology/`, para que ninguém os confunda com módulo ontológico.

**Sem `Dockerfile` nesta feature**: publicação em ambiente produtivo e entrega por release
estão explicitamente fora de escopo na especificação, `compose.yaml` sobe apenas o
PostgreSQL, e a aplicação executa no hospedeiro em desenvolvimento. Nenhum requisito
funcional exige imagem de contêiner da aplicação. Pertence a feature de entrega futura.

## Módulos Elixir

| Módulo | Responsabilidade | Quem pode chamar |
|---|---|---|
| `TheBand.Repo` | acesso ao armazenamento | **apenas** `TheBand.Tenancy`, `TheBand.Audit`, migrações e tarefas administrativas marcadas. Imposto por checagem de Credo (R5) |
| `TheBand.Tenancy` | API pública de Tenant e escopo | qualquer módulo |
| `TheBand.Tenancy.Scope` | estrutura de escopo validado | qualquer módulo |
| `TheBand.Audit` | API pública de evento operacional | qualquer módulo |
| `TheBand.Health` | agregação de estado por componente | camada web |
| `TheBand.Telemetry.Correlation` | geração e propagação de correlação | camada web e trabalhos |
| `TheBand.Jobs.TenantHealthCheck` | trabalhador de verificação | enfileirado por operação |

Nenhum módulo acessa schema Ecto de outro módulo. `TheBand.Audit` recebe escopo já
validado de `TheBand.Tenancy` e não valida Tenant por conta própria.

## API pública

```elixir
defmodule TheBand.Tenancy do
  @doc "Constrói escopo validado. Erro se o Tenant não existir ou estiver inativo."
  @spec scope(Ecto.UUID.t()) :: {:ok, Scope.t()} | {:error, :tenant_not_found | :tenant_inactive}
  def scope(tenant_id)

  @spec scope!(Ecto.UUID.t()) :: Scope.t()
  def scope!(tenant_id)

  @spec register_tenant(map()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
  def register_tenant(attrs)

  @doc "Renomeia. O identificador legível é imutável e não é aceito aqui (FR-010)."
  @spec rename_tenant(Scope.t(), String.t()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
  def rename_tenant(scope, name)

  @spec deactivate_tenant(Ecto.UUID.t()) :: {:ok, Tenant.t()} | {:error, term()}
  def deactivate_tenant(tenant_id)

  @spec activate_tenant(Ecto.UUID.t()) :: {:ok, Tenant.t()} | {:error, term()}
  def activate_tenant(tenant_id)

  @doc "Leitura administrativa, fora de escopo. Único caminho para Tenant inativo (FR-017)."
  @spec admin_fetch_tenant(Ecto.UUID.t()) :: {:ok, Tenant.t()} | {:error, :not_found}
  def admin_fetch_tenant(tenant_id)
end

defmodule TheBand.Audit do
  @spec record_event(Scope.t(), map()) :: {:ok, OperationalEvent.t()} | {:error, Ecto.Changeset.t()}
  def record_event(scope, attrs)

  @spec list_events(Scope.t(), keyword()) :: [OperationalEvent.t()]
  def list_events(scope, opts \\ [])

  @spec count_events(Scope.t()) :: non_neg_integer()
  def count_events(scope)

  @doc "Leitura administrativa de Tenant inativo, fora de escopo (FR-017)."
  @spec admin_list_events(Ecto.UUID.t(), keyword()) :: [OperationalEvent.t()]
  def admin_list_events(tenant_id, opts \\ [])
end

defmodule TheBand.Health do
  @spec alive?() :: boolean()
  def alive?()

  @spec detailed() :: %{status: :healthy | :unhealthy, components: %{atom() => :up | :down}}
  def detailed()
end
```

**Regra imposta por análise estática**: toda função que toca dado tenant-scoped recebe
`Scope.t()` como primeiro argumento. Não existe variante que aceite `tenant_id` cru fora
de `Tenancy.scope/1` e das funções `admin_*`.

## Schemas Ecto

```elixir
schema "tenants" do
  field :slug,   :string          # único, imutável, ^[a-z0-9-]{3,63}$
  field :name,   :string          # livre, alterável, não único
  field :active, :boolean, default: true
  timestamps(type: :utc_datetime_usec)
end

schema "operational_events" do
  field :type,           :string
  field :correlation_id, :string
  field :occurred_at,    :utc_datetime_usec
  field :metadata,       :map, default: %{}   # sem conteúdo sensível (FR-030)
  belongs_to :tenant, TheBand.Tenancy.Tenant, type: :binary_id
end
```

Chave primária `binary_id` em ambas. Detalhes de campo, restrição e transição de estado em
[data-model.md](data-model.md).

## Migrações

1. `create_tenants` — tabela, índice único em `slug`, restrição de verificação
   `slug ~ '^[a-z0-9-]{3,63}$'`. **Verificado em R8**: ambas rejeitam de fato no banco.
2. `create_operational_events` — `tenant_id` `NOT NULL` com chave estrangeira
   `ON DELETE RESTRICT`, índice composto `(tenant_id, occurred_at)`.
3. `add_oban_jobs` — `Oban.Migration.up(version: 14)` / `down(version: 1)`. A v12 foi corrigida para v14
   durante a implementação — ver a correção de R1 em [research.md](research.md).

Todas reversíveis. SC-015 exige aplicar e reverter sem erro em base vazia e em base já
inicializada — coberto por `test/integration/migration_reversibility_test.exs`.

## Dependências entre módulos

```text
the_band_web  →  TheBand.Health, TheBand.Tenancy, TheBand.Audit
TheBand.Audit →  TheBand.Tenancy.Scope   (consome escopo, não valida Tenant)
TheBand.Tenancy → TheBand.Repo
TheBand.Audit   → TheBand.Repo
TheBand.Jobs.*  → TheBand.Tenancy, TheBand.Audit
```

Sem ciclo. `TheBand.Tenancy` não conhece `TheBand.Audit`.

## YAMLs e schemas de validação

**Não se aplica a esta feature.** Nenhum arquivo da base de conhecimento declarativa,
nenhum schema de validação de YAML e nenhuma tarefa `mix knowledge.*` fazem parte da 001.
Pertencem à feature 002. Os únicos YAML desta feature são configuração de fluxo de
trabalho do GitHub e modelos de solicitação — não são base de conhecimento.

## Carregamento e cache da base de conhecimento

**Não se aplica a esta feature.** Decisão pertence à feature 002, com ADR próprio.

## Constraints de banco

| Constraint | Requisito | Verificado |
|---|---|---|
| `tenants_slug_index` (único) | FR-010, SC-008 | R8 — rejeita duplicado |
| `slug_format` (verificação por expressão regular) | FR-010, SC-008 | R8 — rejeita `'AB'` |
| `operational_events.tenant_id NOT NULL` | FR-012 | — |
| chave estrangeira `ON DELETE RESTRICT` | FR-017 (desativação não remove) | — |
| índice `(tenant_id, occurred_at)` | desempenho de consulta escopada | — |

## Validações de domínio

- `slug` ausente da lista de campos permitidos em alteração → imutabilidade (FR-010, R8).
- `name` obrigatório, sem exigência de unicidade (FR-011).
- `Tenancy.scope/1` consulta existência **e** ativação; devolve
  `{:error, :tenant_not_found}` ou `{:error, :tenant_inactive}` (FR-016).
- Toda função de acesso escopado **levanta** quando recebe algo que não é `Scope.t()` —
  é isso que satisfaz FR-014, que RLS não satisfaz (R2).
- `metadata` de evento operacional rejeita chave em lista negra de nomes sensíveis
  (FR-030).

## Eventos internos

Eventos de telemetria emitidos, todos com Tenant e correlação quando aplicável:

```text
[:the_band, :tenancy, :scope, :rejected]       motivo
[:the_band, :audit, :event, :recorded]
[:the_band, :job, :start | :stop | :exception] duração, tentativa, situação, código de erro
[:the_band, :health, :check]                   componente, situação
[:the_band, :repo, :query]                     via telemetria do Ecto
```

Campos exigidos por FR-028: Tenant, correlação, identificador do trabalho, tentativa,
duração, situação, código de erro.

## Mapeamentos

**Não se aplica a esta feature.** Nenhum mapeamento semântico entre fonte externa e
ontologia. Pertence à feature 025 e seguintes.

## Testes conceituais

Não há conceito ontológico nesta feature. Em seu lugar, testes que protegem as distinções
que a especificação registrou:

- teste que verifica que `tenants` **não** tem coluna de organização de domínio, e que
  `operational_events` **não** referencia projeto, atividade ou processo — guarda contra
  fusão de Tenant com `eo.organization` nas features 005 e 006;
- teste que verifica que nenhum módulo sob `lib/the_band/ontology/` existe nesta entrega.

## Testes de contrato

- `health_contract_test.exs` — forma da resposta pública e da detalhada, conforme
  [contracts/health.md](contracts/health.md). A pública **não** deve conter nome de
  componente (SC-009).
- Contrato da API pública de `TheBand.Tenancy` e `TheBand.Audit` conforme
  [contracts/tenancy.md](contracts/tenancy.md): assinatura, retornos de erro nomeados e
  exigência de `Scope.t()`.
- Contrato do trabalhador conforme [contracts/worker.md](contracts/worker.md): argumentos
  exigidos e situações finais possíveis.

## Testes de integração

| Teste | Critério | Método |
|---|---|---|
| `tenant_isolation_test.exs` | SC-003, SC-004 | dois Tenants com eventos; consulta, contagem, alteração e remoção cruzadas; acesso sem escopo levanta |
| `idempotency_test.exs` | SC-007 | lote de 10 execuções do mesmo trabalho, comparação de estado final; unicidade do Oban (R7) |
| `migration_reversibility_test.exs` | SC-015 | aplicar e reverter em base vazia e em base já inicializada |
| `tenant_health_check_test.exs` | SC-005, SC-006 | quatro casos de R6: ativo, sem Tenant, inativo, inexistente — esperando `cancelled` e `attempt = 1` nos três últimos |
| `operator_secret_test.exs` | SC-009 | recusa sem segredo, com segredo errado, e com segredo ausente da configuração |

Marcados com etiqueta `:integration`, executados com PostgreSQL real.

## Documentação

- `README.md` — passos de inicialização que sustentam SC-001 (15 minutos em máquina limpa)
- `docs/architecture/overview.md` — fluxo, módulos, fronteira entre infraestrutura e
  futuro domínio ontológico
- `docs/adr/0001-monolito-modular-multitenant.md` — FR-041
- `docs/adr/0002-estrategia-de-isolamento-por-tenant.md` — FR-042, incluindo a rejeição de
  banco por Tenant **e** a evidência de R2 sobre RLS devolver vazio em vez de rejeitar
- `docs/adr/0003-tenant-nao-e-organizacao.md` — FR-043
- `.env.example` — todas as variáveis obrigatórias, nenhum valor real
- `quickstart.md` — roteiro de validação executável ([quickstart.md](quickstart.md))

## Riscos do plano

| Risco | Probabilidade | Mitigação |
|---|---|---|
| Sem RLS, acesso que ignore a abstração não é barrado pelo banco | média | checagem customizada de Credo (R5) reprova o PR; RLS registrada como feature futura com evidência já levantada |
| **Checagem de Credo vira no-op silencioso**: `mix credo` não compila antes de rodar, e checagem não carregada apenas imprime aviso e sai com código 0 (R5). SC-002 deixaria de ser verificado sem nada falhar | **alta** se não mitigado | `mix compile` antes de `mix credo` na ordem dos portões, **mais** reprovação explícita quando o Credo emitir `Ignoring an undefined check`, **mais** teste afirmando que o módulo é carregável |
| Primeira execução de CI sem cache aproxima-se dos 10 minutos de SC-012 | média | cache de `deps`/`_build` e de PLT com chave incluindo OTP, Elixir e hash de `mix.lock` (R3, R10) |
| `.credo.exs` afrouxado além do necessário para acomodar código gerado | média | apenas `Design.AliasUsage` ajustado, com justificativa no próprio arquivo; nenhuma outra checagem estrita alterada (R4) |
| Imutabilidade de `slug` imposta só na aplicação | baixa | teste dedicado; gatilho de banco registrado como opção se insuficiente (R8) |
| Alerta de compilação do próprio Oban em Elixir 1.20 | baixa | `--warnings-as-errors` só na compilação do projeto, não em `deps.compile` (R1) |
| SC-011 exige tentativa real de envio à linha principal | certa | tarefa explícita de evidência na Fase 2; a configuração já está confirmada no servidor |

## Complexity Tracking

> Preencher SOMENTE se o Constitution Check tiver violações a justificar.

Nenhuma violação. Seção intencionalmente vazia.
