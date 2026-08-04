# Contract — Trabalho assíncrono

**Feature**: 001 | **Requisitos**: FR-021 a FR-027, SC-005 a SC-007 | **Decisão**: [research.md](../research.md) R6, R7

Contrato que **todo** trabalhador do The Band deve cumprir, agora e nas features seguintes.
`TheBand.Jobs.TenantHealthCheck` é a implementação de referência.

---

## Argumentos obrigatórios

```json
{ "tenant_id": "<uuid>" }
```

`tenant_id` é obrigatório em **todo** trabalhador (FR-022). Argumentos adicionais são
específicos de cada trabalhador.

---

## Situações finais possíveis

| Situação | Quando | Retorno do trabalhador | Nova tentativa | Requisito |
|---|---|---|---|---|
| `completed` | Tenant ativo e trabalho concluído | `:ok` | — | FR-021 |
| `cancelled` | `tenant_id` ausente dos argumentos | `{:cancel, "tenant_id ausente"}` | **não** | FR-023, SC-005 |
| `cancelled` | Tenant inexistente | `{:cancel, "tenant inexistente: <id>"}` | **não** | FR-023 |
| `cancelled` | Tenant inativo | `{:cancel, "tenant inativo: <id>"}` | **não** | FR-024, SC-006 |
| `retryable` → `discarded` | falha transitória | `{:error, motivo}` | sim, até `max_attempts` | FR-025 |

### Por que `{:cancel, motivo}` e não `{:error, motivo}`

**Verificado por execução** (R6): `{:cancel, motivo}` produz `state = cancelled`,
`attempt = 1`, motivo persistido em `errors`, e **nenhuma** nova tentativa.

`{:error, motivo}` faria o Oban reprocessar até `max_attempts`. Para Tenant inativo isso
violaria FR-024 diretamente — retentar não vai fazer o Tenant voltar a estar ativo, e a
fila acumularia trabalho condenado.

Saída real da verificação:

```text
tenant ativo         state=completed  attempt=1
sem tenant_id        state=cancelled  attempt=1  {:cancel, "tenant_id ausente"}
tenant inativo       state=cancelled  attempt=1  {:cancel, "tenant inativo: <id>"}
tenant inexistente   state=cancelled  attempt=1  {:cancel, "tenant inexistente: <id>"}
```

---

## Ordem de validação obrigatória

```text
1. tenant_id presente nos argumentos?     não → {:cancel, "tenant_id ausente"}
2. Tenancy.scope(tenant_id)               {:error, :tenant_not_found} → {:cancel, ...}
                                          {:error, :tenant_inactive}  → {:cancel, ...}
3. trabalho de fato, com o escopo validado
```

O passo 2 usa `Tenancy.scope/1`, a mesma função de todo acesso a dados. O trabalhador
**não** consulta a tabela `tenants` por conta própria — isso duplicaria a regra de
validação em dois lugares.

---

## Idempotência (FR-026, SC-007)

Duas camadas, ambas necessárias.

### Camada 1 — enfileiramento

```elixir
Worker.new(args, unique: [period: <segundos>, fields: [:worker, :args]])
```

**Verificado** (R7): a segunda inserção dos mesmos argumentos devolveu o **mesmo** registro
com `conflict?: true`, sem criar segundo trabalho.

```text
unique job: mesma id nas duas insercoes? true (id1=5 id2=5)
conflito marcado? true
```

### Camada 2 — efeito

Unicidade do Oban **não** cobre idempotência de efeito. Se um trabalho executar duas vezes
por reinício de nó, a proteção precisa estar na escrita: chave natural com
`ON CONFLICT DO NOTHING` ou equivalente.

**Limitação registrada explicitamente**: um trabalhador que dependa apenas da camada 1 não
é idempotente. SC-007 é verificado por lote de pelo menos 10 execuções comparando o estado
final, não pela presença da opção `unique`.

---

## Observabilidade obrigatória (FR-027, FR-028, SC-016)

Todo trabalhador emite, via telemetria:

```text
[:the_band, :job, :start]
[:the_band, :job, :stop]        duração, situação
[:the_band, :job, :exception]   duração, código de erro
```

Metadados obrigatórios em todos: `tenant_id`, `correlation_id`, `job_id`, `attempt`.

`correlation_id` vem dos argumentos quando presente; caso contrário é gerado no início da
execução e registrado, para que a cadeia seja reconstituível (FR-029).

**Proibido** registrar credencial, token ou conteúdo sensível completo de payload
(FR-030).

---

## Contrato de teste

`test/the_band/jobs/tenant_health_check_test.exs` deve cobrir os quatro casos verificados
em R6:

| Caso | `state` esperado | `attempt` esperado | Motivo em `errors` |
|---|---|---|---|
| Tenant ativo | `completed` | 1 | ausente |
| Sem `tenant_id` | `cancelled` | 1 | menciona `tenant_id ausente` |
| Tenant inativo | `cancelled` | 1 | menciona `tenant inativo` e a id |
| Tenant inexistente | `cancelled` | 1 | menciona `tenant inexistente` e a id |

`test/integration/idempotency_test.exs` deve executar o mesmo trabalho 10 vezes com a mesma
entrada e afirmar estado final idêntico ao de uma única execução (SC-007).
