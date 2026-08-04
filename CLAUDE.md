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

**Fase 0 concluída (bootstrap).** Ainda NÃO existe aplicação Phoenix.

> **Repositório é PÚBLICO.** Histórico, especificações e mensagens de commit são
> visíveis e indexáveis por qualquer pessoa. Nunca versione credencial, token, chave ou
> `.env` real — aqui isso é vazamento imediato, não achado a corrigir depois. Escreva
> todo artefato assumindo leitura externa.
>
> **A linha principal é protegida no servidor** pelo conjunto de regras `protect-main`,
> sem atores de exceção: sem escrita direta, sem reescrita de histórico, sem remoção;
> exige Pull Request com 1 aprovação, descarte de aprovação obsoleta, aprovação do
> último envio e resolução de comentários. Sempre trabalhe em branch e abra PR.

| Item | Estado |
|---|---|
| Repositório | público, `main` protegida por `protect-main` |
| Spec Kit (`.specify/`, `.claude/skills/`) | instalado, integração `claude` |
| `constitution.md` | v1.0.0 ratificada |
| Elixir / Erlang OTP | 1.20.2 / OTP 29 (via Homebrew) |
| Docker | 29.4.x, daemon ativo |
| Aplicação Phoenix, Ecto, Oban, Req | **ausentes** — feature 001 |
| `priv/knowledge_base/` | **ausente** — feature 002 |
| Módulos ontológicos | **ausentes** — features 003+ |

Próxima feature: **001 — Fundação Phoenix e governança**.

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

Biblioteca nova exige justificativa no `plan.md`. Biblioteca YAML ainda **não
escolhida** — decidir no `/speckit-plan` da feature 002, com pesquisa de manutenção,
segurança e compatibilidade, e registrar em ADR.

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

Branches: `feature|fix|refactor|docs|test|chore/<issue>-<descricao>`

Commits: `tipo(escopo): descrição imperativa` — ex.
`feat(cmpo): add change request schema`, `fix(cmpo): prevent duplicate commit
ingestion`. Nunca mensagem vaga.

Nunca push direto na main. Nunca merge com teste falhando. Nunca aprovar o próprio PR.
Documentação, contratos, migrações, YAMLs e testes vão no mesmo PR do código.

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
001 Fundação Phoenix e governança      ← PRÓXIMA
002 Infraestrutura da base YAML
003 Infraestrutura comum de ontologias

# vertical fina de valor: prova o pipeline ponta a ponta antes de ampliar ontologias
005 EO → 009 CMPO → 024 fontes externas → 025 motor GraphQL/YAML
→ 026 GitHub→EO → 027 GitHub→CMPO → 031 necessidades → 032 medidas
   entrega: "tempo até a primeira revisão" de ponta a ponta

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
aprovar o próprio PR; merge sem revisão; declarar sucesso sem evidência; remover teste
para passar; inventar requisito; ampliar escopo silenciosamente; expor segredo; colocar
segredo em YAML; misturar features independentes; alterar arquitetura sem ADR; mapear
conceitos só por nome; ignorar proveniência; ignorar idempotência; criar dashboard sem
necessidade de informação; alterar contrato sem avaliar compatibilidade; mudar código
para novo requisito sem atualizar o Spec Kit; marcar tarefa concluída sem evidência;
ignorar inconsistência do `analyze`; duplicar conceitos entre ontologias; aceitar YAML
inválido; usar a API externa como modelo de domínio.

Havendo incerteza relevante: **pare e apresente alternativas**.
