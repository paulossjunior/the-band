# ADR-0004 — Todo serviço HTTP tem contrato OpenAPI, e o documento é dividido por credencial

- **Status**: aceita, **não implementada** — feature 039
- **Data**: 2026-08-06
- **Feature**: 039 — Contrato OpenAPI (a criar), imediatamente antes da 025
- **Decide**: se existe contrato declarado para serviço HTTP, e quem pode ler esse contrato

## Contexto

O projeto passou a exigir especificação OpenAPI para **todo** serviço HTTP exposto. A regra é
"sempre", sem exceção por tamanho ou por importância do endpoint.

A razão não é documentação. A constituição proíbe alterar contrato público sem avaliar
compatibilidade, e sem uma especificação declarada "o contrato" é o próprio código — a avaliação de
compatibilidade vira leitura de diff, feita por quem já decidiu mudar.

Há um segundo fato que muda a decisão, e é específico deste repositório: **ele é público.**

A feature 001 decidiu deliberadamente que:

- `GET /health` informa apenas que a plataforma está viva, e **não nomeia componente algum**,
  porque a URL fica documentada num repositório público e resposta detalhada aberta entregaria
  reconhecimento de infraestrutura;
- `GET /health/detail` recusa todo acesso sem a credencial de operação, e a recusa é **idêntica**
  para credencial ausente e credencial inválida.

Um documento OpenAPI público e completo desfaz essa decisão por outro caminho: ele enumera
`/health/detail`, diz onde o caminho privilegiado está e que tipo de credencial ele aceita. Nada
disso vaza segredo, e ainda assim é exatamente o reconhecimento que a 001 recusou entregar.

## Decisão

**Dois documentos, e o balde de cada endpoint é derivado do pipeline de autenticação da rota.**

| Documento | Acesso | Conteúdo |
|---|---|---|
| público | sem credencial | apenas endpoints cujo pipeline é público |
| interno | credencial de operação | todos os endpoints, com esquema de autenticação |

A divisão **não** é escolhida a mão endpoint por endpoint. Ela é derivada do pipeline que a rota
atravessa: rota pública entra no documento público, rota de operador entra apenas no interno.

Isto é o ponto central da decisão. Uma divisão por julgamento erra em silêncio — alguém acrescenta
uma rota privilegiada, esquece de marcá-la, e ela aparece no documento público sem que nada reprove.
Derivada do pipeline, o erro exige mudar a autenticação da rota, que é visível. E há teste que
reprova se rota de operador aparecer no documento público, porque derivação sem teste é convenção.

Obrigações que valem para os dois documentos:

- caminho, método, parâmetros, corpo e **todas** as respostas, inclusive as de erro;
- contrato **gerado ou verificado a partir do código**, nunca mantido à mão em paralelo;
- teste que reprova quando rota, parâmetro ou resposta divergem do contrato;
- versão declarada, e mudança incompatível declarada como incompatível;
- nenhum segredo, cabeçalho com valor real, exemplo com credencial ou host interno.

## Alternativas rejeitadas

**Um documento único, protegido pela credencial de operação.** Mais simples, e hoje funcionaria: só
existem os dois endpoints de saúde. Rejeitada porque a feature 025 expõe o motor de consulta
declarativa a consumidor de verdade, e esse consumidor não tem acesso de operador — ficaria sem
contrato, o que esvazia a regra justamente para quem ela serve. A decisão voltaria à mesa em poucas
features, e voltar à mesa depois de a implementação existir custa mais.

**Um documento único, público e completo.** É o mais comum na indústria e o mais simples de todos.
Rejeitada porque enumera `/health/detail` e seu esquema de autenticação num repositório público.
Anularia a decisão da feature 001 sem revogá-la explicitamente, que é a pior forma de desfazer uma
decisão de segurança: ninguém percebe que foi desfeita.

## Consequências

**Aceitas:**

- dois artefatos em vez de um, e o custo de manter a derivação correta;
- a feature 039 introduz biblioteca nova, que exige justificativa no `plan.md` daquela feature.
  Nada aqui antecipa a escolha da biblioteca;
- o documento interno, por conter o mapa completo, herda a mesma proteção de `/health/detail`, e
  portanto o mesmo risco: credencial de operação vazada expõe o mapa. Isso não é novo — a credencial
  já dava acesso ao estado dos componentes.

**Dívida declarada:** os dois endpoints da feature 001 foram entregues **sem** contrato. A regra é
"sempre", e no momento em que ela foi escrita já havia duas violações. A dívida é paga pela feature
039, e **não** é retrofitada dentro de outra feature — a constituição proíbe misturar features
independentes.

**Emenda da constituição adiada de propósito.** A regra vive em `CLAUDE.md` até a feature 039, e a
emenda MINOR entra no mesmo Pull Request que a implementa. Emendar agora colocaria a constituição em
violação imediata pelos dois endpoints existentes, e norma que nasce violada ensina que norma pode
ser violada.

## Como verificar quando a 039 chegar

- documento público não contém rota alguma cujo pipeline exija credencial — verificado por teste;
- documento interno recusa acesso sem credencial, com recusa idêntica para ausente e inválida;
- divergência entre contrato e rota real reprova o portão;
- nenhum dos dois documentos contém valor de credencial, verificado pela mesma varredura que o
  repositório já usa.
