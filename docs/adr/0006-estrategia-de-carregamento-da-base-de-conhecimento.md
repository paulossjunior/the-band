# ADR-0006 — A base de conhecimento é carregada na inicialização, não em compilação

- **Status**: aceita
- **Data**: 2026-08-06
- **Feature**: 002 — Infraestrutura da base de conhecimento YAML
- **Requisitos**: FR-026, FR-027, FR-028, FR-029, FR-030, SC-010
- **Decide**: quando os YAMLs são lidos, onde a representação vive, e o que acontece quando um é inválido
- **Evidência**: [research.md](../../specs/002-knowledge-base-infrastructure/research.md), R11

## Contexto

FR-027 proíbe leitura de disco a cada consulta. SC-010 exige que o número de leituras **não aumente**
entre a décima e a milésima consulta. FR-030 exige que a estratégia declare explicitamente o custo
aceito — invisibilidade de mudança sem recompilar, ou necessidade de invalidação explícita.

O documento de referência do projeto permite compilação, inicialização ou cache controlado, "conforme
decisão registrada no plano". A decisão precisava de medição, não de preferência.

**Medido em R11**: arquivo realista de conceito, 766 bytes, com rótulo e definição bilíngues, atributos,
relações, classificação e proveniência.

| Arquivos | Tempo de análise |
|---|---|
| 100 | 26 ms |
| 1.000 | 263 ms |
| 5.000 | **1.360 ms** |

A base entregue pela feature 002 tem cerca de quinze arquivos. Cinco mil é um cenário que só chega
muitas features adiante, e custa 1,4 segundo.

## Decisão

**Carregamento único na inicialização da aplicação, para `:persistent_term`.**

- a base é lida, validada e construída uma vez, quando a aplicação sobe;
- a representação vive em `:persistent_term`, que é do próprio Erlang/OTP — **nenhuma dependência
  nova**;
- consulta em execução lê de `:persistent_term` e **nunca** toca o disco. FR-027 e SC-010 ficam
  satisfeitos de forma absoluta, não estatística: o número de leituras de disco após a inicialização é
  **zero**, não "baixo";
- consulta a identificador inexistente devolve resposta que distingue "não existe" de "existe e está
  vazio" (FR-029);
- **arquivo inválido impede a aplicação de subir.** Não há carregamento parcial, não há degradação
  silenciosa.

## Por que a inicialização, e não a compilação

Compilar os YAMLs para dentro dos módulos parece atraente: custo zero na inicialização e imutabilidade
garantida. Foi rejeitada por um motivo que não é de conveniência.

**Criaria duas fontes de verdade que podem divergir em silêncio.** `mix knowledge.validate` lê o disco.
Um runtime com a base compilada carrega o que estava no disco **no momento da última compilação**. Uma
mudança de YAML sem recompilar faz a validação aprovar um conteúdo que o runtime não tem — e a
divergência não produz erro algum, apenas respostas obsoletas. É exatamente a forma da classe de defeito
que esta feature existe para fechar: verificação que aprova sem que o que foi verificado seja o que
está em uso.

O custo secundário, também real: mudar um YAML exigiria recompilar para vê-lo, o que atrapalha
justamente as features 003 em diante, que passarão o tempo escrevendo YAML.

## Por que não cache preguiçoso

Carregar sob demanda com cache em ETS foi rejeitado porque a primeira consulta paga o custo e, pior, o
caminho de falha do cache **lê o disco** — reintroduzindo, por consulta, a pergunta que FR-027 quer
eliminar. E um caminho de erro de cache que devolve "nada encontrado" em vez de falhar é a mesma
armadilha: resposta vazia que parece legítima.

A medição remove a única vantagem que o cache preguiçoso teria. Não há o que adiar: 1,4 segundo para um
cenário dez vezes maior que o realista.

## Consequências

**Aceitas:**

- **inicialização mais lenta**, na ordem de milissegundos para a base real. Se a base algum dia chegar
  a cinco mil arquivos, 1,4 segundo por arranque — e nesse ponto a decisão se revisita com número novo,
  não com suposição;
- **invalidação explícita em desenvolvimento.** Mudar um YAML não se reflete sem recarregar. Isto é o
  custo que FR-030 exige declarar. A feature entrega um caminho de recarga para desenvolvimento, para
  que a alternativa não seja reiniciar o servidor a cada edição;
- `:persistent_term` provoca varredura global de coleta de lixo a cada escrita. **Escrevemos uma vez, na
  inicialização, antes de haver carga** — o custo é pago quando não há nada para atrapalhar. Recarga em
  desenvolvimento paga de novo, e em desenvolvimento isso é irrelevante;
- os arquivos precisam existir em execução. `priv/` acompanha as releases do Phoenix, então o requisito
  já está satisfeito pela forma de empacotamento em uso.

**A consequência mais séria, declarada:** **YAML inválido impede o arranque.** Um arquivo malformado
não degrada o serviço — ele derruba a aplicação inteira.

Isto é deliberado e vale contra a alternativa. Uma base de conhecimento parcialmente carregada mentiria
sobre o que o modelo semântico afirma, e todo indicador derivado dela seria inválido sem que nada
avisasse. FR-028 já proíbe representação parcial; recusar o arranque é a forma de obedecer.

O risco é mitigado por onde ele mora: os YAMLs são versionados junto com o código, e as três
verificações obrigatórias de status impedem que conteúdo inválido chegue à linha principal. Para um
arquivo inválido derrubar a produção, ele teria de passar por `knowledge.validate`, `knowledge.graph` e
`knowledge.test` — que é precisamente o que esta feature constrói para ser impossível.

## Como verificar

- contador de leituras de disco idêntico entre a décima e a milésima consulta (SC-010);
- consulta a identificador inexistente distinguível de conteúdo vazio (FR-029);
- um arquivo inválido impede o arranque, com mensagem que nomeia o arquivo — e **não** sobe com base
  parcial (FR-028);
- conteúdo de exemplo, proposto e obsoleto ausentes da representação em execução (FR-044, FR-067);
- caminho de recarga em desenvolvimento reflete mudança de YAML sem reiniciar o servidor.
