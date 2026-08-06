# CLAUDE.md — The Band

Guia operacional para agentes de IA neste repositório. A autoridade normativa é
[.specify/memory/constitution.md](.specify/memory/constitution.md) — em conflito, a
constituição prevalece.

## O que é The Band

Plataforma de integração semântica e análise de dados de Engenharia de Software.
Coleta dados de ferramentas de desenvolvimento (GitHub, GitLab, Azure DevOps, Jira,
SonarQube, CI/CD, gestão de projetos, monitoramento, controle de tempo), harmoniza
semanticamente, preserva proveniência, e responde perguntas de gestão com
rastreabilidade — ex.: "quanto tempo um PR aguarda a primeira revisão?", "de quais
fontes este indicador foi derivado?", "como esta medida foi calculada?".

Não é dashboard, data lake sem semântica, coleção de scripts, cópia dos modelos das
ferramentas, nem chatbot ligado ao banco.

## Estado atual do repositório

**Feature 001 entregue.** A aplicação Phoenix existe, sobe, e tem isolamento por Tenant
imposto por análise estática.

> **Repositório é PÚBLICO.** Histórico, especificações e mensagens de commit são
> visíveis e indexáveis por qualquer pessoa. Nunca versione credencial, token, chave ou
> `.env` real — aqui isso é vazamento imediato, não achado a corrigir depois. Escreva
> todo artefato assumindo leitura externa.
>
> **A linha principal é protegida no servidor** pelo conjunto de regras `protect-main`,
> sem atores de exceção — nem para quem administra. Sem escrita direta, sem reescrita de
> histórico, sem remoção. Exige Pull Request com resolução de comentários e **três
> verificações obrigatórias de status**. Aprovações humanas exigidas: **zero**, pela
> cláusula `Mantenedor único` — ver abaixo. Sempre trabalhe em branch e abra PR.

| Item | Estado |
|---|---|
| Repositório | público, `main` protegida por `protect-main`, sem ator de exceção |
| `constitution.md` | **v2.0.0** — cláusula `Mantenedor único` |
| Elixir / Erlang OTP | 1.20.2 / OTP 29.0.4 |
| Aplicação Phoenix + LiveView | **existe** — 1.8.9 / 1.2.8 |
| Ecto / PostgreSQL | **existe** — 3.14.0 / 17.10 |
| Oban | **existe** — 2.23.1, migração v14, 1 trabalhador de referência |
| Req | dependência presente, **nenhum conector** — feature 025 |
| Isolamento por Tenant | **existe** — escopo que levanta; RLS descartada, ver ADR-0002 |
| Verificação automática | `ci.yml` + `security.yml`, 3 status checks obrigatórios |
| Registros de decisão | ADR-0001 a **0006** em `docs/adr/` |
| Contrato OpenAPI dos serviços | **ausente** — regra vale desde já, dívida paga pela feature 039 |
| `priv/knowledge_base/` | **ausente** — feature 002 |
| Módulos ontológicos | **ausentes** — features 003+ |

Tabelas existentes: `tenants`, `operational_events`, e as do Oban. Nenhuma com prefixo de
ontologia — há teste que falha se aparecer.

Feature em curso: **002 — Infraestrutura da base de conhecimento YAML** — `specify`, `clarify` e
`checklist` concluídos; `plan` a seguir.

### O que subir e verificar

```bash
cp .env.example .env && docker compose up -d
mix deps.get && mix ecto.setup && mix phx.server

curl -s http://localhost:4000/health          # {"status":"alive"}
mix gates                                     # os cinco portões, na ordem correta
mix test --only integration                   # obrigatórios no CI
```

`mix gates` respeita a ordem exigida: `mix credo` **não** compila o projeto antes de rodar, e
sem a compilação as checagens próprias não carregam e o Credo sai com código 0.

## Arquitetura

Monólito modular multitenant em Elixir/Phoenix. Sem microserviços.

```text
Fontes externas → conectores Elixir → dados brutos → proveniência
→ transformação semântica → módulos organizados pelas ontologias
→ PostgreSQL/Ecto → necessidades de informação → medidas e indicadores
→ Reportify → Phoenix LiveView e APIs
```

O núcleo do domínio é organizado pelas **ontologias**, nunca pelas ferramentas
externas.

### Rede de ontologias

```text
UFO
└── SEON
    ├── EO      organizações, pessoas, equipes, papéis
    ├── SPO     projetos, processos, atividades, participações
    ├── SysSwO  sistemas, programas, código, artefatos
    ├── RSRO    requisitos e artefatos de requisitos
    ├── CMPO    repositórios, branches, commits, merges, change requests
    ├── ROoST   testes, execuções, resultados
    ├── QAPO    avaliações, critérios, não conformidades
    ├── OSDEF   defeitos, faults, failures, vulnerabilidades
    └── Continuum
        ├── SRO   processo Scrum, backlogs, user stories, entregáveis
        ├── CIRO  integração contínua, build, test, inspection
        └── CDRO  continuous delivery, continuous deployment
```

Dependência vai do específico para o geral.

- Permitido: `SRO → EO|SPO|SysSwO|RSRO`, `CIRO → SPO|SysSwO|CMPO|ROoST|QAPO|OSDEF`,
  `CDRO → SPO|SysSwO|CIRO`.
- Proibido: `EO → SRO`, `SPO → CIRO`, `SysSwO → CDRO`.

Conceito que já existe em ontologia mais geral é reutilizado, nunca duplicado.
`Person` pertence a EO; SRO, CIRO e CDRO só referenciam pessoas em papéis contextuais.

### Termo canônico: Tenant ≠ Organização

| Termo | Significado | Onde |
|---|---|---|
| **Tenant** | unidade de isolamento da instalação — quem contrata e opera este The Band. Coluna `tenant_id`. | feature 001 |
| **Organização** | organização do mundo real analisada — `eo.organization`, objeto social do domínio | feature 005, EO |

Um Tenant contém **várias** Organizações. Consultoria que analisa 12 clientes = 1 Tenant,
12 `eo.organization`. `eo_organizations` tem `tenant_id`; não é redundância.

**Nunca** use "organização" como sinônimo de Tenant, em código, spec, commit ou revisão.
Fundir os dois destrói a capacidade de comparar organizações dentro do mesmo contratante —
a pergunta central do produto.

### Distinções semânticas que não podem ser violadas

- **Tenant** ≠ `eo.organization` (ver acima)
- `Person` ≠ `Team Member` (papel) ≠ `Team Membership` (relação contextual). Pessoa é
  agente físico, existe independente de organização, e **não** tem `organization_id` —
  participa por vínculo com papel e período. Sem isso, "quais pessoas acumulam papéis?" e
  cycle time por equipe ficam inrespondíveis.
- `Intended Process` ≠ `Performed Process`
- `Code` ≠ `Program`
- documento de requisitos ≠ requisito
- Pull Request ≠ merge ≠ decisão de aprovação
- `Test Case` ≠ `Test Execution`
- code smell ≠ defeito
- `Failure` (evento) ≠ `Defect`

Nunca mapeie conceitos só por semelhança de nome.

### API pública dos módulos

Cada ontologia expõe API pública pelo módulo principal:

```elixir
defmodule TheBand.Ontology.Continuum.SRO do
  alias TheBand.Ontology.Continuum.SRO.{Commands, Queries}

  defdelegate register_user_story(attrs), to: Commands
  defdelegate list_sprint_user_stories(sprint_id), to: Queries
end
```

Nunca faça, fora do próprio módulo:

```elixir
Repo.insert(%TheBand.Ontology.Continuum.SRO.UserStory{})
```

Conectores nunca escrevem direto nos schemas Ecto dos módulos ontológicos.

### Prefixos de tabela

`eo_`, `spo_`, `sysswo_`, `rsro_`, `cmpo_`, `roost_`, `qapo_`, `osdef_`, `sro_`,
`ciro_`, `cdro_`.

## Stack

Obrigatória: Elixir, Erlang/OTP, Phoenix, Phoenix LiveView, Ecto, PostgreSQL, Oban,
Req, ExUnit, Mox, Credo, Dialyzer, ExDoc, Docker Compose, Phoenix Releases.

Proibido por padrão (só com feature + análise comparativa + ADR): Python, Go, frontend
separado em TypeScript, Node.js como requisito central, NATS, Kafka, RabbitMQ, Redis
como fila, Apache AGE, Neo4j, pgvector, Kubernetes, Helm, microserviços.

Biblioteca nova exige justificativa no `plan.md`.

**Biblioteca YAML: decidida por medição**, não por conveniência —
[ADR-0005](docs/adr/0005-biblioteca-yaml-e-portao-de-tokens.md).

- `yaml_elixir` constrói, sempre com `read_all_from_string/2`. Nunca `read_from_string/2`, que
  descarta documentos em silêncio;
- **antes dela, um portão de tokens** com `:yamerl_parser`, que recusa âncora, apelido, chave
  duplicada, tabulação na indentação e múltiplos documentos. Não é otimização: um arquivo de **814
  bytes** de apelidos aninhados **mata o processo**, e nenhuma biblioteca oferece limite de nós;
- `fast_yaml` descartada por não compilar sem `libyaml` do sistema numa máquina limpa;
- **nenhuma** biblioteca de validação de esquema. Escrita em Elixir.

**Carregamento**: uma vez na inicialização, para `:persistent_term`. YAML inválido **impede o
arranque** — base parcial mentiria sobre o modelo semântico.
[ADR-0006](docs/adr/0006-estrategia-de-carregamento-da-base-de-conhecimento.md).

## Base de conhecimento YAML

`priv/knowledge_base/` é base de conhecimento declarativa, versionada, validável e
auditável — **não** configuração. Representa ontologias, conceitos, relações,
cardinalidades, restrições, perguntas de competência, mapeamentos, necessidades de
informação, medidas, fórmulas, glossário, exemplos, regras e proveniência.

Todo YAML: tem schema, versão, id estável, dependências declaradas, proveniência
declarada. Schema estrito rejeita campo desconhecido. Nenhum YAML contém segredo.

Tasks Mix (feature 002):

```bash
mix knowledge.validate   # valida YAMLs contra schemas
mix knowledge.compile    # compila YAMLs para estruturas Elixir
mix knowledge.graph      # verifica dependências e ciclos
mix knowledge.test       # executa perguntas de competência e regras
mix knowledge.diff       # mostra mudanças semânticas entre versões
```

Não ler disco a cada requisição — carregar em compile-time, boot ou cache controlado,
conforme decisão registrada no plano.

## Multitenancy

Uma base PostgreSQL, tabelas compartilhadas, `tenant_id` nas entidades relevantes,
políticas de acesso. Não um banco por tenant. Todo acesso considera o tenant atual.
Jobs Oban carregam e validam `tenant_id`. YAMLs são globais por padrão.

## Serviços HTTP têm contrato OpenAPI — sempre

**Todo serviço HTTP exposto pela plataforma tem especificação OpenAPI publicada, sem exceção.**
Endpoint sem contrato declarado não entra. A regra vale para APIs REST, para o motor de consulta
declarativa da feature 025 e para qualquer superfície futura consumida por outro programa.

Por quê: o contrato é o que permite avaliar compatibilidade antes de mudar — e a constituição
proíbe alterar contrato sem avaliar compatibilidade. Sem especificação, "o contrato" é o código, e
a avaliação vira leitura de diff.

Obrigatório em todo serviço:

- caminho, método, parâmetros, corpo e **todas** as respostas, inclusive as de erro;
- esquema de autenticação, quando houver;
- o contrato **gerado ou verificado a partir do código**, nunca escrito à mão em paralelo. Contrato
  mantido à mão divergirá, e um contrato que mente é pior que nenhum;
- teste que reprova quando rota, parâmetro ou resposta divergem do contrato — senão a regra é
  decorativa;
- versão declarada, e mudança incompatível declarada como incompatível.

Proibido: contrato que exponha segredo, cabeçalho de autenticação com valor real, exemplo com
credencial, ou host interno.

### Dois documentos, e a divisão é derivada — não escolhida

O repositório é público. A feature 001 decidiu que `/health` não nomeia componente algum
justamente porque a URL fica documentada, e que `/health/detail` recusa todo acesso sem credencial.
Um documento OpenAPI público que enumere `/health/detail` e seu esquema de autenticação entrega
reconhecimento de infraestrutura — **anula a decisão da 001 por outro caminho, sem revogá-la.**

| Documento | Acesso | Conteúdo |
|---|---|---|
| público | sem credencial | só endpoints cujo pipeline é público |
| interno | credencial de operação | todos, com esquema de autenticação |

O balde de cada endpoint é **derivado do pipeline de autenticação da rota**, nunca escolhido à mão.
Divisão por julgamento erra em silêncio: alguém acrescenta rota privilegiada, esquece de marcá-la, e
ela aparece no documento público sem nada reprovar. Derivada do pipeline, o erro exige mudar a
autenticação da rota — que é visível. E há teste que reprova se rota de operador aparecer no
documento público, porque derivação sem teste é convenção.

Registrado em [ADR-0004](docs/adr/0004-contrato-openapi-e-sua-exposicao.md), com as duas
alternativas rejeitadas e o motivo de cada uma.

### Estado: a regra nasceu com duas violações

**Nenhum contrato OpenAPI existe.** Os dois endpoints da feature 001 foram entregues sem ele. A
dívida é paga pela **feature 039**, que fica imediatamente antes da 025 — a primeira a expor serviço
para consumidor de verdade. Não é retrofitada dentro de outra feature: a constituição proíbe misturar
features independentes.

A **emenda da constituição está adiada de propósito**: a regra vive aqui até a 039, e a emenda MINOR
entra no mesmo PR que a implementa. Emendar agora colocaria a constituição em violação imediata
pelos dois endpoints existentes, e norma que nasce violada ensina que norma pode ser violada.
Enquanto isso, em conflito a constituição prevalece sobre este arquivo — e ela ainda não exige
contrato.

A biblioteca exige justificativa no `plan.md` da 039. Nada aqui antecipa a escolha.

## Fluxo de trabalho

Comandos do Spec Kit instalado usam **hífen**, não ponto:

```text
/speckit-constitution  /speckit-specify  /speckit-clarify  /speckit-checklist
/speckit-plan  /speckit-tasks  /speckit-taskstoissues  /speckit-analyze
/speckit-implement  /speckit-converge
```

Ciclo obrigatório por feature:

```text
Necessidade → Discovery → Feature Request
→ /speckit-specify → /speckit-clarify → /speckit-checklist → aprovação
→ /speckit-plan → revisão arquitetural → revisão semântica
→ /speckit-tasks → /speckit-taskstoissues → /speckit-analyze
→ branch → implementação → testes → quality gates → convergência
→ Pull Request → revisão independente → merge
```

O passo `aprovação` do ciclo foi **delegado** por instrução permanente da pessoa mantenedora: o
agente roda o ciclo ponta a ponta e interrompe apenas pelos motivos de uma lista fechada de onze
itens. A lista, as condições de incorporação e as armadilhas de execução já pagas neste
repositório estão em [AGENTS.md](AGENTS.md) — é o único lugar onde vivem, de propósito.

A delegação não dispensa a aprovação: é aprovação concedida uma vez. Enquanto a constituição não
registrar a delegação por emenda, o princípio I prevalece sobre o `AGENTS.md` em caso de disputa.

Branches: `feature|fix|refactor|docs|test|chore/<issue>-<descricao>`

Commits: `tipo(escopo): descrição imperativa` — ex.
`feat(cmpo): add change request schema`, `fix(cmpo): prevent duplicate commit
ingestion`. Nunca mensagem vaga.

Nunca push direto na main. Nunca merge com teste falhando.
Documentação, contratos, migrações, YAMLs e testes vão no mesmo PR do código.

### Mantenedor único (constituição 2.0.0)

O repositório tem **uma única pessoa** com permissão de escrita, e o GitHub não permite
aprovar o próprio PR — exigir aprovação humana tornaria toda incorporação impossível. A
constituição substituiu a aprovação humana por **verificação mecânica**:

- **Permanece obrigatório**: branch + PR sempre; escrita direta na main bloqueada no
  servidor sem ator de exceção; **todos os quality gates registrados como status checks
  obrigatórios**; resolução de comentários.
- **Muda**: aprovações humanas exigidas = 0. Auto-merge permitido **só depois** de todas as
  verificações obrigatórias passarem.
- **Compensações obrigatórias**: todo requisito verificável precisa de verificação
  automatizada; o PR declara requisito por requisito qual evidência o cobre; achado
  `CRITICAL`/`HIGH` do `analyze` bloqueia o merge; revisão independente por outro agente,
  **sem** tratá-la como equivalente a revisão humana.
- **Reversão automática**: ao entrar a 2ª pessoa com permissão de escrita, a exigência de
  aprovação humana volta sem nova emenda.

**Risco encerrado.** O estado transitório declarado na emenda — "enquanto as verificações
obrigatórias não existirem, a proteção se reduz a exigir PR" — acabou. As três verificações
estão registradas no servidor: `Quality gates`, `Credenciais versionadas`,
`Dependências vulneráveis`.

Provado por execução, não por leitura de configuração:

```text
$ git push origin main
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote: - Changes must be made through a pull request.
remote: - 3 of 3 required status checks are expected.
 ! [remote rejected] main -> main
```

Rejeitado para quem **administra** o repositório. E com verificação obrigatória reprovada, a
incorporação fica `BLOCKED` mesmo com as outras duas aprovadas — exige-se que **todas** passem.

## Quality gates

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
mix dialyzer
mix test
mix knowledge.validate   # a partir da 002
mix knowledge.graph      # a partir da 002
mix knowledge.test       # a partir da 002
```

Quando aplicável: `mix ecto.migrate`, `mix test --only integration`.

Nunca remover ou enfraquecer teste para o pipeline passar. Nunca esconder erro com mock
excessivo ou valor fixo.

## Roadmap

```text
001 Fundação Phoenix e governança      ✔ ENTREGUE (94/95, T088 pendente)
002 Infraestrutura da base YAML        ← EM CURSO
003 Infraestrutura comum de ontologias

# vertical fina de valor: prova o pipeline ponta a ponta antes de ampliar ontologias
005 EO → 009 CMPO → 024 fontes externas
→ 039 contrato OpenAPI → 025 motor GraphQL/YAML
→ 026 GitHub→EO → 027 GitHub→CMPO → 031 necessidades → 032 medidas
   entrega: "tempo até a primeira revisão" de ponta a ponta

# 039 recebe número novo em vez de renumerar 025–038: renumerar quebraria toda
# referência já escrita. Ela vem antes da 025 porque a 025 é a primeira feature a
# expor serviço para consumidor, e paga a dívida dos dois endpoints da 001.

# ampliação sob demanda
004 UFO · 006 SPO · 007 SysSwO · 008 RSRO · 010 ROoST · 011 QAPO · 012 OSDEF
013–017 SRO · 018–021 CIRO · 022–023 CDRO
028 GitHub→SRO · 029 Actions→CIRO · 030 Deployments→CDRO

033 Analytics · 034 Reportify · 035 Dashboard
036 Avaliação do Knowledge Graph · 037 Recuperação semântica · 038 GraphRAG
```

Cada item tem ciclo próprio de Spec Kit.

## Restrições

Não pode: programar sem Spec Kit, spec, plano, tarefas ou issue; push direto na main;
merge com qualquer verificação obrigatória reprovada, ausente ou pendente; merge sem
verificação independente (humana com 2+ mantenedores, mecânica com 1 — ver `Mantenedor
único`); declarar sucesso sem evidência; remover teste
para passar; inventar requisito; ampliar escopo silenciosamente; expor segredo; colocar
segredo em YAML; misturar features independentes; alterar arquitetura sem ADR; mapear
conceitos só por nome; ignorar proveniência; ignorar idempotência; criar dashboard sem
necessidade de informação; alterar contrato sem avaliar compatibilidade; mudar código
para novo requisito sem atualizar o Spec Kit; marcar tarefa concluída sem evidência;
ignorar inconsistência do `analyze`; duplicar conceitos entre ontologias; aceitar YAML
inválido; usar a API externa como modelo de domínio.

Havendo incerteza relevante: **pare e apresente alternativas**.
