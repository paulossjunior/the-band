# Quickstart — Validação da feature 001

**Feature**: 001 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

Roteiro de validação executável. Cada seção prova um ou mais critérios de sucesso. Este
documento é um guia de execução e verificação — o código de implementação pertence a
`tasks.md` e à fase de implementação.

**Alvo de SC-001**: da clonagem à resposta saudável em **até 15 minutos**, sem consultar
outra pessoa.

---

## Pré-requisitos

| Item | Versão verificada | Como conferir |
|---|---|---|
| Elixir | 1.20.2 | `elixir --version` |
| Erlang/OTP | 29 (erts-17.0.4) | `elixir --version` |
| Docker | daemon ativo | `docker info` |
| Hex e rebar3 | — | `mix local.hex --force && mix local.rebar --force` |

---

## 1. Subir o ambiente (SC-001)

```bash
git clone https://github.com/paulossjunior/the-band.git
cd the-band
cp .env.example .env        # preencher os valores locais
docker compose up -d        # apenas PostgreSQL
mix deps.get
mix ecto.setup              # cria, migra e semeia
mix phx.server
```

**Esperado**: servidor atendendo, sem erro no terminal.

### Variável obrigatória ausente falha nomeando a variável (FR-007)

Verificado com `MIX_ENV=prod`, **não** em desenvolvimento:

```bash
MIX_ENV=prod env -u DATABASE_URL mix run -e ''
```

**Esperado**: falha imediata nomeando `DATABASE_URL`, sem iniciar com valor padrão.

```text
** (TheBand.Config.MissingEnvError) variável de ambiente DATABASE_URL está ausente.
   Formato esperado: ecto://USUARIO:SENHA@HOST/BASE
```

**Por que em produção e não em desenvolvimento.** Uma versão anterior deste roteiro testava em
desenvolvimento. Exigir a variável ali adicionaria atrito à inicialização local — que é
exatamente o que SC-001 mede — sem proteger nada: o padrão de desenvolvimento é público por
construção e não alcança produção. O modo de falha que FR-007 existe para impedir é
**produção subir com configuração que ninguém escolheu**, e é isso que passou a ser testado.

Em desenvolvimento e teste, `DATABASE_URL` e `SECRET_KEY_BASE` têm padrão declarado em
`config/dev.exs` e `config/test.exs`.

### Segredo de operação ausente recusa, nunca libera (FR-003)

```bash
env -u THE_BAND_OPERATOR_SECRET mix phx.server
# noutro terminal:
curl -i -H "Authorization: Bearer qualquer-coisa" http://localhost:4000/health/detail
```

**Esperado**: `401` com corpo `{"error":"unauthorized"}`. O caminho **público** segue
respondendo `200`.

---

## 2. Verificação de saúde (FR-001 a FR-004, SC-009)

### Público — apenas vivacidade

```bash
curl -i http://localhost:4000/health
```

**Esperado**: `200`, corpo **exatamente** `{"status":"alive"}`, cabeçalho
`X-Correlation-Id` presente.

**Verificar também o que NÃO aparece**: nenhum nome de componente, nenhum estado, nenhuma
versão, nenhum host. Ver [contracts/health.md](contracts/health.md).

### Detalhado sem credencial

```bash
curl -i http://localhost:4000/health/detail
```

**Esperado**: `401`, corpo `{"error":"unauthorized"}`. Nenhum estado de componente.

### Detalhado com credencial

```bash
curl -i -H "Authorization: Bearer $THE_BAND_OPERATOR_SECRET" \
  http://localhost:4000/health/detail
```

**Esperado**: `200`, `components` com `database` e `background_jobs`.

### Armazenamento indisponível

```bash
docker compose stop postgres
curl -i http://localhost:4000/health                     # deve seguir 200 alive
curl -i -H "Authorization: Bearer $THE_BAND_OPERATOR_SECRET" \
  http://localhost:4000/health/detail                    # deve dar 503, database down
docker compose start postgres
```

**Esperado**: público continua `200` (não consulta dependência); detalhado devolve `503`
identificando `database: "down"`, sem expor credencial nem rastro de pilha.

---

## 3. Migrações reversíveis (SC-015)

```bash
mix ecto.migrate
mix ecto.rollback --all
mix ecto.migrate
mix ecto.migrate            # segunda aplicação: sem efeito, sem erro
```

**Esperado**: as quatro operações concluem sem erro.

---

## 4. Isolamento entre Tenants (SC-002, SC-003, SC-004, SC-008)

```bash
mix test --only integration test/integration/tenant_isolation_test.exs
```

Exploração manual em `iex -S mix`:

```elixir
{:ok, a} = TheBand.Tenancy.register_tenant(%{slug: "tenant-alpha", name: "Alpha"})
{:ok, b} = TheBand.Tenancy.register_tenant(%{slug: "tenant-beta",  name: "Beta"})

{:ok, sa} = TheBand.Tenancy.scope(a.id)
{:ok, sb} = TheBand.Tenancy.scope(b.id)

TheBand.Audit.record_event(sa, %{type: "probe", correlation_id: "c1", occurred_at: DateTime.utc_now()})
TheBand.Audit.count_events(sa)   # 1
TheBand.Audit.count_events(sb)   # 0  ← isolamento

TheBand.Audit.count_events(nil)  # LEVANTA — não devolve 0
```

**A última linha é o ponto central**: ausência de escopo levanta. Devolver `0` seria falha
silenciosa. É por isso que Row Level Security foi descartada nesta feature —
[research.md](research.md) R2.

### Restrições de identidade (SC-008)

```elixir
TheBand.Tenancy.register_tenant(%{slug: "tenant-alpha", name: "Outro"})  # erro: slug duplicado
TheBand.Tenancy.register_tenant(%{slug: "AB",           name: "Curto"})  # erro: slug_format
TheBand.Tenancy.register_tenant(%{slug: "ok-slug",      name: "Alpha"})  # OK: name repete
```

---

## 5. Trabalho assíncrono (SC-005, SC-006, SC-007)

```bash
mix test --only integration test/integration/idempotency_test.exs
mix test test/the_band/jobs/tenant_health_check_test.exs
```

Exploração manual:

```elixir
alias TheBand.Jobs.TenantHealthCheck
import Ecto.Query

{:ok, _} = Oban.insert(TenantHealthCheck.new(%{"tenant_id" => a.id}))   # → completed
{:ok, _} = Oban.insert(TenantHealthCheck.new(%{}))                      # → cancelled
{:ok, _} = TheBand.Tenancy.deactivate_tenant(b.id)
{:ok, _} = Oban.insert(TenantHealthCheck.new(%{"tenant_id" => b.id}))   # → cancelled

TheBand.Repo.all(from j in "oban_jobs", select: {j.id, j.state, j.attempt})
```

**Esperado**: `attempt = 1` em **todos** os cancelados — sem nova tentativa. Ver
[contracts/worker.md](contracts/worker.md).

### Dados de Tenant desativado permanecem legíveis (FR-017)

```elixir
TheBand.Tenancy.scope(b.id)              # {:error, :tenant_inactive}
TheBand.Tenancy.admin_fetch_tenant(b.id) # {:ok, tenant}  ← preservado
TheBand.Audit.admin_list_events(b.id)    # eventos preservados
```

---

## 6. Portões de qualidade (SC-010, SC-012)

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
mix dialyzer
mix test
```

**Esperado**: os cinco passam. Notas de execução medida ([research.md](research.md)):

- `mix credo --strict` **só** passa com `.credo.exs` presente — sem ele, o código gerado
  pelo Phoenix produz 3 achados de `Design.AliasUsage` e o comando sai com código 2 (R4).
- `mix dialyzer` leva ~1m40s na primeira execução (construção do PLT) e ~3s depois. O CI
  **deve** cachear o PLT (R3).

### Provar que cada portão reprova (SC-010)

Introduzir uma violação deliberada por vez, abrir proposta de mudança, confirmar reprovação
e reverter:

| Violação | Portão que deve reprovar |
|---|---|
| linha fora do padrão de formatação | `mix format --check-formatted` |
| variável não usada | `mix compile --warnings-as-errors` |
| função com complexidade acima do limite | `mix credo --strict` |
| especificação de tipo incorreta | `mix dialyzer` |
| asserção invertida em teste | `mix test` |
| credencial falsa versionada | fluxo de segurança |

---

## 7. Proteção da linha principal (SC-011, SC-011a) — **exige execução, não leitura de configuração**

Os dois únicos critérios que a especificação e o plano **não** puderam provar. A
configuração está confirmada no servidor, mas o comportamento precisa ser observado.

### 7.1 Escrita direta é rejeitada (SC-011)

```bash
git switch main
git commit --allow-empty -m "probe: verificar protecao da linha principal"
git push origin main          # DEVE ser rejeitado pelo servidor
git reset --hard origin/main  # descartar o commit local de teste
```

**Esperado**: o envio é rejeitado, inclusive para quem administra o repositório. Registrar
a saída de erro como evidência no PR.

### 7.2 Incorporação com verificação pendente é bloqueada (SC-011a)

Este é o **substituto mecânico da aprovação humana** sob a cláusula `Mantenedor único` da
constituição. Sem ele, a cláusula fica sem lastro e a proteção se reduz a exigir PR.

```bash
gh api repos/paulossjunior/the-band/rulesets/20343491 \
  --jq '[.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context]'
```

**Esperado**: todas as verificações de `ci.yml` e `security.yml` listadas.

Depois, com uma verificação deliberadamente reprovada, e em seguida com uma pendente,
tentar incorporar de fato:

```bash
gh pr merge <numero> --squash    # DEVE ser recusado nos dois casos
```

**Esperado**: recusa do servidor nos dois casos. Registrar as duas saídas como evidência.

### 7.3 Nenhum ator de exceção (FR-036)

```bash
gh api repos/paulossjunior/the-band/rulesets/20343491 --jq '.bypass_actors'
```

**Esperado**: `[]`. Qualquer ator de exceção esvazia SC-011 justamente para quem mais
escreve.

### 7.4 Revisão humana — apenas com mais de uma pessoa mantenedora

```bash
gh api repos/paulossjunior/the-band/collaborators --jq 'length'
```

Se o resultado for maior que 1, a cláusula `Mantenedor único` deixa de valer por reversão
automática: confirmar que a incorporação fica bloqueada sem aprovação de outra pessoa
(FR-036a). Se for 1, este passo não se aplica e 7.2 é o que sustenta a verificação
independente.

---

## 8. Ausência de segredos (SC-013)

```bash
mix test --only integration            # inclui verificação de .env.example
grep -rniE 'ghp_|gho_|github_pat_|AKIA|BEGIN [A-Z ]*PRIVATE KEY' --exclude-dir=.git .
```

**Esperado**: nenhum resultado. `.env.example` presente, com todas as variáveis
obrigatórias e nenhum valor real.

---

## 9. Registros de decisão (SC-014)

```bash
ls docs/adr/
```

**Esperado**: `0001-monolito-modular-multitenant.md`,
`0002-estrategia-de-isolamento-por-tenant.md`, `0003-tenant-nao-e-organizacao.md`.

**Teste de SC-014**: pedir a alguém de fora do projeto para, em até 10 minutos e usando só
o repositório, responder:

1. Por que sistema único modular em vez de vários serviços?
2. Por que não uma base de dados por Tenant?
3. Por que Tenant e Organização são entidades diferentes?

ADR-0002 deve incluir a evidência de que Row Level Security devolve conjunto vazio em vez
de rejeitar — é o que justifica a escolha do mecanismo.

---

## Matriz de cobertura

| Critério | Seção |
|---|---|
| SC-001 | 1 |
| SC-002, SC-003, SC-004 | 4 |
| SC-005, SC-006, SC-007 | 5 |
| SC-008 | 4 |
| SC-009 | 2 |
| SC-010, SC-012 | 6 |
| SC-011 | **7.1** |
| SC-011a | **7.2** |
| SC-013 | 8 |
| SC-014 | 9 |
| SC-015 | 3 |
| SC-016 | 5 |

Todos os 17 critérios têm caminho de verificação executável.
