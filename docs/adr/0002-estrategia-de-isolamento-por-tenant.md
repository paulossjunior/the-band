# ADR-0002 — Estratégia de isolamento por Tenant

- **Status**: aceita
- **Data**: 2026-08-04
- **Feature**: 001 — Fundação e governança
- **Requisitos**: FR-012 a FR-017, FR-042, SC-002, SC-003, SC-004
- **Decide**: onde e como o isolamento entre contratantes é imposto

## Contexto

O The Band atende vários contratantes na mesma instalação. Dado de um **nunca** pode ser
visível, contável ou alterável a partir do contexto de outro.

Isolamento retroencaixado é a fonte clássica de vazamento entre clientes: adicioná-lo depois
exige revisar todo acesso a dados já escrito. Precisa ser a primeira restrição estrutural.

Duas perguntas independentes:

1. **Onde os dados ficam?** Uma base compartilhada, um schema por contratante, ou uma base por
   contratante.
2. **Quem impõe o filtro?** O banco de dados, ou a aplicação.

## Decisão

### Onde: base única, tabelas compartilhadas, coluna `tenant_id`

Uma base PostgreSQL. Toda entidade, exceto a própria tabela de Tenants, carrega `tenant_id`
`NOT NULL` com chave estrangeira `ON DELETE RESTRICT`.

### Quem impõe: a aplicação, através de um escopo que **levanta erro**

```elixir
{:ok, scope} = TheBand.Tenancy.scope(tenant_id)   # valida existência E ativação
TheBand.Audit.list_events(scope)
```

Toda função que toca dado tenant-scoped recebe `Scope.t()` como primeiro argumento. Receber
qualquer outra coisa **levanta**, inclusive `nil`.

> **A invariante: ausência de contexto de Tenant levanta erro. Nunca devolve conjunto vazio.**

### Row Level Security do PostgreSQL: **testada e descartada** nesta feature

Esta é a parte da decisão que mais importa, e ela vem de execução, não de preferência.

## A evidência que decidiu

RLS foi implementada e exercitada de ponta a ponta em PostgreSQL 17.10: papel de banco
não-dono, `FORCE ROW LEVEL SECURITY`, política sobre `current_setting('app.tenant_id', true)`.

| Cenário | Resultado real |
|---|---|
| `app.tenant_id` definido para o Tenant A | 3 de 8 linhas — **isolamento correto** |
| `INSERT` apontando para outro Tenant | **rejeitado**, `insufficient_privilege` |
| `SET LOCAL` após o fim da transação | `nil` — **não vaza** entre checkouts do pool |
| **`app.tenant_id` ausente** | **0 linhas, silenciosamente. Nenhum erro.** |

A última linha é a decisão.

**FR-014 exige rejeitar o acesso quando o contexto está ausente. RLS não rejeita: devolve
conjunto vazio.**

Um defeito que perdesse o contexto produziria "nenhum dado encontrado" em vez de falha visível.
Isso é **pior que a ausência de proteção**, porque parece funcionamento normal: ninguém abre
incidente para uma listagem vazia. O defeito sobrevive, e a confiança na plataforma some junto
com os dados que ela deixou de mostrar.

O escopo em camada de aplicação faz o oposto — levanta, com mensagem que nomeia o requisito:

```text
** (ArgumentError) acesso a dado tenant-scoped sem escopo de Tenant.
   Recebido: nil
   Isto levanta em vez de devolver conjunto vazio, e a diferença é o requisito FR-014.
```

### Custos adicionais de RLS, secundários mas reais

Mesmo que o problema acima não existisse, RLS exigiria:

- papel de banco não-dono para a aplicação, separado do papel de migração — o dono contorna RLS
  a menos que `FORCE` esteja ativo;
- `SET LOCAL` dentro de transação em **toda** leitura, o que obriga a envolver todo caminho de
  leitura em transação;
- coordenação com as tabelas do Oban, acessadas pela própria biblioteca.

Nenhum desses custos compraria o requisito que motivaria adotá-la.

## Como a fronteira é imposta, já que o banco não a impõe

Sem RLS, nada no banco barra um acesso que ignore a abstração. O lugar dessa barreira é ocupado
por **análise estática**, porque em Elixir não é possível tornar um módulo privado — uma
fronteira sem verificação automática é só um comentário.

`TheBand.Credo.Check.NoDirectRepoAccess` reprova a proposta de mudança que:

1. chame `TheBand.Repo` fora de uma lista curta de módulos autorizados, cada um com motivo
   registrado;
2. construa `%TheBand.Tenancy.Scope{}` fora de `TheBand.Tenancy`.

A segunda regra veio de revisão independente. `@opaque` é verificado por análise de tipos e
**não em execução**: qualquer módulo podia fabricar um escopo apontando para outro Tenant.
Verificado — um escopo fabricado lia dado de Tenant **desativado**, contornando FR-017, e
devolvia conjunto vazio para Tenant inexistente, reproduzindo dentro do nosso código o mesmo
modo de falha pelo qual RLS foi descartada.

### O que a análise estática garante, e o que não garante

Ela previne **descuido**, não contorno deliberado. Quem escreve código nesta aplicação e quer
burlar a validação também poderia chamar o repositório direto.

Importa para o modelo de ameaça: **não existe caminho de entrada externa que produza um escopo.**
A camada web chama `TheBand.Tenancy.scope/1` com o identificador recebido. Um contratante não
escreve código da aplicação. Portanto isto é fronteira **interna de disciplina**, não vetor de
vazamento entre contratantes.

Limitações registradas na própria checagem: não detecta apelido renomeado, repositório passado
como argumento, nem `apply/3` com módulo em variável.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| **RLS como mecanismo único** | Não satisfaz FR-014. Devolve vazio em vez de rejeitar. Evidência acima |
| **RLS somada ao escopo de aplicação** | Dobra os mecanismos na fundação, exige papéis de banco distintos e transação em toda leitura, sem satisfazer nenhum requisito que o escopo já não satisfaça. Adiar preserva a opção sem custo |
| **Prefixo de schema por Tenant** (`prefix:` do Ecto) | Equivale a um schema por contratante. Contraria a estratégia de tabelas compartilhadas e multiplica migrações por contratante |
| **Uma base por Tenant** | Proibida explicitamente pela constituição. Impede a pergunta comparativa que é o produto: uma consultoria com doze clientes não conseguiria comparar seus próprios clientes, porque a resposta exigiria cruzar bases |

## Consequências

### Aceitas

- **Sem RLS, o banco não barra quem ignorar a abstração.** Ocupado por análise estática, que
  previne descuido e não contorno deliberado.
- **A checagem tem pontos cegos**, registrados nela mesma.
- **`admin_*` são caminhos de leitura fora de escopo**, necessários porque FR-017 exige que dado
  de Tenant desativado permaneça legível. O prefixo é deliberado: uma busca no código encontra
  todo acesso fora de escopo numa única expressão.

### Ganhas

- Ausência de contexto **falha visivelmente**, e a mensagem nomeia o requisito.
- Validação de existência **e** ativação num só lugar. Um escopo obtido pela API pública já
  carrega as duas garantias, e nenhuma função precisa reverificar.
- Toda consulta é um `JOIN` normal. Sem transação obrigatória, sem papéis de banco extras.
- O mecanismo é testável sem infraestrutura: nenhum teste precisa de papel de banco especial.

## Verificação

| Critério | Como foi provado |
|---|---|
| SC-002 | checagem de análise estática; violação em `lib/` → código de saída 16; módulos autorizados limpos |
| SC-003 | dois Tenants com **3 e 5** eventos; soma **8**; busca cruzada → `{:error, :not_found}` |
| SC-004 | `list_events(nil)`, `count_events(nil)`, `record_event(nil, …)`, `fetch_event(nil, …)`, `purge_events_before(nil, …)` — **todos levantam** |
| FR-017 | após desativar: `{:error, :tenant_inactive}`; leitura administrativa preserva os 3 eventos |

Contagens **diferentes** de propósito: com 3 e 3, um defeito que trocasse os escopos passaria
despercebido.

### Teste de mutação

Os testes foram verificados quebrando o código de propósito:

| Mutação | Testes que pegaram |
|---|---|
| remover o filtro `tenant_id` da consulta base | 9 de 14 de isolamento |
| `Scope.tenant_id!` devolver `nil` em vez de levantar | 3 (após correção; **1 antes**) |
| changeset aceitar `tenant_id` dos atributos | 3 (após correção; **1 antes**) |

A mutação revelou que **dois testes passavam pelo motivo errado**: com a invariante removida,
`where: tenant_id == ^nil` faz o próprio Ecto levantar `ArgumentError` — a mesma classe que nós
levantamos. As asserções ficavam verdes sem provar nada sobre a nossa fronteira, e passaram a
exigir a mensagem.

## Quando reconsiderar

- **Exigência regulatória de isolamento no banco.** Aí RLS volta como camada **adicional**, não
  substituta: ela barraria no banco, o escopo continuaria rejeitando ausência de contexto.
- **Um contratante exigir base separada** por contrato. Decisão comercial, não técnica, e exige
  ADR próprio.
- **A checagem de análise estática mostrar-se insuficiente** — uma violação real chegando à linha
  principal. Aí a resposta provável é somar RLS, não substituir.

## Referências

- `specs/001-phoenix-foundation-governance/research.md` — R2, evidência completa de RLS
- `specs/001-phoenix-foundation-governance/contracts/tenancy.md` — contrato da API
- `lib/the_band/tenancy/scope.ex` — o que é garantido e o que não é
- `credo_checks/no_direct_repo_access.ex` — a checagem e suas limitações
- ADR-0003 — Tenant não é Organização
