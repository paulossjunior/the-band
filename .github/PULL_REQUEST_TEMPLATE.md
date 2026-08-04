<!--
Sob a cláusula `Mantenedor único` da constituição, a contagem de aprovações humanas exigidas
é zero. Isto significa que ninguém vai ler o diff de novo.

Consequência para este formulário: a tabela de requisito para evidência não é burocracia — é
o que substitui a revisão humana. Um requisito sem evidência executada é um requisito não
atendido, independentemente de o portão ter passado.
-->

## Feature

<!-- Ex.: 001 — Fundação e governança. Tarefas T001–T021. -->

- Especificação:
- Plano:
- Issue: <!-- `Closes #N` -->

## Escopo

<!-- O que este PR entrega. -->

## Fora de escopo

<!-- O que ele deliberadamente NÃO entrega, e onde isso é tratado. Escopo ampliado em
silêncio é proibido pela constituição. -->

## Ontologias afetadas

<!-- Ontologia principal e das quais depende. Se nenhuma, escreva "Nenhuma" e diga por quê —
não deixe em branco. -->

## Conceitos e relações afetados

<!-- Conceitos adicionados ou alterados, relações, cardinalidades, constraints.

CUIDADO com fusão de conceitos: `Tenant` não é `eo.organization`; `Person` não é
`Team Member`; Pull Request não é merge. Ver as distinções invioláveis na constituição. -->

## YAMLs alterados

<!-- Arquivos da base de conhecimento declarativa. Se nenhum, escreva "Nenhum". YAML de
fluxo de trabalho e modelo de solicitação NÃO são base de conhecimento. -->

## Mapeamentos semânticos

| Origem | Ontologia | Conceito | Equivalência | Limitação |
|---|---|---|---|---|
|  |  |  |  |  |

## Migrações

| Migração | Reversível | Verificado como |
|---|---|---|
|  |  |  |

<!-- Migração que não reverte é armadilha que se descobre quando se precisa voltar. -->

## Requisito → evidência

<!-- OBRIGATÓRIO. Uma linha por requisito e por critério de sucesso que este PR afeta.

"Evidência" é saída de execução, não afirmação. "Os testes passam" não é evidência de um
requisito; o teste que prova aquele requisito é. -->

| Requisito | Evidência executada |
|---|---|
|  |  |

## Resultado dos quality gates

| Portão | Resultado |
|---|---|
| `mix format --check-formatted` |  |
| `mix compile --warnings-as-errors` |  |
| `mix credo --strict` |  |
| `mix dialyzer` |  |
| `mix test` |  |
| `mix test --only integration` |  |
| `mix knowledge.validate` (a partir da 002) |  |
| `mix knowledge.graph` (a partir da 002) |  |
| `mix knowledge.test` (a partir da 002) |  |

## Perguntas de competência validadas

<!-- Só para feature ontológica. Se não se aplica, diga por quê. -->

## Evidências

<!-- Saída de execução. Cole o que aconteceu, não o que deveria acontecer.

Inclua também o que a execução revelou e mudou o plano: correção de pesquisa, defeito
encontrado, hipótese descartada. Isso é a parte mais útil do PR para quem vier depois. -->

## Riscos residuais

<!-- O que fica conhecido e aceito, com a razão.

Requisito não provado precisa aparecer aqui, não desaparecer. Ver o princípio V: nenhum
agente declara sucesso sem evidência. -->

## Checklist

- [ ] Spec Kit concluído para esta feature
- [ ] `analyze` sem inconsistência `CRITICAL` ou `HIGH` pendente
- [ ] YAMLs validados, ou justificado por que não se aplica
- [ ] Mapeamentos semânticos revisados, ou justificado por que não se aplica
- [ ] Testes passando, sem teste removido nem enfraquecido para o portão passar
- [ ] Credo `--strict` aprovado, sem checagem afrouxada — e se alguma foi, justificada no
      próprio `.credo.exs`
- [ ] Dialyzer aprovado
- [ ] Migrações aplicam **e revertem**
- [ ] Documentação, contratos e testes no mesmo PR do código
- [ ] Ausência de segredos, inclusive no histórico
- [ ] Convergência verificada: toda tarefa da issue concluída, ou realocada com justificativa
- [ ] Revisão independente por outro agente, com resultado anexado

<!-- A última caixa é exigência da cláusula `Mantenedor único`. Ela não é equivalente a
revisão humana, e essa limitação é registrada de propósito. -->
