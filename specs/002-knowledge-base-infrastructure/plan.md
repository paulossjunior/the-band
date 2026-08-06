# Plano de implementação — Feature 002, infraestrutura da base de conhecimento YAML

**Branch**: `feature/002-knowledge-base-infrastructure`

**Data**: 2026-08-06

**Especificação**: [spec.md](spec.md) — 92 requisitos funcionais, 24 critérios de sucesso

**Pesquisa**: [research.md](research.md) — R1 a R11, medidos

**Registros de decisão**: [ADR-0005](../../docs/adr/0005-biblioteca-yaml-e-portao-de-tokens.md) ·
[ADR-0006](../../docs/adr/0006-estrategia-de-carregamento-da-base-de-conhecimento.md)

## Summary

Construir a maquinaria que torna `priv/knowledge_base/` uma base de conhecimento declarativa,
versionada, validável e auditável. Nenhuma ontologia é modelada.

O desenho tem uma característica que a pesquisa impôs e que nenhuma leitura de documentação sugeriria:
**a validação tem duas passagens, e a primeira acontece antes de qualquer termo ser construído.** Um
arquivo de 814 bytes mata o processo se chegar à construção (research.md R6), e nenhuma das bibliotecas
disponíveis oferece limite de nós. O portão de tokens não é otimização — é a única defesa.

## Technical Context

| Item | Escolha | Fonte |
|---|---|---|
| Interpretação de YAML | `yaml_elixir` ~> 2.12, promovida de dependência transitiva de desenvolvimento para dependência de runtime | ADR-0005 |
| Portão de tokens | `:yamerl_parser.string/2` com `{:token_fun, fun}` | ADR-0005, R10 |
| Construção | `YamlElixir.read_all_from_string/2` — **nunca** `read_from_string/2` | ADR-0005, R8 |
| Validação de esquema | escrita em Elixir, **sem biblioteca nova** | ADR-0005 |
| Representação em execução | `:persistent_term`, carregada na inicialização | ADR-0006 |
| Grafo e ciclos | escrito em Elixir; `:digraph` do OTP é opção de implementação, sem dependência nova | — |
| Comparação entre versões | duas referências do histórico do repositório | spec Q2 |

### Justificativa da dependência

A constituição exige justificativa de biblioteca nova no `plan.md`. **`yaml_elixir` já está no
`mix.exs`**, como dependência transitiva `only: [:dev, :test]` da ferramenta de auditoria, com um aviso
registrado desde a feature 001 dizendo que aquela presença **não** era a escolha.

O que muda aqui: ela passa a ser declarada **explicitamente** e disponível em runtime, porque a base é
carregada na inicialização da aplicação. A escolha foi feita por medição — R1 a R11 — e não por
conveniência, que é exatamente o que FR-048 proíbe. O aviso no `mix.exs` é substituído por uma
referência à ADR-0005.

Nenhuma outra dependência é acrescentada. `:persistent_term`, `:digraph` e `:yamerl_parser` são,
respectivamente, OTP, OTP e uma dependência que já vem com `yaml_elixir`.

## Constitution Check

| Princípio | Como esta feature obedece |
|---|---|
| I — especificação antes de código | `specify`, `clarify` e `checklist` concluídos antes deste plano. Nenhuma linha escrita ainda |
| II — semântica primeiro | nenhuma ontologia modelada; os esquemas exigem classificação ontológica e reciprocidade (FR-076, FR-080) para que as distinções não negociáveis não possam ser fundidas |
| III — proveniência | FR-073 e FR-074 exigem proveniência em todo arquivo, com vocabulário fechado, e separam proveniência **do conhecimento** da proveniência **de dado integrado** |
| IV — nenhuma métrica sem necessidade de informação | FR-077 exige que toda medida declare a necessidade que responde. Achado do checklist `semantics.md`, CHK008 — era violação constitucional |
| V — evidência antes de conclusão | matriz requisito→evidência obrigatória; SC-021 exige provar impedindo o carregamento de um esquema por vez, nove casos |
| VI — simplicidade evolutiva | **zero** biblioteca de validação, de grafo ou de cache. `:persistent_term`, `:digraph` e Elixir puro |
| VII — idempotência | validação e compilação são funções puras do conteúdo do disco: rodar duas vezes produz saída idêntica byte a byte (FR-091, SC-023) |
| VIII — base de conhecimento como artefato | é o objeto da feature |

Nenhuma decisão desta feature exige ADR além das duas já escritas. Nada da lista de tecnologias
proibidas é introduzido.

## Project Structure

```text
priv/knowledge_base/
├── manifest.yaml
├── schemas/                       9 esquemas de validação
│   ├── ontology.schema.yaml       concept · relation · mapping
│   ├── competency-question.schema.yaml
│   ├── information-need.schema.yaml
│   ├── measurement.schema.yaml    glossary · connector-definition
│   └── ...
└── examples/                      conjunto reservado — espaço `example.*`
                                   exercita os 9 esquemas, os 3 estados, os 2 idiomas
                                   AUSENTE da base compilada (FR-044, FR-067)

lib/the_band/knowledge/
├── knowledge.ex                   API pública do módulo
├── manifest.ex                    FR-002 a FR-006, FR-088
├── token_gate.ex                  PASSAGEM 1 — âncora, chave duplicada, tabulação, multi-doc
├── loader.ex                      PASSAGEM 2 — read_all_from_string, um documento
├── schema.ex                      esquemas: forma, campos, vocabulários fechados
├── validator.ex                   FR-007 a FR-018, FR-051 a FR-085
├── graph.ex                       FR-019 a FR-023 — ciclo, direção, referência pendente
├── secret_scan.ex                 FR-024, FR-025, FR-062 a FR-065
├── compiled.ex                    :persistent_term — FR-026 a FR-029
├── report.ex                      FR-015 a FR-017, FR-091 — saída determinística e ordenada
└── diff.ex                        FR-036 a FR-040

lib/mix/tasks/
├── knowledge.validate.ex   knowledge.graph.ex   knowledge.test.ex
├── knowledge.compile.ex    knowledge.diff.ex

test/the_band/knowledge/            unitários por módulo
test/fixtures/knowledge_base/       CAMINHO DE RECUSA — fora de priv/ (FR-043)
test/integration/knowledge_*.exs    portões, arranque, carregamento
```

**Por que os casos de recusa ficam em `test/fixtures/` e não em `priv/`**: arquivo inválido dentro da
base faria a verificação obrigatória reprovar permanentemente (FR-043). O caminho de aceitação fica em
`priv/knowledge_base/examples/` porque só assim os nove esquemas são exercitados por algo que a
verificação obrigatória de fato lê.

## Sequência de implementação

Ordem por dependência, não por prioridade declarada. Cada bloco é entregável e verificável sozinho.

| # | Bloco | Requisitos | Fecha |
|---|---|---|---|
| 1 | Portão de tokens | FR-010, FR-011, FR-018, FR-071, FR-072, FR-092 | R6 e R7 — a defesa contra a bomba e contra a corrupção silenciosa |
| 2 | Manifesto e esquemas | FR-001 a FR-006, FR-055 a FR-057, FR-075 a FR-085, FR-088 | as obrigações de conteúdo, sem as quais nove esquemas vazios satisfariam FR-005 |
| 3 | Validação estrita e `knowledge.validate` | FR-007 a FR-017, FR-051 a FR-054, FR-058 a FR-061, FR-073, FR-074, FR-089 a FR-091 | US1 |
| 4 | Varredura de segredo e exceções | FR-024, FR-025, FR-062 a FR-065 | proibição de segredo em base pública |
| 5 | Grafo e `knowledge.graph` | FR-019 a FR-023, FR-082 a FR-084, FR-086 | US2 |
| 6 | Conjunto reservado de exemplos | FR-041, FR-042, FR-044 | dá sujeito à maquinaria |
| 7 | Compilação, `:persistent_term` e arranque | FR-026 a FR-030, FR-066 a FR-070, FR-087 | US4 |
| 8 | `knowledge.test` | FR-031 a FR-035 | US5 |
| 9 | `knowledge.diff` | FR-036 a FR-040 | US6 |
| 10 | Três verificações obrigatórias no servidor | FR-045 a FR-047 | US3 — só pode fechar depois de 3, 5 e 8 existirem |

Um Pull Request por bloco ou por grupo coeso de blocos, como na feature 001. Nunca misturar.

## Riscos, e o que fazer com cada um

| Risco | Mitigação |
|---|---|
| **`:yamerl_parser` é interface interna.** O portão depende de tipos de token que não são API pública de `yaml_elixir`. Atualização pode quebrar | Teste que reprova se o fluxo deixar de expor `:yamerl_anchor`, `:yamerl_alias` ou `:yamerl_mapping_key`. O portão **nunca** pode degradar para "não detectou nada" com código de saída zero — é a classe de defeito da feature 001 |
| **Verificação que aprova sem ter feito o trabalho.** Já aconteceu neste projeto | FR-089 e SC-021: confirmar que os nove esquemas carregaram, provado impedindo o carregamento de um por vez. Nove casos, nove reprovações. FR-016 e FR-017 valem para as **cinco** tarefas |
| **YAML inválido impede o arranque** (ADR-0006) | Deliberado: base parcial mentiria sobre o modelo semântico. Mitigado por onde mora — as três verificações obrigatórias impedem conteúdo inválido de chegar à linha principal |
| **Âncoras proibidas** custam reuso declarativo | Aceito. R6 mediu 814 bytes matando o processo, e R5 mediu âncora em fluxo produzindo dado errado. O recurso é perigoso **e** defeituoso |
| Sem linha e coluna para byte inválido (R9) | Limitação registrada em ADR-0005, não contornada. A mensagem nomeia arquivo e razão |
| Duplicação semântica não é mecanizável | Limitação aceita e registrada em Assumptions da especificação. Achado CHK024 |
| Orçamento de dez minutos com oito verificações | R11 mediu 1,36 s para cinco mil arquivos. A análise de YAML não é o gargalo por uma ordem de grandeza. Medir o total de novo ao fechar o bloco 10 |

## O que este plano deliberadamente **não** faz

- não modela ontologia alguma — features 003 em diante;
- não constrói linguagem de regra declarativa — decidido em Q3, registrado em Out of Scope;
- não cria `priv/knowledge_base/ontology/`, `mappings/`, `rules/`, `sources/` nem qualquer diretório
  sem conteúdo — a constituição proíbe pasta vazia antecipada, e há teste que reprova;
- não introduz contrato OpenAPI: esta feature não expõe endpoint algum. A regra existe, e o motivo de
  não ter sujeito aqui está em Out of Scope (ADR-0004, feature 039);
- não escolhe biblioteca de validação de esquema — nenhuma é usada.

## Complexity Tracking

| Complexidade acrescentada | Justificativa |
|---|---|
| Duas passagens de análise por arquivo | R6: sem o portão, 814 bytes derrubam a verificação obrigatória. R11: custo de 0,27 ms/arquivo contra orçamento de dez minutos. A alternativa não existe — nenhuma biblioteca oferece limite de nós |
| Acoplamento a interface interna de `yamerl` | É o único lugar que expõe âncora, apelido e chave duplicada com posição. `yaml_elixir` não expõe. Coberto por teste que reprova se o acoplamento quebrar |
| Recusar arranque com YAML inválido | FR-028 proíbe representação parcial. Degradar seria servir um modelo semântico que mente |
| Validação escrita à mão em vez de biblioteca | Princípio VI. Vocabulário fechado, reciprocidade, direções de dependência e correspondência nos dois sentidos seriam escritos à mão de qualquer forma; a biblioteca cobriria só a parte fácil e acrescentaria dependência |
