# ADR-0001 — Monólito modular multitenant em Elixir/Phoenix

- **Status**: aceita
- **Data**: 2026-08-04
- **Feature**: 001 — Fundação e governança
- **Requisito**: FR-041
- **Decide**: forma de execução e implantação da plataforma

## Contexto

O The Band integra dados de muitas ferramentas de Engenharia de Software — GitHub, GitLab,
Azure DevOps, Jira, SonarQube, ferramentas de integração e entrega contínuas, gestão de
projetos, monitoramento, controle de tempo. Harmoniza esses dados semanticamente contra uma
rede de ontologias de referência, preserva proveniência, e responde perguntas de gestão com
rastreabilidade.

A leitura ingênua desse enunciado sugere microserviços: um serviço por fonte, um por ontologia,
um de ingestão, um de medidas. O roteiro tem trinta e oito features e mais de dez ontologias, o
que reforça a intuição de "muitas partes, muitos serviços".

Essa intuição está errada para este projeto, e o motivo é o próprio propósito dele.

## Decisão

**Um monólito modular multitenant em Elixir/Phoenix.** Um processo de aplicação, uma base
PostgreSQL, módulos organizados pelas ontologias.

Nenhum microserviço. Nenhum broker externo. Nenhum banco de grafos. Nenhum frontend separado.
Nenhuma linguagem adicional.

```text
Fontes externas
→ conectores Elixir → dados brutos → proveniência
→ transformação semântica → módulos organizados pelas ontologias
→ PostgreSQL/Ecto
→ necessidades de informação → medidas e indicadores
→ Reportify → Phoenix LiveView e APIs
```

O núcleo do domínio é organizado pelas **ontologias**, nunca pelas ferramentas externas.

## Por que, e não apenas "porque é mais simples"

### O produto é feito de junções

A pergunta central da plataforma não é "quantos commits o repositório X tem". É do tipo:

> Quais Pull Requests aguardam mais tempo por revisão, em quais equipes, de quais projetos, e
> quais commits desses Pull Requests aparecem em falhas de build?

Responder isso cruza `cmpo.change_request`, `eo.person`, `eo.team`, `spo.performed_activity`,
`sysswo.software_item` e `ciro.build`. Numa arquitetura de microserviços, cada junção dessas
vira chamada de rede, e a consulta passa a ser orquestração distribuída — com latência,
consistência parcial e falha parcial onde antes havia um `JOIN`.

Fatiar por serviço quando o valor está justamente em cruzar os fatias é pagar o custo da
distribuição para perder a capacidade que motivou o projeto.

### A rede de ontologias já dá a modularidade

A separação que o domínio pede é **semântica**, não de processo. UFO, SEON, EO, SPO, SysSwO,
RSRO, CMPO, ROoST, QAPO, OSDEF, Continuum, SRO, CIRO, CDRO — com dependência do específico para
o geral, verificada no build.

Módulo Elixir com API pública dá essa fronteira sem rede no meio. E dá algo que microserviço
não dá: a violação de dependência entre ontologias é detectável **em tempo de compilação**, não
em produção.

### A plataforma de execução já resolve o que motivaria distribuir

Concorrência, isolamento de falha e supervisão de trabalho em segundo plano — as razões
habituais para separar processos — são o que a máquina virtual do Erlang oferece dentro de um
único nó. Coleta de fonte externa roda em processo supervisionado, com repetição e limite, sem
broker.

### O custo operacional é do tamanho do time

O projeto tem **uma pessoa mantenedora**. Microserviços custam observabilidade distribuída,
versionamento de contrato entre serviços, rastreamento entre processos e orquestração de
implantação. Esse custo não é proporcional ao número de serviços: é proporcional ao número de
serviços **vezes** a maturidade que a operação exige.

## Alternativas consideradas

### Microserviços por fonte externa

Um serviço por GitHub, GitLab, Jira e assim por diante.

Descartada. Os conectores são a parte **mais** parecida entre si: todos paginam, tratam limite
de taxa, guardam ponto de retomada, preservam payload bruto e chamam mapeamento declarativo.
Separá-los multiplica infraestrutura para código que quer ser compartilhado, e o motor
declarativo previsto na feature 025 resolve a variação sem separar processo.

### Microserviços por ontologia

Um serviço por EO, SPO, CMPO e assim por diante.

Descartada, e é a alternativa mais tentadora porque parece seguir o domínio. Mas as ontologias
**dependem** umas das outras por desenho: `SRO → EO, SPO, SysSwO, RSRO`;
`CIRO → SPO, SysSwO, CMPO, ROoST, QAPO, OSDEF`. Transformar cada dependência dessas em chamada
de rede converteria a rede de ontologias — que é a estrutura conceitual do produto — num grafo
de chamadas com falha parcial.

### Serviço separado de ingestão

Descartada por ora. É a alternativa **menos** ruim das três e a mais provável de se tornar
necessária: importação histórica de fonte grande tem perfil de recurso diferente do resto. Mas
separar antes de existir uma fonte real, um volume real e um gargalo medido é adivinhação.

Fica registrada como evolução esperada, não como erro a evitar. A decisão de separar exigirá ADR
próprio, com medição.

### Frontend separado em TypeScript

Descartada. A interface prevista é analítica: painel, listagem, detalhamento com rastreabilidade.
LiveView entrega isso sem duplicar modelo de dados em duas linguagens e sem manter uma camada de
API só para consumo próprio.

## Consequências

### Aceitas

- **Escala vertical primeiro.** Um nó maior antes de mais nós. Aceitável porque a carga é de
  coleta e análise, não de tráfego de usuário final.
- **Uma base de dados é ponto único de falha.** Mitigado por réplica e backup quando houver
  operação real, não antes.
- **Implantação é atômica.** Uma mudança em qualquer módulo implanta tudo. É o que torna os
  quality gates obrigatórios em vez de recomendados: sem eles, uma regressão em qualquer módulo
  derruba a plataforma inteira.
- **A fronteira entre módulos depende de disciplina, não de rede.** Nada impede fisicamente que
  um módulo alcance o schema interno de outro. Mitigado por análise estática — ver ADR-0002.

### Ganhas

- Junção entre ontologias é `JOIN`, não orquestração distribuída.
- Violação de dependência entre ontologias falha o build.
- Transação abrange transformação semântica e persistência, o que dá idempotência sem
  compensação distribuída.
- Uma pessoa consegue operar.

## Quando reconsiderar

Esta decisão **não** é permanente. Reconsiderar quando houver **medição**, não intuição:

| Sinal | O que provavelmente indica |
|---|---|
| Importação histórica de uma fonte satura o nó e degrada consulta | separar ingestão |
| Uma ontologia tem ciclo de mudança radicalmente diferente das outras | extrair aquele módulo |
| Coleta exige mais de um nó por volume, não por disponibilidade | distribuir coleta |
| Consulta analítica competindo com escrita de coleta | separar leitura, ainda sem microserviço |

Cada uma exige ADR próprio. Abandonar o monólito modular está na lista de decisões que exigem
ADR na constituição.

## Referências

- `.specify/memory/constitution.md` — seção Restrições Tecnológicas
- `specs/001-phoenix-foundation-governance/plan.md` — Technical Context
- ADR-0002 — estratégia de isolamento por Tenant
- ADR-0003 — Tenant não é Organização
