# Phase 1 — Data Model: Fundação e governança da plataforma

**Feature**: 001 | **Data**: 2026-08-03 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

Duas tabelas de domínio próprio, mais as tabelas geridas pelo Oban. Restrições marcadas
como **verificadas** foram aplicadas e testadas em PostgreSQL 17.10 real — ver
[research.md](research.md) R8.

---

## `tenants`

Unidade de isolamento da instalação. **Não** é `eo.organization` (feature 005) — ver
`Terminologia canônica` na especificação e ADR-0003.

| Campo | Tipo | Restrição | Requisito |
|---|---|---|---|
| `id` | `binary_id` | chave primária | FR-009 |
| `slug` | `varchar(63)` | `NOT NULL`, único, `~ '^[a-z0-9-]{3,63}$'`, **imutável** | FR-010, SC-008 |
| `name` | `text` | `NOT NULL`, sem unicidade, alterável | FR-011 |
| `active` | `boolean` | `NOT NULL`, padrão `true` | FR-016, FR-017 |
| `inserted_at` | `timestamptz(6)` | `NOT NULL` | FR-009 |
| `updated_at` | `timestamptz(6)` | `NOT NULL` | — |

**Índices e restrições**

| Nome | Tipo | Verificado |
|---|---|---|
| `tenants_pkey` | chave primária | — |
| `tenants_slug_index` | único | **sim** — rejeitou `'tenant-alpha'` duplicado |
| `slug_format` | verificação `slug ~ '^[a-z0-9-]{3,63}$'` | **sim** — rejeitou `'AB'` |

**Imutabilidade de `slug`**: não há restrição declarativa simples sem gatilho. Imposta na
aplicação pela ausência de `slug` na lista de campos permitidos em alteração, coberta por
teste. Gatilho de banco registrado como opção se a garantia de aplicação se mostrar
insuficiente (R8).

**Transições de estado**

```text
     register_tenant
            ↓
      ┌──────────┐  deactivate_tenant  ┌────────────┐
      │  active  │ ──────────────────► │  inactive  │
      │  = true  │ ◄────────────────── │  = false   │
      └──────────┘   activate_tenant   └────────────┘
```

| Estado | Acesso comum escopado | Leitura administrativa | Trabalho assíncrono |
|---|---|---|---|
| `active` | permitido | permitido | executa |
| `inactive` | **rejeitado** (`{:error, :tenant_inactive}`) | permitido | **cancelado sem nova tentativa** |
| inexistente | **rejeitado** (`{:error, :tenant_not_found}`) | `{:error, :not_found}` | cancelado sem nova tentativa |

Desativar **não** remove, não anonimiza e não altera dado algum além de `active` (FR-017).
Reativar restaura o acesso comum, mas **não** reexecuta trabalho que falhou por Tenant
inativo (edge case registrado na especificação).

---

## `operational_events`

Fato sobre a execução da própria plataforma. Entidade tenant-scoped que torna FR-012 e
SC-003 verificáveis — sem ela, o requisito de pertencimento a Tenant não teria sujeito,
porque `tenants` não pertence a si mesma.

**Não** é `spo.performed_activity` nem qualquer evento do domínio analisado.

| Campo | Tipo | Restrição | Requisito |
|---|---|---|---|
| `id` | `binary_id` | chave primária | FR-018 |
| `tenant_id` | `binary_id` | `NOT NULL`, chave estrangeira → `tenants(id)` `ON DELETE RESTRICT` | FR-012, FR-017 |
| `type` | `varchar(100)` | `NOT NULL` | FR-018 |
| `correlation_id` | `varchar(64)` | `NOT NULL` | FR-018, FR-029 |
| `occurred_at` | `timestamptz(6)` | `NOT NULL` | FR-018 |
| `metadata` | `jsonb` | `NOT NULL`, padrão `'{}'`, sem conteúdo sensível | FR-018, FR-030 |

**Índices**

| Nome | Colunas | Motivo |
|---|---|---|
| `operational_events_pkey` | `id` | — |
| `operational_events_tenant_id_occurred_at_index` | `(tenant_id, occurred_at)` | toda consulta é escopada por Tenant e ordenada por tempo |

**`ON DELETE RESTRICT` é deliberado**: impede que remover um Tenant apague seu histórico
em cascata. Combinado com FR-017 (desativação preserva dados), garante que histórico
operacional não desapareça por acidente.

**Validação de `metadata`**: chaves cujo nome corresponda a padrão sensível
(`token`, `secret`, `password`, `key`, `credential`, `authorization`) são rejeitadas na
escrita, satisfazendo FR-030 na origem em vez de mascarar na saída.

---

## `oban_jobs` e tabelas auxiliares

Geridas pela migração do Oban (`Oban.Migration.up(version: 14)`). A v12 indicada na
pesquisa original não satisfaz `verify_migrated!/1` com a árvore de supervisão real — ver a
correção de R1 em [research.md](research.md).
Não são modeladas por esta feature.

Contrato de uso relevante ao modelo de dados:

| Campo do Oban | Uso nesta feature | Requisito |
|---|---|---|
| `args` | **deve** conter `"tenant_id"` | FR-022 |
| `state` | `cancelled` para Tenant ausente, inexistente ou inativo | FR-023, FR-024, SC-005, SC-006 |
| `attempt` | `1` nos casos cancelados — sem nova tentativa | FR-024 |
| `errors` | motivo persistido e consultável | FR-027 |
| `unique` | idempotência de enfileiramento | FR-026, SC-007 |

**Verificado em R6/R7**: `{:cancel, motivo}` produz `state = cancelled`, `attempt = 1`,
motivo em `errors`, sem retentativa. Unicidade devolveu a mesma id com `conflict?: true`.

**Nota semântica**: `oban_jobs` é registro operacional de execução da plataforma, não
`spo.performed_activity`.

---

## Relacionamentos

```text
tenants 1 ──── N operational_events        (tenant_id, ON DELETE RESTRICT)
tenants 1 ──── N oban_jobs                 (por convenção em args["tenant_id"],
                                            sem chave estrangeira — tabela é do Oban)
```

A ausência de chave estrangeira entre `oban_jobs` e `tenants` é consciente: a tabela é
gerida por biblioteca externa e alterar seu esquema criaria acoplamento com a migração do
Oban. A garantia vem da validação no trabalhador (FR-023, FR-024), verificada por teste.

---

## Regras que valem para toda tabela tenant-scoped futura

Padrão a ser seguido por todas as features seguintes, inclusive as ontológicas:

1. Coluna `tenant_id` `binary_id` `NOT NULL`, chave estrangeira → `tenants(id)`.
2. `ON DELETE RESTRICT`, nunca `CASCADE` — histórico não desaparece por remoção de Tenant.
3. Todo índice de consulta começa por `tenant_id`.
4. Acesso apenas via `Scope.t()`; ausência de escopo levanta erro, não devolve vazio.
5. A tabela `tenants` é a única exceção: não tem `tenant_id`.

**Importante para as features 005 e 006**: `eo_organizations`, `eo_teams`, `eo_people` e
`spo_projects` seguirão estas regras e **também** terão `tenant_id`. Isso não é
redundância — `tenant_id` diz a qual instalação a linha pertence; a identidade da
organização de domínio é outra coisa. Um Tenant contém várias organizações.
