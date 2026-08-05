# Matriz de evidência — feature 001

**Data**: 2026-08-05 | **Spec**: [spec.md](spec.md) | **Roteiro**: [quickstart.md](quickstart.md)

Este documento existe porque a cláusula `Mantenedor único` da constituição pôs as aprovações
humanas em zero. Ninguém vai reler o diff, então a substituição é esta: **requisito por
requisito, qual evidência executada o cobre.**

Toda linha abaixo aponta para algo que foi **executado**, não afirmado. Onde a evidência não
existe, a linha diz isso.

## Resumo

| | |
|---|---|
| Critérios de sucesso | **17** |
| Provados por execução | **16** |
| Pendentes | **1** — SC-014, exige pessoa externa ao projeto |
| Requisitos funcionais | 45, todos com tarefa e evidência |
| Testes | 150 na execução padrão + 25 de integração |
| Portões | 6, todos com código de saída zero |

---

## Critérios de sucesso

### SC-001 — inicialização em até 15 minutos

**Provado. Medido: 24 segundos.**

Do zero, com contêiner destruído e `deps/` e `_build/` apagados, até base criada, migrada e
semeada. Contra um limite de 900 segundos.

### SC-002 — 100% dos acessos passam pela abstração de escopo

**Provado por análise estática, verificada contra violação deliberada.**

`TheBand.Credo.Check.NoDirectRepoAccess` detecta as duas formas de chamada:

| Forma | Detectada |
|---|---|
| `TheBand.Repo.all(...)` totalmente qualificada | sim |
| `Repo.all(...)` após `alias TheBand.Repo` | sim — **a forma idiomática** |
| construção manual de `%Scope{}` fora de `TheBand.Tenancy` | sim |

Violação deliberada em `lib/` → código de saída **16**. Módulos autorizados → limpos.

A primeira versão da checagem detectava **apenas** a forma qualificada, e por isso perderia
quase toda violação real dando impressão de cobertura. O furo foi encontrado provando a
checagem contra uma violação com apelido — ela não sinalizou nada.

Limitações registradas na própria checagem: apelido renomeado, repositório como argumento, e
`apply/3` com módulo em variável. Análise estática previne descuido, não contorno deliberado.

### SC-003 — zero vazamento entre Tenants

**Provado.**

```text
count_events(scope_a)                        3
count_events(scope_b)                        5
soma (16 provaria vazamento)                 8
evento de B buscado no escopo de A           {:error, :not_found}
```

Contagens **diferentes** de propósito: com 3 e 3, um defeito que trocasse os escopos passaria
despercebido.

Coberto também: listagem, alteração, remoção e expurgo cruzados; filtro por tipo exclusivo do
outro Tenant; limite alto; e chave estrangeira `ON DELETE RESTRICT` impedindo remoção de Tenant
com histórico.

### SC-004 — 100% dos acessos sem contexto são rejeitados

**Provado. Levanta, não devolve vazio.**

`list_events`, `count_events`, `record_event`, `fetch_event` e `purge_events_before` — todas
levantam com `nil`, com identificador cru, e com estrutura parecida com escopo.

A asserção verifica a **mensagem**, não só a classe de exceção. Teste de mutação revelou que
duas asserções passavam pelo motivo errado: com a invariante removida, `where: tenant_id == ^nil`
faz o próprio Ecto levantar `ArgumentError` — a mesma classe. Ficavam verdes sem provar nada
sobre a nossa fronteira.

### SC-005 — 100% das unidades sem Tenant declarado são rejeitadas

**Provado.** Situação `cancelled`, `attempt = 1`, motivo `tenant_id ausente`.

Coberto também `tenant_id` que não é texto: `123`, `%{}`, `[]`, `nil`.

### SC-006 — 100% das unidades de Tenant desativado falham permanentemente

**Provado.**

```text
caso                  state       attempt  motivo
tenant ativo          completed   1        -
sem tenant_id         cancelled   1        {:cancel, "tenant_id ausente"}
tenant inativo        cancelled   1        {:cancel, "tenant inativo: …"}
tenant inexistente    cancelled   1        {:cancel, "tenant inexistente: …"}
```

**`attempt = 1` é a asserção que importa.** Verificar apenas a situação final não pegaria o
defeito: um trabalho descartado após três tentativas também termina fora de `completed`.

Motivo persistido em `errors` e consultável após recarga do registro.

### SC-007 — idempotência em lote de pelo menos 10 execuções

**Provado, com a definição registrada.**

Dez execuções do mesmo trabalho, todas bem-sucedidas, produzindo dez eventos no mesmo Tenant,
todos atribuíveis ao mesmo trabalho, nenhum alcançando outro Tenant.

Dez eventos **não** é violação: é o registro fiel de que o trabalho executou dez vezes.
Registro operacional que desaparece quando repete mentiria sobre o que aconteceu. A propriedade
que importa é o estado ser **convergente e atribuível**.

Unicidade de enfileiramento verificada em separado: segunda inserção devolve a mesma
identificação com conflito sinalizado. O teste registra explicitamente que a presença da opção
`unique` **não** é evidência de idempotência de efeito.

### SC-008 — zero sucessos em identificador legível duplicado, alterado ou malformado

**Provado.**

| Tentativa | Resultado |
|---|---|
| `slug` duplicado | rejeitado — `has already been taken` |
| `AB`, `ab`, `TENANT`, `com_underscore`, `com espaço`, `com.ponto`, `@arroba`, `acentuação`, 64 caracteres | todos rejeitados |
| `abc`, 63 caracteres, `a-b-c`, `t3n4nt-1` | todos aceitos |
| alterar `slug` por `rename_tenant/2` | `slug` intacto |
| `slug` na lista de campos alteráveis | ausente — verificado no changeset |
| nome duplicado | **aceito** — FR-011 não exige unicidade |

Restrições verificadas **no banco**, não só na aplicação: índice único e restrição de
verificação por expressão regular.

### SC-009 — o público não revela componente; o detalhado recusa 100% sem credencial

**Provado.**

Resposta pública com **exatamente uma chave**, e 21 termos de infraestrutura verificados como
ausentes do corpo.

As três recusas do caminho detalhado — sem cabeçalho, com segredo errado, com segredo ausente da
configuração — produzem situação e corpo **idênticos**.

Prova mais forte, com o PostgreSQL parado:

```text
GET /health          → 200  {"status":"alive"}
GET /health/detail   → 503  {"status":"unhealthy","components":{"database":"down",…}}
```

O público responder 200 com o banco fora **é** o requisito: é o que o mantém utilizável como
sonda e o que impede que revele estado de componente.

### SC-010 — cada portão reprova violação deliberada

**Provado, 5 de 5.**

| Portão | Violação | Código de saída |
|---|---|---|
| formatação | linha mal formatada | 1 |
| compilação com alerta como erro | variável não usada | 1 |
| análise estática | módulo aninhado sem apelido | 6 |
| análise de tipos | especificação incorreta | 2 |
| testes | asserção invertida | 2 |

### SC-011 — 100% das escritas diretas na linha principal são rejeitadas

**Provado por tentativa real, não por leitura de configuração.**

```text
$ git commit --allow-empty -m "probe: verificar protecao da linha principal (SC-011)"
$ git push origin main
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote: - Changes must be made through a pull request.
remote: - 3 of 3 required status checks are expected.
 ! [remote rejected] main -> main (push declined due to repository rule violations)
```

Rejeitado para quem **administra** o repositório. `bypass_actors: []`,
`current_user_can_bypass: never`.

### SC-011a — incorporação bloqueada com verificação pendente ou reprovada

**Provado por tentativa real de incorporação.**

| Estado da verificação | Tentativa |
|---|---|
| pendente | recusada — `the base branch policy prohibits the merge` |
| reprovada | recusada — `mergeStateStatus: BLOCKED` |

As outras duas verificações **passaram** e a incorporação continuou bloqueada: exige-se que
**todas** passem, não a maioria.

Este é o substituto mecânico da aprovação humana. Sem ele, a cláusula `Mantenedor único` ficaria
sem lastro.

### SC-012 — verificação completa em até 10 minutos

**Provado. Medido em duas execuções reais.**

| Execução | CI | Análise de tipos | Segurança |
|---|---|---|---|
| 1ª, cache frio | **242s** | 156s | 60s |
| 2ª, cache quente | **52s** | 6s | 30s |

Contra 600 segundos. A medição confirma que o cache do arquivo de análise de tipos é
obrigatório: sem ele esse passo sozinho consome um sexto do orçamento.

### SC-013 — zero credenciais versionadas

**Provado.**

8 formatos sintéticos testados — token de plataforma, PAT, chave AWS, chave privada PEM, token
Slack, chave OpenAI, PAT GitLab, chave GCP: **8 de 8 detectados**.

4 valores legítimos do repositório testados: **0 falsos positivos**. Isto inclui os valores de
assinatura de desenvolvimento e teste, que foram escritos como texto legível em vez de string
aleatória exatamente para não serem confundidos com credencial vazada.

A varredura foi provada **localmente**, e não enviando credencial falsa ao repositório: mesmo
sintética, uma credencial enviada poluiria o histórico de um repositório público e dispararia
alerta da plataforma. A lógica testada é a mesma do fluxo de verificação.

O fluxo varre os **commits da mudança**, não apenas a árvore atual, porque credencial removida no
último commit continua no histórico.

### SC-014 — pessoa externa localiza e resume as decisões em até 10 minutos

**NÃO PROVADO.** Pendente, tarefa T088.

Este é o único critério que depende de alguém de fora, e é o único que não posso executar: eu
escrevi os registros de decisão. Testá-los eu mesmo seria ler meu próprio texto e confirmar que
me entendo, o que prova zero — o critério existe justamente para pegar o que o autor não vê,
como jargão que só faz sentido para quem participou ou decisão registrada onde ninguém procura.

Marcar sem executar violaria o princípio V da constituição. Fica declarado pendente.

**Como executar**: entregar a alguém que não participou o link do repositório e as três perguntas
do bloco 9 de [quickstart.md](quickstart.md), com 10 minutos de relógio.

### SC-015 — migrações aplicam e revertem sem erro

**Provado por 4 testes de integração**, com o sandbox desligado para que o DDL não seja
descartado no fim do teste.

Cobertos: reverter tudo e reaplicar; aplicar em base já migrada sem efeito; reverter em base
vazia; e as tabelas de trabalho assíncrono desaparecendo na reversão e voltando na reaplicação —
essa última porque reversão parcial passaria como sucesso sem ela.

### SC-016 — 100% dos registros de falha identificam Tenant, correlação e trabalho

**Provado.**

Telemetria de início, fim e exceção carregando `tenant_id`, `correlation_id`, `job_id`,
`attempt`, `duration`, `status` e `error_code`.

A correlação fornecida por quem enfileirou é propagada — sem isso, o trabalho não pode ser ligado
à requisição que o originou.

---

## Requisitos funcionais

45 requisitos, todos citados por ao menos uma tarefa e cobertos por evidência. Os agrupamentos e
a evidência de cada um estão nos Pull Requests correspondentes:

| Grupo | Requisitos | Pull Request |
|---|---|---|
| Ambiente e verificação de saúde | FR-001 a FR-008 | #10, #11 |
| Tenant e isolamento | FR-009 a FR-017 | #16 |
| Evento operacional | FR-018 a FR-020 | #16 |
| Trabalho assíncrono | FR-021 a FR-027 | #18 |
| Observabilidade | FR-028 a FR-030 | #10, #15, #18 |
| Verificação automática e governança | FR-031 a FR-040 | #12, #14 |
| Registros de decisão | FR-041 a FR-044 | #17 |

---

## O que a execução mudou no plano

Nenhuma destas mudanças veio de revisão de código ou de leitura de documentação. Todas vieram de
rodar.

| Achado | Como apareceu | Consequência |
|---|---|---|
| Row Level Security devolve vazio em vez de rejeitar | teste de ponta a ponta na pesquisa | mecanismo de isolamento trocado; ADR-0002 |
| Migração do Oban exige v14, não v12 | arranque real com plugins | pesquisa corrigida; lição registrada sobre exercitar o caminho reduzido |
| `mix credo --strict` reprova o código gerado pelo Phoenix | execução | `.credo.exs` com ajuste justificado |
| `mix credo` não compila antes de rodar; checagem ausente sai com código 0 | execução | guarda contra no-op silencioso no fluxo |
| Checagem em `test/` não compila; em `lib/` quebra produção | execução | `requires:` no `.credo.exs` |
| Plug de correlação criado e não ligado a nada | auto-revisão | ligado ao endpoint + 7 testes |
| PLT sobrescrito entre ambientes | auto-revisão | nome por ambiente; 83s economizados por troca |
| Correlação invisível nos logs de desenvolvimento | **rodando a aplicação** | formatador corrigido |
| Correlação lida do mapa cru, contornando a redação | **revisão independente** | contorno eliminado estruturalmente |
| `@opaque` não impede construção de escopo em execução | **revisão independente** | regra nova na checagem; garantia falsa corrigida na documentação |
| Dois testes passavam pelo motivo errado | **teste de mutação** | asserção por mensagem; 1 → 3 testes pegando |
| Caminho de vazamento com cobertura de teste único | **teste de mutação** | segundo ângulo; 1 → 3 testes pegando |

---

## Falsos alarmes que eu mesmo produzi

Registrados porque quem lê os PRs vai encontrá-los mencionados, e porque a causa é reaproveitável.

| Sintoma | Causa real |
|---|---|
| 3 portões com código 1 em execução em lote, e 0 individualmente — duas vezes | `zsh` não faz divisão de palavras em parâmetro não citado, então `mix $g` virava tarefa inexistente |
| `mix test` com conexão recusada | daemon do Docker parado |
| Situação `executing` e 11 eventos em vez de 10 | a fila de desenvolvimento está ativa e disputou os trabalhos com o script de evidência |
| Corpo de Pull Request corrompido | `zsh` interpretou acentos graves como substituição de comando |

Nenhum era defeito de código. Todos foram investigados antes de reportar como falha.

---

## Riscos residuais aceitos

- **SC-014 não provado.** Único critério dependente de pessoa externa.
- **Sem Row Level Security, o banco não barra quem ignorar a abstração.** Ocupado por análise
  estática, que previne descuido e não contorno deliberado. Registrado em ADR-0002.
- **A checagem de análise estática tem pontos cegos**, registrados nela mesma.
- **`max_attempts: 3` é escolha sem medição.** Não há carga real nem fonte externa ainda.
  Revisitar quando os conectores chegarem.
- **Nenhum teste cobre o formato do log em desenvolvimento.** Um teste que afirmasse a
  configuração testaria a configuração, não o comportamento. Esta classe de defeito continua
  exigindo rodar a aplicação para ser vista — foi assim que ela apareceu.
- **A idempotência deste trabalhador vem de o efeito ser acumulativo por natureza.** Um
  trabalhador cujo efeito seja mutação de estado — e os conectores serão — precisa de chave
  natural na escrita. O contrato registra isso, e este trabalhador **não** é modelo para esse
  caso.
