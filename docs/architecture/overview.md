# Arquitetura do The Band — visão geral

**Estado**: fundação entregue (feature 001). Nenhuma ontologia implementada ainda.

Este documento descreve a arquitetura pretendida e marca com clareza o que **já existe** e o que
ainda **não existe**. A distinção importa: descrever o pretendido como se estivesse pronto é o
erro que faz alguém procurar um módulo que ninguém escreveu.

## O que a plataforma faz

Coleta dados de ferramentas usadas no desenvolvimento de software, harmoniza semanticamente com
base em ontologias de referência, preserva proveniência, e responde perguntas de gestão com
rastreabilidade.

Não é painel, não é data lake sem semântica, não é coleção de scripts de extração, não é cópia
dos modelos de dados dos fornecedores, e não é chatbot ligado ao banco.

## Fluxo pretendido

```text
Fontes externas  (GitHub, GitLab, Jira, SonarQube, CI/CD, …)
      │
      ▼
conectores Elixir  ──► dados brutos ──► proveniência
      │                (payload preservado)
      ▼
transformação semântica  (mapeamento declarativo em YAML)
      │
      ▼
módulos organizados pelas ONTOLOGIAS
      │
      ▼
PostgreSQL / Ecto      ── base única, tabelas compartilhadas, tenant_id
      │
      ▼
necessidades de informação ──► medidas e indicadores
      │
      ▼
Reportify ──► Phoenix LiveView e APIs
```

O núcleo do domínio é organizado pelas **ontologias**, nunca pelas ferramentas externas. Uma
entidade externa alimenta várias ontologias: um Pull Request do GitHub vira solicitação de
mudança em CMPO, pessoas em papéis em EO, atividades e participações em SPO, artefatos em SysSwO,
e possível gatilho de pipeline em CIRO.

## O que existe hoje

```text
lib/the_band/
├── application.ex          árvore de supervisão
├── repo.ex                 acesso ao armazenamento — fronteira imposta por análise estática
├── schema.ex               base de todo schema: binary_id + timestamp com microssegundos
├── config.ex               leitura de ambiente que falha nomeando a variável ausente
│
├── tenancy.ex              API pública do isolamento
├── tenancy/
│   ├── scope.ex            escopo validado — LEVANTA na ausência de contexto
│   ├── scope_error.ex
│   ├── tenant.ex           schema
│   ├── queries.ex          autorizado a chamar o repositório
│   └── commands.ex         autorizado a chamar o repositório
│
├── audit.ex                API pública de evento operacional
├── audit/
│   ├── operational_event.ex   schema — primeira entidade que pertence a um Tenant
│   ├── queries.ex             ponto único onde o filtro por tenant_id é aplicado
│   └── commands.ex
│
├── health.ex               verificação de saúde em dois níveis
├── health/
│   ├── checker.ex          comportamento — fronteira testável
│   └── system_checker.ex   implementação real
│
└── telemetry/
    ├── correlation.ex      identificador propagado por requisição e por trabalho
    └── handler.ex          registro estruturado, com redação de valores sensíveis

lib/the_band_web/
├── endpoint.ex             plug de correlação vem antes da telemetria
├── router.ex               dois caminhos distintos de verificação de saúde
├── plugs/
│   ├── correlation_id.ex
│   └── operator_secret.ex  comparação em tempo constante
└── controllers/
    ├── health_controller.ex         público — não consulta dependência alguma
    └── health_detail_controller.ex  restrito a operação

credo_checks/
└── no_direct_repo_access.ex   impõe a fronteira de acesso a dados
```

Duas tabelas de domínio próprio — `tenants` e `operational_events` — mais as tabelas do Oban.

## O que NÃO existe ainda

| Ausente | Chega na feature |
|---|---|
| `priv/knowledge_base/` e as tarefas `mix knowledge.*` | 002 |
| `lib/the_band/ontology/` e a infraestrutura comum de ontologias | 003 |
| UFO, EO, SPO, SysSwO, RSRO, CMPO, ROoST, QAPO, OSDEF, SRO, CIRO, CDRO | 004 a 023 |
| Cadastro de fontes externas e o motor declarativo de coleta | 024, 025 |
| Conectores do GitHub | 026 a 030 |
| Necessidades de informação, medidas, analytics, Reportify, painel | 031 a 035 |
| Qualquer trabalhador assíncrono próprio | 005 (issue #5) |

A infraestrutura de trabalho assíncrono **está** de pé — supervisão, migração, fila — e nenhum
trabalhador foi escrito ainda.

Os diretórios ausentes **não** foram criados vazios: a constituição proíbe criar pasta antes de a
feature justificar, e há teste que falha se algum aparecer.

## As três fronteiras que sustentam o resto

### 1. Isolamento entre contratantes

Toda entidade, exceto `tenants`, carrega `tenant_id`. Todo acesso passa por um escopo validado
que **levanta erro** na ausência de contexto — nunca devolve conjunto vazio.

Row Level Security do PostgreSQL foi testada e descartada porque devolve conjunto vazio
silenciosamente sem o contexto, transformando perda de contexto em "nenhum dado encontrado".
Ver [ADR-0002](../adr/0002-estrategia-de-isolamento-por-tenant.md).

Sem RLS, a fronteira é imposta por análise estática: `TheBand.Credo.Check.NoDirectRepoAccess`
reprova acesso direto ao repositório e construção manual de escopo fora dos módulos autorizados.

### 2. Semântica antes de ferramenta

O domínio é organizado pelas ontologias, com dependência do específico para o geral, verificada
no build. Conceito que existe em ontologia mais geral é reutilizado, nunca duplicado.

Distinções que não podem ser violadas, e a razão de cada uma em
[ADR-0003](../adr/0003-tenant-nao-e-organizacao.md):

- **Tenant** ≠ `eo.organization` — um Tenant contém várias organizações
- `Person` ≠ `Team Member` (papel) ≠ `Team Membership` (vínculo com período)
- `Intended Process` ≠ `Performed Process`
- `Code` ≠ `Program`
- Pull Request ≠ merge ≠ decisão de aprovação
- `Test Case` ≠ `Test Execution`
- code smell ≠ defeito
- `Failure` (evento) ≠ `Defect`

Há teste que falha se a fusão começar.

### 3. Verificação mecânica em vez de confiança

O repositório tem uma única pessoa mantenedora, e a constituição substituiu aprovação humana por
verificação obrigatória no servidor. Cinco portões de qualidade são verificações obrigatórias de
status: escrita direta na linha principal é rejeitada, e incorporação com qualquer verificação
reprovada ou pendente é bloqueada — provado por tentativa real, não por leitura de configuração.

## Onde o processo assíncrono entra

O Oban executa coleta, transformação, cálculo de medidas e geração de relatório. Toda unidade de
trabalho declara seu Tenant, e trabalho de Tenant ausente, inexistente ou inativo falha
**definitivamente** com `{:cancel, motivo}` — sem nova tentativa, porque retentar não fará o
Tenant voltar a existir.

Nenhum broker externo. A plataforma de execução do Erlang cobre concorrência, isolamento de falha
e supervisão dentro de um nó. Ver [ADR-0001](../adr/0001-monolito-modular-multitenant.md).

## Observabilidade

Todo registro operacional carrega, quando aplicável: Tenant, identificador de correlação,
identificador do trabalho, tentativa, duração, situação e código de erro.

A correlação atravessa requisição, consulta ao banco e trabalho em segundo plano — é o que
permite reconstituir a cadeia de execução de uma falha. Valores sob chave de nome sensível são
redigidos na **escrita**, não filtrados na leitura: filtrar depois pressupõe que o valor já foi
persistido, e num banco isso alcança backup e réplica.

## Registros de decisão

| ADR | Decide |
|---|---|
| [0001](../adr/0001-monolito-modular-multitenant.md) | Monólito modular multitenant em Elixir/Phoenix |
| [0002](../adr/0002-estrategia-de-isolamento-por-tenant.md) | Onde e como o isolamento é imposto; por que RLS foi descartada |
| [0003](../adr/0003-tenant-nao-e-organizacao.md) | Tenant não é Organização, e por que fundir destruiria o produto |

## Referências

- `.specify/memory/constitution.md` — autoridade normativa
- `CLAUDE.md` — guia operacional
- `specs/001-phoenix-foundation-governance/` — especificação, plano, pesquisa e contratos
