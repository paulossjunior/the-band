# Phase 0 — Research: Fundação e governança da plataforma

**Feature**: 001 | **Data**: 2026-08-03 | **Spec**: [spec.md](spec.md)

Toda decisão abaixo foi verificada por execução em um projeto descartável
(`mix phx.new probe`) no ambiente real desta máquina, não por leitura de documentação.
As saídas citadas são reais.

**Ambiente de verificação**: Elixir 1.20.2, Erlang/OTP 29 (erts-17.0.4), PostgreSQL
17.10 em contêiner, macOS arm64.

---

## R1 — Versões da stack compatíveis com Elixir 1.20.2 / OTP 29

**Decisão**: adotar as versões abaixo, todas resolvidas e compiladas com sucesso no
ambiente real.

| Pacote | Versão | Observação |
|---|---|---|
| `phoenix` | 1.8.9 | `mix phx.new` gera e compila sem erro |
| `phoenix_live_view` | 1.2.8 | |
| `ecto` / `ecto_sql` | 3.14.1 / 3.14.0 | |
| `postgrex` | 0.22.3 | resolvido estável; a última publicada é `1.0.0-rc.1` (pre-release) e **não** deve ser fixada |
| `oban` | 2.23.1 | migração v12 aplicada com sucesso |
| `req` | 0.7.2 | traz `finch`, `mint`, `nimble_options`, `nimble_pool` |
| `credo` | 1.7.19 | ver R4 |
| `dialyxir` | 1.4.7 | ver R3 |
| `mox` | 1.2.0 | traz `nimble_ownership` |
| `jason` | 1.4.5 | resolvido estável; a última publicada é `1.5.0-alpha.2` e **não** deve ser fixada |
| `bandit` | 1.12.4 | servidor padrão do Phoenix 1.8 |
| `telemetry` / `telemetry_metrics` / `telemetry_poller` | 1.4.2 / 1.1.0 / 1.3.0 | |

**Rationale**: risco declarado na especificação era compatibilidade com Elixir e OTP
recentes. Verificação empírica: `mix deps.get` resolveu tudo e
`mix compile --warnings-as-errors` gerou todas as aplicações sem falhar.

**Achado sobre o gerador**: `mix phx.new .` em diretório **não vazio** pergunta
`Are you sure you want to continue? [Yn]` e, sem entrada disponível, **aborta** com
`** (Mix) Please select another directory for installation.` Verificado. A forma que
funciona é `echo Y | mix phx.new . …`, também verificada: preserva `.git`, `README.md`,
`CLAUDE.md` e `specs/`. O gerador 1.8.9 também cria `AGENTS.md`, que não estava previsto.

**Achado relevante**: `oban 2.23.1` emite um alerta próprio ao compilar em Elixir 1.20:

```text
warning: this clause of defp expected_error?/1 is never used
  lib/oban/repo.ex:253:8: Oban.Repo.expected_error?/1
```

O alerta é da dependência, não do projeto. `--warnings-as-errors` aplica-se à
compilação do projeto, e a compilação de dependências não é afetada — a aplicação
`oban` foi gerada normalmente. **Consequência para o plano**: não usar
`--warnings-as-errors` em `mix deps.compile`, apenas na compilação do projeto.

**Alternativas consideradas**: fixar `postgrex 1.0.0-rc.1` e `jason 1.5.0-alpha.2` por
serem as versões mais recentes publicadas — descartado, são pre-release e a constituição
exige justificar biblioteca; adotar pre-release na fundação sem necessidade é risco sem
retorno.

---

## R2 — Mecanismo de isolamento entre Tenants

**Decisão**: **escopo em camada de aplicação como mecanismo único e obrigatório na
feature 001.** Row Level Security do PostgreSQL **não** entra nesta feature; fica
registrada como feature futura com ADR próprio, com a evidência abaixo já levantada.

**Rationale — a evidência decide**. RLS foi testado de ponta a ponta com papel não-dono,
`FORCE ROW LEVEL SECURITY` e política sobre `current_setting('app.tenant_id', true)`:

| Cenário testado | Resultado real |
|---|---|
| `app.tenant_id` definido para o Tenant A | 3 de 8 linhas — isolamento correto |
| **`app.tenant_id` ausente** | **0 linhas, silenciosamente. Nenhum erro.** |
| `INSERT` apontando para outro Tenant | rejeitado, `insufficient_privilege` |
| `SET LOCAL` após o fim da transação | `nil` — não vaza entre checkouts do pool |

O segundo caso é decisivo. **FR-014 exige rejeitar o acesso quando o contexto de Tenant
está ausente.** RLS não rejeita: devolve conjunto vazio. Um defeito que perde o contexto
de Tenant produziria "nenhum dado encontrado" em vez de erro — falha silenciosa, mais
difícil de detectar do que a ausência de proteção, porque parece funcionamento normal.

Além disso, RLS exige, para funcionar de fato:

- papel de banco não-dono para a aplicação, separado do papel de migração (o dono
  contorna RLS a menos que `FORCE` esteja ativo);
- `SET LOCAL` dentro de transação em **toda** leitura, o que obriga a envolver todo
  caminho de leitura em transação — contamina todo o acesso a dados e adiciona custo;
- coordenação com as tabelas do Oban, que são acessadas pela própria biblioteca.

Isso é complexidade estrutural que não satisfaz o requisito que motivaria adotá-la.

**Decisão detalhada do mecanismo adotado**:

- módulo único `TheBand.Tenancy` expõe um escopo explícito (`Tenancy.Scope`) que carrega
  o `tenant_id` validado;
- todo acesso a dados recebe o escopo como primeiro argumento e aplica o filtro por
  `tenant_id` na consulta;
- ausência de escopo **levanta erro**, não devolve vazio — satisfaz FR-014 diretamente;
- `tenant_id` é `NOT NULL` com chave estrangeira `ON DELETE RESTRICT` em toda tabela
  tenant-scoped, garantindo integridade no banco independentemente da aplicação.

**Risco residual aceito**: sem RLS, um acesso que ignore a abstração não é barrado pelo
banco. Mitigação: SC-002 exige verificação automática de que 100% dos acessos passam pela
abstração — ver R5.

**Alternativas descartadas**:

- RLS como mecanismo único: não satisfaz FR-014 (evidência acima).
- RLS somada ao escopo de aplicação, ambas na 001: dobra os mecanismos na fundação, exige
  papéis de banco distintos e transação em toda leitura, sem satisfazer nenhum requisito
  que o escopo de aplicação já não satisfaça. Adiar preserva a opção sem custo.
- Prefixo de schema por Tenant no Ecto (`prefix:`): equivale a um schema por Tenant,
  contraria a estratégia de tabelas compartilhadas exigida pela constituição, e multiplica
  migrações por Tenant.
- Banco por Tenant: proibido explicitamente pela constituição.

---

## R3 — Dialyzer em OTP 29

**Decisão**: `dialyxir 1.4.7`, PLT versionado em cache de CI, arquivo
`.dialyzer_ignore.exs` presente desde o início.

**Rationale**: verificado por execução. Construção do PLT e análise completa:

```text
PLT: done in 0m58.59s
Análise: done in 0m2.91s
Total errors: 0, Skipped: 0, Unnecessary Skips: 0
done (passed successfully)
tempo de parede total: 1m40s
```

Nenhum problema em OTP 29. O nome do PLT gerado inclui a versão
(`dialyxir_erlang-29.0.4_elixir-1.20.2_deps-dev.plt`), portanto a chave de cache de CI
deve incluir versão de OTP, de Elixir e o hash de `mix.lock`.

**Achado**: dialyxir avisa `No :ignore_warnings opt specified in mix.exs and default does
not exist.` Criar `.dialyzer_ignore.exs` e declará-lo em `mix.exs` desde a primeira
entrega, mesmo vazio, para o aviso não poluir a saída.

**Consequência para SC-012** (verificações em até 10 minutos): 1m40s de Dialyzer sem
cache é aceitável, mas o PLT **deve** ser cacheado no CI, senão consome sozinho um sexto
do orçamento em toda execução.

---

## R4 — `mix credo --strict` no código gerado pelo Phoenix

**Decisão**: manter `--strict` como exigido pela constituição e adicionar `.credo.exs`
que ajusta explicitamente `Credo.Check.Design.AliasUsage`, com justificativa registrada.

**Rationale**: verificado por execução sobre o projeto gerado por `mix phx.new`:

```text
mix credo --strict  → exit code 2
mix credo           → exit code 0
```

Os três achados em modo estrito são todos `Design.AliasUsage` em código **gerado pelo
Phoenix**, não escrito por nós:

```text
lib/probe_web/components/core_components.ex:210:9
test/support/data_case.ex:39:11
test/support/data_case.ex:40:19
```

Ou seja: adotar `mix credo --strict` sem configuração faz o CI reprovar a primeira
entrega por causa do gerador, não por causa do nosso código. Isso não é aceitável e não
justifica abandonar `--strict`.

**Decisão detalhada**: `.credo.exs` deve elevar o limite de `Design.AliasUsage`
(`if_nested_deeper_than`) ou excluir os arquivos gerados, e a escolha entre as duas
precisa ser registrada como comentário no próprio arquivo. Nenhuma outra checagem estrita
deve ser afrouxada nesta feature.

**Alternativas descartadas**:

- Usar `mix credo` sem `--strict`: contraria diretamente os quality gates da
  constituição.
- Editar o código gerado pelo Phoenix para satisfazer a checagem: cria divergência do
  gerador que reaparece em toda atualização do Phoenix.

---

## R5 — Como provar que 100% dos acessos passam pela abstração de escopo (SC-002)

**Decisão**: checagem customizada de Credo em **`credo_checks/`** na raiz, incluída em
`elixirc_paths` apenas para `:dev` e `:test`, somada a uma guarda contra no-op silencioso.

**Rationale**: SC-002 exige verificação automática, não revisão humana. Em Elixir não é
possível tornar um módulo privado, então a restrição precisa ser imposta por análise
estática. Credo já está na stack e permite checagem customizada, o que evita introduzir
ferramenta nova — a constituição proíbe tecnologia nova quando a atual basta.

Módulos autorizados a chamar `TheBand.Repo` diretamente: `TheBand.Tenancy`, `TheBand.Audit`,
as migrações, e as tarefas administrativas explicitamente marcadas. Qualquer outro módulo
deve receber o escopo.

### Onde a checagem NÃO pode ficar — verificado por execução

**`test/credo/checks/`**: não funciona. O projeto gerado tem
`elixirc_paths(:test), do: ["lib", "test/support"]` e `elixirc_paths(_), do: ["lib"]`.
`test/credo/` não é compilado em **nenhum** ambiente. Verificado: o módulo não carrega nem
em `:dev` nem em `:test`.

**`lib/`**: quebraria a compilação de produção. `use Credo.Check` exige a dependência
`credo`, declarada `only: [:dev, :test]`. Um módulo em `lib/` que a use falha em
`MIX_ENV=prod`.

### A solução verificada

```elixir
defp elixirc_paths(:test), do: ["lib", "test/support", "credo_checks"]
defp elixirc_paths(:dev),  do: ["lib", "credo_checks"]
defp elixirc_paths(_),     do: ["lib"]
```

Resultados reais:

| Verificação | Resultado |
|---|---|
| `mix credo --strict` com violação em `lib/` | detecta e sai com **código 16** |
| `MIX_ENV=prod mix compile` | compila 14 arquivos em vez de 15; **nenhum** módulo de checagem no build de produção |

### Achado grave: no-op silencioso

**`mix credo` não compila o projeto antes de rodar.** Se o módulo da checagem não estiver
compilado, o Credo apenas imprime um aviso e **sai com código 0**:

```text
** (config) Ignoring an undefined check: TheBand.Credo.Check.NoDirectRepoAccess
Analysis took 0.01 seconds (0.00s running 0 checks on 15 files)
exit=0
```

Ou seja: em `_build` limpo, ou se o nome do módulo for renomeado sem atualizar `.credo.exs`,
**SC-002 deixa de ser verificado e nada falha**. Isso é pior que a ausência da checagem,
porque o portão passa e parece cumprido.

**Mitigação obrigatória, em duas camadas**:

1. `mix compile` **antes** de `mix credo` na ordem dos portões — já é a ordem exigida;
2. reprovar explicitamente quando o Credo emitir `Ignoring an undefined check`, e teste que
   afirma que o módulo da checagem está carregável. Sem isso, a camada 1 protege apenas
   quem não limpou o `_build`.

**Alternativas descartadas**:

- `mix xref` com verificação em script: funciona, mas produz saída difícil de acionar e
  não se integra ao gate de análise estática já existente.
- Teste que faz busca textual no código: frágil a formatação e a apelidamento.
- Confiar em revisão humana: viola SC-002, e sob a cláusula `Mantenedor único` não existe
  revisão humana a que recorrer.

---

## R6 — Rejeição e não-repetição de trabalho assíncrono (FR-023, FR-024, SC-005, SC-006)

**Decisão**: usar o retorno `{:cancel, motivo}` do `Oban.Worker`.

**Rationale**: verificado por execução com quatro unidades de trabalho reais:

| Caso | `state` | `attempt` | Motivo registrado |
|---|---|---|---|
| Tenant ativo | `completed` | 1 | — |
| Sem `tenant_id` | `cancelled` | 1 | `{:cancel, "tenant_id ausente"}` |
| Tenant inativo | `cancelled` | 1 | `{:cancel, "tenant inativo: <id>"}` |
| Tenant inexistente | `cancelled` | 1 | `{:cancel, "tenant inexistente: <id>"}` |

`{:cancel, motivo}` produz exatamente o comportamento exigido: falha definitiva,
`attempt = 1`, **sem nova tentativa**, e o motivo fica persistido na coluna `errors`,
consultável — satisfaz FR-023, FR-024, FR-027, SC-005 e SC-006 sem código próprio de
controle de tentativa.

**Contraste importante**: retornar `{:error, motivo}` faria o Oban reprocessar até
`max_attempts`, o que violaria FR-024 (Tenant inativo não deve ser retentado).

---

## R7 — Idempotência de trabalho assíncrono (FR-026, SC-007)

**Decisão**: unicidade nativa do Oban (`unique: [period: ..., fields: [:worker, :args]]`)
como mecanismo de idempotência de enfileiramento, somada a escrita idempotente no banco
por chave natural.

**Rationale**: verificado por execução. Duas inserções do mesmo trabalho com os mesmos
argumentos:

```text
unique job: mesma id nas duas insercoes? true (id1=5 id2=5)
conflito marcado? true
```

A segunda inserção devolveu o mesmo registro com `conflict?: true` em vez de criar um
segundo trabalho. Isso cobre a idempotência de **enfileiramento**.

**Limitação registrada**: unicidade do Oban não cobre idempotência de **efeito**. Se um
trabalho executar duas vezes por reinício de nó, a proteção precisa estar na escrita.
Portanto toda escrita da fundação usa chave natural com `ON CONFLICT DO NOTHING` ou
equivalente, e SC-007 é verificado por lote de pelo menos 10 execuções comparando estado
final.

---

## R8 — Restrições de identidade do Tenant no banco (FR-010, FR-011, SC-008)

**Decisão**: índice único em `slug`, restrição de verificação com expressão regular no
próprio banco, e imutabilidade imposta na camada de aplicação.

**Rationale**: verificado por execução com as restrições reais aplicadas:

| Tentativa | Resultado real |
|---|---|
| `slug = 'AB'` (curto e com maiúscula) | rejeitado pela restrição `slug_format` |
| `slug = 'tenant-alpha'` já existente | rejeitado pelo índice `tenants_slug_index` |

A expressão `slug ~ '^[a-z0-9-]{3,63}$'` como restrição de verificação funciona e falha
no banco, não apenas na aplicação — garantia válida mesmo para escrita feita por
migração ou tarefa administrativa.

**Imutabilidade**: não há restrição declarativa simples para "coluna imutável" sem
gatilho. Decisão: impor na aplicação, pela ausência de `slug` na lista de campos
permitidos em alteração, e cobrir com teste. Gatilho de banco fica registrado como opção
caso a garantia de aplicação se mostre insuficiente.

---

## R9 — Verificação de saúde em dois níveis (FR-001 a FR-004, SC-009)

**Decisão**: dois caminhos distintos no roteador. O público responde apenas vivacidade,
sem consultar dependência alguma. O detalhado exige segredo de operação comparado em
tempo constante e consulta armazenamento e mecanismo de trabalho assíncrono.

**Rationale**: separar os caminhos, em vez de variar o corpo da resposta conforme
autenticação, evita que um defeito de autorização exponha o corpo detalhado. O público
não consultar dependência alguma também o torna barato o suficiente para uso como sonda
de infraestrutura em alta frequência.

Comparação do segredo deve ser em tempo constante para não permitir inferência por
medição de tempo. Ausência do segredo na configuração faz o caminho detalhado recusar
todo acesso — nunca liberar (edge case já registrado na especificação).

---

## R10 — Integração contínua

**Decisão**: `erlef/setup-beam` fixando Elixir 1.20.2 e OTP 29, PostgreSQL 17 como
serviço do fluxo de trabalho, cache separado para `deps`/`_build` e para o PLT do
Dialyzer.

**Rationale**: FR-034 exige executar contra armazenamento de dados real provisionado pelo
próprio processo de verificação — serviço do fluxo de trabalho satisfaz isso sem
contêiner gerenciado manualmente. As versões precisam ser fixadas explicitamente porque
são recentes; deixar em aberto tornaria a verificação não reproduzível.

Chave de cache do PLT deve incluir versão de OTP, versão de Elixir e hash de `mix.lock`,
conforme o nome de arquivo observado em R3.

**Orçamento de SC-012 (10 minutos)**, com base nas medições reais: Dialyzer 1m40s sem
cache e 3s com PLT cacheado; compilação completa das dependências na primeira execução é
o maior custo. Com cache aquecido a expectativa é folgada; sem cache a primeira execução
fica próxima do limite. Registrar como risco a acompanhar, não como bloqueio.

---

## Itens deliberadamente não pesquisados nesta fase

- Alvos de latência, taxa de requisição e volume: a especificação não define e a fundação
  não tem carga real. Pertence a feature de capacidade.
- Localização e acessibilidade: única superfície é a verificação de saúde.
- Biblioteca de YAML: pertence à feature 002, com pesquisa própria conforme a
  constituição.
- Estratégia de publicação em produção e observabilidade externa: fora do escopo
  declarado da especificação.
