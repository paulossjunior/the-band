# Contract — Isolamento por Tenant

**Feature**: 001 | **Requisitos**: FR-009 a FR-020, SC-002 a SC-004, SC-008 | **Decisão**: [research.md](../research.md) R2, R5, R8

Contrato da API pública de `TheBand.Tenancy` e `TheBand.Audit`. Estes são os **únicos**
módulos autorizados a chamar `TheBand.Repo`, além de migrações e tarefas administrativas
marcadas — restrição imposta por checagem customizada de Credo (R5).

---

## Invariante central

> Ausência de contexto de Tenant **levanta erro**. Nunca devolve conjunto vazio.

Esta é a razão pela qual o isolamento é imposto na aplicação e não por Row Level Security.
RLS foi testada e devolve **0 linhas silenciosamente** quando o contexto está ausente
(R2), o que transforma um defeito em "nenhum dado encontrado" — falha silenciosa. FR-014
exige rejeição.

---

## `TheBand.Tenancy.Scope`

Estrutura opaca que carrega um `tenant_id` **já validado** contra existência e ativação.

```elixir
@type t :: %Scope{tenant_id: Ecto.UUID.t()}
```

Não é construtível fora de `Tenancy.scope/1` e `Tenancy.scope!/1`. Não há função que
aceite `tenant_id` cru em caminho de acesso a dados.

---

## `TheBand.Tenancy`

### `scope(tenant_id)`

```elixir
@spec scope(Ecto.UUID.t()) :: {:ok, Scope.t()} | {:error, :tenant_not_found | :tenant_inactive}
```

| Entrada | Retorno | Requisito |
|---|---|---|
| Tenant existente e ativo | `{:ok, %Scope{}}` | FR-013 |
| Tenant existente e inativo | `{:error, :tenant_inactive}` | FR-016 |
| Tenant inexistente | `{:error, :tenant_not_found}` | FR-016 |
| `nil` | `{:error, :tenant_not_found}` | FR-014 |
| valor que não é UUID | `{:error, :tenant_not_found}` | FR-014 |

**Nunca cria Tenant implicitamente** (FR-016).

### `scope!(tenant_id)`

Igual, mas levanta `TheBand.Tenancy.ScopeError` em vez de devolver tupla de erro.

### `register_tenant(attrs)`

```elixir
@spec register_tenant(map()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
```

| Entrada | Resultado | Requisito |
|---|---|---|
| `%{slug: "tenant-alpha", name: "Alpha"}` | `{:ok, tenant}` com `active: true` | FR-009 |
| `slug` duplicado | erro em `slug`, restrição `tenants_slug_index` | FR-010, SC-008 |
| `slug` fora de `^[a-z0-9-]{3,63}$` | erro em `slug`, restrição `slug_format` | FR-010, SC-008 |
| `slug` ausente | erro de campo obrigatório | FR-010 |
| `name` ausente | erro de campo obrigatório | FR-011 |
| `name` duplicado | `{:ok, tenant}` — unicidade **não** é exigida | FR-011 |

Ambas as restrições de `slug` foram verificadas no banco real (R8), não apenas na
aplicação.

### `rename_tenant(scope, name)`

```elixir
@spec rename_tenant(Scope.t(), String.t()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
```

Altera **apenas** `name`. Não aceita `slug` — a assinatura não o expõe, e a lista de
campos permitidos em alteração não o inclui. Tentativa de alterar `slug` por qualquer
caminho é rejeitada (FR-010, SC-008).

Recebe `Scope.t()`: renomear é operação escopada.

### `deactivate_tenant(tenant_id)` / `activate_tenant(tenant_id)`

```elixir
@spec deactivate_tenant(Ecto.UUID.t()) :: {:ok, Tenant.t()} | {:error, term()}
```

Recebem `tenant_id` cru, **não** `Scope.t()` — desativar um Tenant inativo por meio de um
escopo válido seria contraditório. São operações administrativas.

**Desativar preserva integralmente os dados** (FR-017): não remove, não anonimiza, altera
apenas `active`.

### `admin_fetch_tenant(tenant_id)`

```elixir
@spec admin_fetch_tenant(Ecto.UUID.t()) :: {:ok, Tenant.t()} | {:error, :not_found}
```

Único caminho de leitura para Tenant **inativo** (FR-017). Deliberadamente prefixada
`admin_` para que revisão e busca no código encontrem todo acesso fora de escopo.

---

## `TheBand.Audit`

Todas as funções escopadas recebem `Scope.t()` como **primeiro** argumento.

### `record_event(scope, attrs)`

```elixir
@spec record_event(Scope.t(), map()) :: {:ok, OperationalEvent.t()} | {:error, Ecto.Changeset.t()}
```

| Entrada | Resultado | Requisito |
|---|---|---|
| escopo válido + `%{type:, correlation_id:, occurred_at:}` | `{:ok, event}` com `tenant_id` do escopo | FR-018, FR-019 |
| `tenant_id` explícito nos atributos | **ignorado** — o do escopo prevalece | FR-019 |
| `metadata` com chave sensível (`token`, `secret`, `password`, `key`, `credential`, `authorization`) | erro em `metadata` | FR-030 |
| primeiro argumento não é `Scope.t()` | **levanta** `FunctionClauseError` | FR-014 |

### `list_events(scope, opts)` / `count_events(scope)`

```elixir
@spec list_events(Scope.t(), keyword()) :: [OperationalEvent.t()]
@spec count_events(Scope.t()) :: non_neg_integer()
```

| Cenário | Resultado | Requisito |
|---|---|---|
| dois Tenants com eventos, escopo do Tenant A | apenas eventos de A | FR-020, SC-003 |
| contagem no escopo de A | total **desconsidera** B integralmente | FR-020, SC-003 |
| escopo ausente | **levanta**, não devolve `[]` nem `0` | FR-014, SC-004 |

A distinção entre "levanta" e "devolve vazio" é o requisito, não detalhe de estilo.

### `admin_list_events(tenant_id, opts)`

Leitura fora de escopo, para Tenant inativo (FR-017). Prefixo `admin_` pelo mesmo motivo
acima.

---

## Contrato imposto por análise estática (SC-002)

Checagem customizada de Credo reprova a proposta de mudança quando encontra chamada direta
a `TheBand.Repo.<função>` fora da lista de módulos autorizados.

**Módulos autorizados**:

```text
TheBand.Tenancy.*
TheBand.Audit.*
TheBand.Repo.Migrations.*
Mix.Tasks.TheBand.*        (tarefas administrativas)
```

Qualquer outro módulo que chame `TheBand.Repo` diretamente reprova o PR. Um teste
acompanha a checagem, verificando a própria lista de autorizados — para que ampliá-la seja
uma mudança visível em revisão, não um efeito colateral.

---

## Contrato de teste de isolamento (SC-003, SC-004)

`test/integration/tenant_isolation_test.exs` deve cobrir, com dois Tenants reais e dados
em ambos:

| Operação no escopo de A | Esperado |
|---|---|
| listar | nenhum registro de B |
| contar | total sem os registros de B |
| alterar registro de B | rejeitado, nada modificado |
| remover registro de B | rejeitado, nada modificado |
| qualquer operação sem escopo | levanta |
| escopo de Tenant inativo | `{:error, :tenant_inactive}` |
| escopo de Tenant inexistente | `{:error, :tenant_not_found}` |
