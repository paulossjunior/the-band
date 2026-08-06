# ADR-0007 — O YAML é a especificação normativa do modelo; a implementação é derivada dele e conferida por teste

- **Status**: aceita. Vale para a feature 002 no que ela precisa **exigir**; a verificação de
  conformidade em si chega com a **feature 003**, quando existir módulo ontológico para conferir
- **Data**: 2026-08-06
- **Feature**: 002 — Infraestrutura da base de conhecimento YAML
- **Requisitos**: FR-093 a FR-098 (novos), FR-075, FR-076, FR-079
- **Decide**: qual é a relação entre os YAMLs da base de conhecimento e os schemas Ecto, as migrações
  e o código dos módulos ontológicos

## Contexto

A base de conhecimento representa conceitos, atributos, relações, cardinalidades e restrições. Os
módulos ontológicos, das features 003 em diante, terão schemas Ecto e tabelas com prefixo por
ontologia.

Os dois descrevem a mesma coisa. **Quem manda?**

O documento de referência do projeto define `knowledge.compile` como "carregar e compilar os YAMLs
para **estruturas Elixir**" — estrutura em memória, não schema Ecto e não migração. Ele não decide a
relação com o banco. A especificação da feature 002, escrita antes desta decisão, tratava a base como
fonte de consulta em execução e **não dizia nada** sobre o modelo persistido.

Deixar indefinido tem custo concreto: o YAML declara que `sro.user_story` tem o atributo `importance`,
a tabela `sro_user_stories` não tem a coluna, e **nada reprova**. A base semântica passa a mentir sobre
o sistema real — e é ela que responde "de quais fontes este indicador foi derivado", que é a pergunta
central do produto.

## Decisão

**O YAML é a especificação normativa. A implementação é derivada dele. A divergência entre os dois
reprova um portão.**

- **o YAML define os tipos e as cardinalidades.** Conceitos com atributos nomeados, tipados e com
  obrigatoriedade declarada; relações com cardinalidade declarada em notação única;
- os schemas Ecto, as migrações e o código dos módulos ontológicos são **implementados a partir do
  YAML** — é o agente que os escreve, lendo o YAML como especificação, dentro do ciclo Spec Kit;
- um teste de conformidade **reprova** quando os dois divergirem: atributo declarado e ausente do
  schema, campo no schema fora do YAML, tipo divergente, cardinalidade que não corresponde à
  associação implementada, tabela sem o prefixo da ontologia;
- **nenhum código é gerado mecanicamente.** Não existe `mix knowledge.gen`, não existe arquivo `.ex`
  gerado e versionado, não existe migração automática.

### A consequência que decide o desenho da 002: o YAML tem de ser suficiente

Se a implementação é derivada do YAML, então **o que o YAML não disser, quem implementa vai inventar**
— e inventar requisito é o que a constituição proíbe no princípio I.

Isto transforma "declare seus atributos" numa barra muito mais alta: o vocabulário de tipo precisa ser
**fechado** e mapear sem ambiguidade para um tipo de persistência. `type: numero` não serve: inteiro,
decimal e ponto flutuante têm consequências diferentes em banco, e escolher por conta própria é
inventar. Cardinalidade precisa ser **obrigatória**, porque a diferença entre `many_to_one` e
`many_to_many` é a diferença entre uma coluna e uma tabela de junção.

### O teste de conformidade é a rede de segurança de quem implementa

Como a implementação é derivada por leitura, ela pode errar: interpretar demais, esquecer um campo,
escolher o tipo vizinho. O teste que compara YAML e schema é o que pega isso.

É a mesma lógica da cláusula `Mantenedor único`: quando não há uma segunda pessoa relendo o diff, a
verificação tem de ser mecânica.

### Axiomas: enunciado estruturado, sem linguagem formal

Restrição e axioma são declarados **dentro** do próprio conceito ou da relação (FR-083), com
identificador estável e enunciado nos dois idiomas exigidos. Quem implementa lê o enunciado e o traduz
em validação, restrição de banco ou código.

**Nenhuma linguagem formal de expressão é construída nesta feature.** Isso preserva a decisão da
clarificação Q3, que manteve `knowledge.test` estrutural e recusou projetar uma linguagem de regra
antes de existir ontologia real para exercitá-la.

A escolha é assimétrica de propósito: axioma declarado como enunciado identificado pode ser
formalizado por uma feature futura. Axioma **não declarado** não pode ser formalizado depois, porque
não existe.

## Alternativas rejeitadas

**Gerar schemas e migrações mecanicamente a partir do YAML.**

Elimina a divergência por construção, o que é atraente. Rejeitada por três razões:

1. **migração gerada não é migração revisada.** Renomear coluna com dados dentro, mudar tipo, preencher
   valor para linha existente — cada um tem risco de perda de dado, e a forma correta depende do que já
   está no banco, que o YAML não sabe;
2. **código gerado e versionado volta a ser duas fontes de verdade**, e pior, porque parece derivado:
   alguém edita o arquivo gerado, o gerador roda de novo, a edição desaparece — ou não roda, e a
   divergência fica invisível. A verificação de divergência continuaria necessária de todo jeito;
3. índice, chave composta e restrição de banco são julgamento de engenharia, não consequência da
   ontologia. Um gerador teria de aceitar anotações para tudo isso, e o YAML deixaria de ser modelo
   semântico para virar descrição de banco — o que o princípio II proíbe.

Se a geração for desejada algum dia, esta ADR é o ponto de partida: com a conformidade já verificada,
gerar passa a ser economia de digitação, não mudança de fonte de verdade.

**Só consulta em execução, sem conferência.** É o que a especificação da 002 dizia implicitamente e o
que o documento de referência diz literalmente. Rejeitada pelo custo descrito no Contexto.

## Consequências

**Aceitas:**

- **a mesma informação é escrita duas vezes** — no YAML e no schema. É o preço de manter julgamento
  humano sobre índices, chaves e estratégia de migração. A conferência garante que a duplicação não
  vire divergência;
- o teste de conformidade **reprova trabalho pela metade**: schema sem YAML, ou YAML sem schema. É
  intencional — as duas metades entram no mesmo PR, como a constituição já exige para migração e
  documentação;
- **a feature 002 ganha requisitos** (FR-093 a FR-098) que ela não tinha, e sem os quais a 003 não tem
  contra o que conferir.

**A lacuna que esta decisão expôs, e que existia em silêncio:** ao registrar isto, verificou-se que
**nenhum requisito da especificação exigia que um conceito declarasse seus atributos**. FR-076 exigia
classificação ontológica e especialização, e nada mais. Sob esta ADR, a conferência da 003 não teria
contra o que conferir e quem implementasse teria de inventar os campos.

É a mesma classe de defeito que a 002 combate, invertida no tempo: não "verificação sem sujeito", mas
**"sujeito sem os dados que a verificação futura exige"**. Encontrada porque a decisão foi registrada
em vez de assumida.

**Fato considerado, e que não muda a ADR-0006:** os YAMLs são editados raramente — uma vez por feature
ontológica, não como configuração. Isso torna o carregamento em tempo de compilação mais atraente do
que parecia. **A ADR-0006 se mantém**: o argumento decisivo dela não era o custo de recompilar, era que
compilação cria duas fontes de verdade que divergem em silêncio, e a objeção vale igual para conteúdo
raramente editado. Registrado para que a pergunta "por que não em compilação, se ninguém edita?" tenha
resposta em vez de virar experimento repetido.

## Como verificar quando a feature 003 chegar

- atributo declarado no YAML e ausente do schema reprova;
- campo no schema ausente do YAML reprova;
- tipo divergente reprova;
- cardinalidade declarada que não corresponde à associação implementada reprova;
- tabela sem o prefixo da sua ontologia reprova;
- **e a conferência não pode aprovar quando não encontrou par algum para comparar.** É a forma da
  falha da feature 001 — ferramenta que sai com código de sucesso sem ter feito o trabalho — e ela se
  aplica aqui igual.
