# Specification Quality Checklist: Infraestrutura da base de conhecimento YAML

**Purpose**: Validate specification completeness and quality before proceeding to planning

**Created**: 2026-08-05

**Última execução**: 2026-08-05, segunda iteração — após Q1, Q2 e Q3 respondidas

**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) — **com duas exceções
  declaradas abaixo**
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders — **com uma limitação consciente, declarada abaixo**
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification — com as exceções declaradas

## Notes

### O que mudou entre a primeira e a segunda iteração

A primeira execução reprovou três itens, todos pela mesma causa: FR-006, FR-035 e FR-040
remetiam a uma decisão pendente em vez de declarar um requisito. Não era falha de redação —
cada uma tinha interpretações razoáveis que mudavam **o que se constrói**.

| Pergunta | Decisão | Efeito na especificação |
|---|---|---|
| **Q1** — lista de ontologias do manifesto | Inventário verificável | FR-006 passou a exigir verificação nos **dois** sentidos. A divergência deliberada em relação ao exemplo do documento de referência está registrada em Clarifications |
| **Q2** — contra o que a comparação compara | Duas referências do histórico | FR-040 passou a proibir explicitamente artefato gerado e versionado que descreva o estado semântico, com a razão |
| **Q3** — abrangência da verificação de perguntas de competência | Só estrutural | FR-033 e FR-034 deixaram de falar em regras; FR-035 passou a exigir que a limitação apareça **dentro do relatório**; a linguagem de regra entrou em Out of Scope; US5 ganhou um cenário sobre a declaração da limitação |

Os três registros detalhados em Clarifications listam também **o que foi rejeitado e por quê**
— inclusive um risco aceito: a verificação de perguntas de competência tem nome mais forte do
que o que ela garante, e é por isso que a limitação é exigida no relatório e não apenas aqui.

### Exceções declaradas a "no implementation details"

1. **YAML** é nomeado ao longo de toda a especificação. Não é escolha desta especificação: a
   constituição, no princípio VIII, define a base de conhecimento como arquivos YAML em
   `priv/knowledge_base/`. É restrição herdada, e omiti-la produziria uma especificação que
   não descreve a feature. Os casos de Edge Cases sobre coerção de tipo e âncoras só existem
   **porque** o formato é YAML, e removê-los apagaria a parte mais substantiva dos requisitos.

2. **`Ecto.Schema`** aparece uma vez, na tabela de terminologia, para dizer que "esquema de
   validação" **não** é isso. É nomeado para prevenir uma confusão — a palavra "schema" tem
   três sentidos neste projeto — e não para prescrever implementação.

Nenhum nome de tarefa, módulo, biblioteca ou ferramenta aparece na especificação. A escolha da
biblioteca de interpretação de YAML é explicitamente deixada para pesquisa e ADR (FR-048,
FR-049), inclusive com a proibição de ratificar a biblioteca que já está no projeto como
dependência transitiva da ferramenta de auditoria.

### Sobre "written for non-technical stakeholders"

As seis histórias de usuário, os critérios de sucesso e as seções de escopo são legíveis por
quem não programa. A seção Edge Cases **não é**, e não pode ser: os casos são comportamentos
específicos de interpretadores de YAML — coerção de `1.0` para número, `no` para falso,
expansão de apelidos recursivos — e são exatamente o conteúdo verificável desta feature. Cada
um é um caminho pelo qual arquivo inválido é aceito em silêncio, que é a classe de defeito que
a feature 001 encontrou na análise estática.

Reescrevê-los em linguagem de negócio os tornaria não verificáveis. Registrado como limitação
consciente, não como item a corrigir.

### Pronto para a próxima fase

Nenhum item reprovado. A especificação está pronta para `/speckit-checklist` e `/speckit-plan`.

O plano precisa resolver duas decisões que esta especificação deliberadamente não resolve, e
ambas exigem ADR: a biblioteca de interpretação de YAML (FR-048, FR-049) e a estratégia de
carregamento (FR-030).
