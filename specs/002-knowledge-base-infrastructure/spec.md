# Feature Specification: Infraestrutura da base de conhecimento YAML

**Feature Branch**: `feature/002-knowledge-base-infrastructure`

**Created**: 2026-08-05

**Status**: Draft

**Input**: User description: "Infraestrutura da base de conhecimento YAML do The Band. Criar a maquinaria que torna `priv/knowledge_base/` uma base de conhecimento declarativa, versionada, validável e auditável — não configuração. Nenhuma ontologia é modelada nesta feature."

## Terminologia canônica

A palavra "schema" é usada com três significados diferentes neste projeto, e confundi-los
produz especificação ambígua e revisão inútil. Esta especificação usa os termos abaixo de
forma estrita.

| Termo | Significado | Onde vive |
|---|---|---|
| **Base de conhecimento** | Conjunto versionado de arquivos declarativos que representam o modelo semântico do The Band. Artefato de domínio, revisado como código. **Não é configuração.** | `priv/knowledge_base/` |
| **Arquivo de conhecimento** | Um arquivo da base. Tem um tipo, um esquema de validação, versão, identificador estável, dependências declaradas e proveniência declarada. | qualquer lugar da base |
| **Esquema de validação** | Descrição da forma exigida para um tipo de arquivo de conhecimento: campos permitidos, obrigatórios, tipos e restrições. **Não** é `Ecto.Schema` e não descreve tabela. | `priv/knowledge_base/schemas/` |
| **`schema_version`** | Versão do esquema de validação que um arquivo declara seguir. Distinta da versão do próprio conteúdo. | dentro de cada arquivo |
| **Versão do conteúdo** | Versão semântica do que o arquivo afirma. Muda quando a afirmação muda, ainda que o esquema não mude. | dentro de cada arquivo |
| **Identificador estável** | Identificador que não muda durante a vida do que ele nomeia. Renomear rótulo não muda identificador; mudar identificador é mudança incompatível. | dentro de cada arquivo |
| **Base compilada** | Representação em memória da base, produzida uma vez e consultada sem tocar o disco. | runtime |
| **Ontologia declarada** | Ontologia registrada no manifesto. | manifesto |
| **Ontologia implementada** | Ontologia com módulos e persistência no código. **Zero nesta feature** — features 003 em diante. | `lib/the_band/ontology/` |

"Ontologia declarada" não é "ontologia implementada". O manifesto listar `sro` não significa
que SRO exista em código: significa que a base contém arquivos de conhecimento sobre SRO. A
lista do manifesto é **inventário verificável** do conteúdo presente, não roteiro de intenção
— decidido em Clarifications Q1 e imposto por FR-006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Impedir que conhecimento malformado entre na base (Priority: P1)

Uma pessoa que escreve ou altera conhecimento — no futuro, a cada feature ontológica —
adiciona ou modifica um arquivo da base. Antes de o arquivo poder ser incorporado, a
plataforma verifica que ele tem forma válida, e recusa com uma mensagem que diz **qual
arquivo, qual campo e o que está errado**. Um arquivo válido é aceito sem ruído.

**Why this priority**: É o único item que, entregue isoladamente, já produz valor. Todas as
features 003 em diante escrevem arquivos de conhecimento, e escrevê-los sem verificação
significa descobrir erro semântico meses depois, dentro de um indicador errado. Sem esta
história, nenhuma outra tem sujeito.

**Independent Test**: Introduzir arquivos deliberadamente inválidos, um defeito por
arquivo, e confirmar que cada um é recusado com mensagem localizável. Introduzir um arquivo
válido e confirmar que é aceito. Entrega valor sem nenhuma das outras histórias.

**Acceptance Scenarios**:

1. **Given** a base contém um arquivo com um campo que o esquema de validação não define,
   **When** a validação é executada, **Then** ela reprova, nomeia o arquivo, nomeia o campo
   desconhecido, e a execução termina com código de falha.
2. **Given** um arquivo sem versão declarada, **When** a validação é executada, **Then** ela
   reprova nomeando a ausência.
3. **Given** um arquivo sem identificador estável, **When** a validação é executada,
   **Then** ela reprova nomeando a ausência.
4. **Given** um arquivo sem dependências declaradas, **When** a validação é executada,
   **Then** ela reprova nomeando a ausência — declarar lista vazia é diferente de omitir o
   campo, e apenas a omissão é recusada.
5. **Given** um arquivo sem proveniência declarada, **When** a validação é executada,
   **Then** ela reprova nomeando a ausência.
6. **Given** um arquivo que não é um documento YAML válido, **When** a validação é
   executada, **Then** ela reprova indicando a posição do erro de sintaxe, e **não** trata o
   arquivo como vazio nem o ignora.
7. **Given** um arquivo cujo conteúdo, embora sintaticamente válido, não é um mapeamento na
   raiz, **When** a validação é executada, **Then** ela reprova.
8. **Given** todos os arquivos da base válidos, **When** a validação é executada, **Then**
   ela aprova, relata quantos arquivos foram verificados, e termina com código de sucesso.
9. **Given** um arquivo colocado dentro da base em um local que nenhum tipo reconhece,
   **When** a validação é executada, **Then** ela reprova — arquivo dentro da base nunca é
   silenciosamente ignorado.
10. **Given** um arquivo contendo valor com forma de token, senha, chave privada ou
    credencial, **When** a validação é executada, **Then** ela reprova identificando o
    arquivo, e **não** repete o valor suspeito na mensagem.
11. **Given** a base é validada, **When** o relatório é lido, **Then** o número de arquivos
    verificados é maior que zero — validação que não encontra arquivo algum reprova em vez
    de aprovar vazia.

---

### User Story 2 - Impedir que a rede de ontologias seja violada (Priority: P1)

A constituição define quais ontologias podem depender de quais, e proíbe ciclos. Hoje isso
é texto. Quem escreve conhecimento precisa que a regra seja imposta pela plataforma, não
lembrada por quem revisa — e precisa que identificador duplicado e referência a algo
inexistente também sejam recusados, porque nenhum dos dois é detectável olhando um arquivo
por vez.

**Why this priority**: A regra de dependência entre ontologias é o que impede o modelo
semântico de degenerar em grafo emaranhado onde nada é reutilizável. Ela precisa existir
**antes** da primeira ontologia (feature 003), porque impor depois significa desmanchar
dependência já escrita. Entregue isoladamente, converte a seção "Fundamentação Ontológica"
da constituição de documentação em verificação.

**Independent Test**: Declarar uma dependência proibida, um ciclo, um identificador
duplicado e uma referência inexistente — cada um isoladamente — e confirmar que cada caso
reprova. Declarar as dependências permitidas e confirmar que são aceitas.

**Acceptance Scenarios**:

1. **Given** dois arquivos da base declarando o mesmo identificador estável, **When** a
   verificação de integridade é executada, **Then** ela reprova nomeando o identificador e
   **os dois** arquivos.
2. **Given** um arquivo que referencia um identificador que não existe em nenhum arquivo da
   base, **When** a verificação é executada, **Then** ela reprova nomeando quem referencia e
   o que foi referenciado.
3. **Given** uma cadeia de dependências entre ontologias que forma ciclo, **When** a
   verificação é executada, **Then** ela reprova exibindo o ciclo completo, e termina com
   código de falha.
4. **Given** uma dependência na direção proibida pela constituição, **When** a verificação é
   executada, **Then** ela reprova nomeando a direção e citando a regra violada.
5. **Given** as dependências permitidas pela constituição, **When** a verificação é
   executada, **Then** todas são aceitas — a verificação não é um recusador indiscriminado.
6. **Given** um arquivo que declara depender de uma ontologia ausente do manifesto,
   **When** a verificação é executada, **Then** ela reprova.
7. **Given** uma referência a identificador que existe, mas em uma ontologia que o arquivo
   não declarou como dependência, **When** a verificação é executada, **Then** ela reprova —
   dependência usada e não declarada é tão inválida quanto dependência proibida.

---

### User Story 3 - Impedir que conhecimento não verificado entre na linha principal (Priority: P2)

Quem mantém o repositório precisa da garantia de que nenhuma mudança em arquivo de
conhecimento seja incorporada sem que as verificações de conhecimento tenham passado no
servidor — não apenas na máquina de quem escreveu.

**Why this priority**: P2 por dependência, não por importância. As verificações só podem ser
registradas depois de existirem. A cláusula `Mantenedor único` da constituição torna este
registro **obrigatório**, não opcional: com zero aprovações humanas exigidas, a verificação
mecânica no servidor é a única independência que resta.

**Independent Test**: Abrir uma proposta de mudança com um arquivo de conhecimento inválido
e confirmar que a incorporação é bloqueada. Corrigir e confirmar que passa a ser possível.

**Acceptance Scenarios**:

1. **Given** as três verificações de conhecimento registradas como obrigatórias no servidor,
   **When** uma proposta de mudança contém arquivo de conhecimento inválido, **Then** a
   incorporação é bloqueada e o motivo é identificável na própria proposta.
2. **Given** uma verificação obrigatória ainda em execução, **When** se tenta incorporar,
   **Then** a incorporação é bloqueada — pendente é tratado como não aprovado.
3. **Given** todas as verificações obrigatórias aprovadas, **When** se tenta incorporar,
   **Then** a incorporação é permitida.
4. **Given** uma proposta de mudança que não toca arquivo algum de conhecimento, **When** as
   verificações executam, **Then** elas ainda executam e aprovam — a verificação não é
   condicionada ao conteúdo da mudança, porque condicioná-la criaria o caminho para
   desativá-la.

---

### User Story 4 - Consultar o conhecimento em execução sem reler o disco (Priority: P2)

A plataforma em execução precisa consultar o conhecimento — quais conceitos existem, quais
relações, quais restrições — para responder qualquer pergunta de gestão. Precisa fazer isso
sem reler e reinterpretar arquivos a cada consulta.

**Why this priority**: Sem esta história o conhecimento é um artefato que só o processo de
verificação lê, e nenhuma feature de runtime pode consumi-lo. É pré-requisito da feature 003
e de tudo que dela depende. Entregue isoladamente, permite que a 003 comece.

**Independent Test**: Consultar a base compilada repetidamente e confirmar que o número de
leituras de disco não cresce com o número de consultas. Confirmar que a base compilada
oferece o mesmo conteúdo que os arquivos declaram.

**Acceptance Scenarios**:

1. **Given** a plataforma em execução, **When** a base de conhecimento é consultada muitas
   vezes, **Then** o número de leituras de arquivo não cresce com o número de consultas.
2. **Given** a base compilada, **When** um identificador existente é consultado, **Then** o
   conteúdo devolvido corresponde ao que o arquivo declara.
3. **Given** a base compilada, **When** um identificador inexistente é consultado, **Then** a
   resposta distingue explicitamente "não existe" de "existe e está vazio".
4. **Given** um arquivo inválido na base, **When** a compilação é executada, **Then** ela
   reprova e **não** produz base compilada parcial — base parcial mentiria sobre o que o
   modelo semântico afirma.
5. **Given** a compilação concluída, **When** o resultado é inspecionado, **Then** nem o
   conjunto de exemplos reservado, nem o conteúdo proposto, nem o obsoleto fazem parte do
   conhecimento disponível em execução.

---

### User Story 5 - Verificar que o conhecimento sustenta as perguntas que afirma responder (Priority: P3)

Uma pergunta de competência declara quais conceitos e relações são necessários para
respondê-la. Quem escreve conhecimento precisa saber quando essa declaração deixou de ser
verdadeira — por exemplo, quando um conceito citado foi renomeado ou removido.

**Why this priority**: P3 porque nesta feature não existe dado algum nem persistência
ontológica, então nenhuma pergunta de competência pode ser de fato **respondida**. O que se
verifica aqui é estrutural, e apenas isso — decidido em Clarifications Q3. Tratá-la como
"responder a pergunta" seria prometer o que a feature não tem meio de cumprir.

**Independent Test**: Declarar uma pergunta de competência citando um conceito que não
existe e confirmar que a verificação reprova. Remover um conceito citado por uma pergunta
existente e confirmar que a verificação passa a reprovar.

**Acceptance Scenarios**:

1. **Given** uma pergunta de competência que cita um conceito inexistente, **When** a
   verificação é executada, **Then** ela reprova nomeando a pergunta e o conceito.
2. **Given** uma pergunta de competência que cita uma relação inexistente, **When** a
   verificação é executada, **Then** ela reprova.
3. **Given** uma pergunta de competência cujos conceitos citados existem mas pertencem a
   ontologias que ela não declara, **When** a verificação é executada, **Then** ela reprova.
4. **Given** várias perguntas de competência e uma delas insustentável, **When** a
   verificação é executada, **Then** o resultado de cada pergunta é relatado
   individualmente, e não apenas somado em um total que esconderia qual falhou.
5. **Given** nenhuma pergunta de competência na base, **When** a verificação é executada,
   **Then** ela reprova em vez de aprovar vazia.
6. **Given** a verificação aprova, **When** o relatório é lido, **Then** ele declara em seu
   próprio texto que a conferência foi estrutural e que nenhuma pergunta foi respondida com
   dados.

---

### User Story 6 - Enxergar o que mudou semanticamente entre duas versões (Priority: P3)

Quem revisa uma mudança em arquivo de conhecimento precisa enxergar **o que mudou no
significado**, não a diferença textual linha por linha. Precisa que mudança incompatível
apareça como incompatível, e não escondida no meio de reformatação.

**Why this priority**: P3 porque as features 003 em diante ainda não produziram histórico de
conhecimento para comparar. Passa a ser essencial quando houver, e construí-la depois
significa não ter registro da primeira safra de mudanças.

**Independent Test**: Produzir duas versões da base diferindo por uma mudança compatível e
uma incompatível, e confirmar que a comparação classifica cada uma corretamente e que
reformatação sem mudança de significado não aparece.

**Acceptance Scenarios**:

1. **Given** duas versões da base em que um conceito foi adicionado, **When** a comparação é
   executada, **Then** a adição é relatada e classificada como compatível.
2. **Given** duas versões em que um identificador estável foi removido ou renomeado,
   **When** a comparação é executada, **Then** a mudança é relatada e classificada como
   **incompatível**.
3. **Given** duas versões em que um campo passou a ser obrigatório onde não era, **When** a
   comparação é executada, **Then** a mudança é classificada como incompatível.
4. **Given** duas versões que diferem apenas por reformatação, reordenação de chaves ou
   comentário, **When** a comparação é executada, **Then** nenhuma mudança semântica é
   relatada.
5. **Given** uma mudança classificada como incompatível, **When** a versão declarada do
   conteúdo não foi elevada de forma condizente, **Then** a comparação sinaliza a omissão.

---

### Edge Cases

Os casos abaixo não são hipotéticos: quase todos são comportamento conhecido de
interpretadores de YAML, e cada um é um caminho pelo qual arquivo inválido pode ser aceito
em silêncio. A classe de defeito é a mesma encontrada na feature 001, em que uma checagem de
análise estática não carregava e terminava com código de sucesso.

Cada caso traz o requisito que o resolve. Os que não têm requisito estão marcados, e são
deliberados: pertencem à medição do plano, não à especificação. Lista de casos em que não se
sabe o que está decidido é uma armadilha — é assim que buraco silencioso sobrevive à revisão.

**Coerção de tipo pelo interpretador**

| Caso | Resolução |
|---|---|
| `version: 1.0` é interpretado como número, não como o texto `"1.0"`. Um arquivo com versão `1.10` compararia igual a `1.1` | FR-012 — versão e identificador são texto; recusa se a coerção mudaria o significado |
| `yes`, `no`, `on`, `off`, `y`, `n` viram booleano em interpretadores que seguem a versão 1.1 da especificação. Um rótulo `pt-BR: no` viraria `false` | FR-012 |
| `~`, `null` e campo vazio produzem ausência de valor | FR-007 — campo obrigatório com valor vazio é **violação**, não ausência, e a mensagem distingue as duas |
| Identificador iniciado por dígito, ou só com dígitos e pontos, pode ser interpretado como número | FR-051 — cada segmento começa por letra; FR-012 |

**Estrutura do documento**

| Caso | Resolução |
|---|---|
| Chave duplicada no mesmo mapeamento: a maioria dos interpretadores mantém a última em silêncio | FR-010 — recusada |
| Âncoras, apelidos (`&`, `*`) e chave de mesclagem (`<<:`): verificar campo desconhecido antes da expansão deixa um apelido contrabandear campo desconhecido | FR-011 — verificação **após** a expansão, ou recusa do recurso; a escolha fica registrada |
| Apelidos recursivos que expandem exponencialmente esgotam memória. O repositório é público e aceita propostas de mudança: uma proposta pode derrubar a verificação do servidor | FR-018 — recusa em vez de esgotar o processo |
| Múltiplos documentos YAML no mesmo arquivo, separados por `---` | FR-071 — recusado; um arquivo, um documento |
| Arquivo vazio, com apenas comentários, ou com apenas `---` | FR-071 — recusado |

**Sistema de arquivos**

| Caso | Resolução |
|---|---|
| Extensão `.yml` versus `.yaml` | FR-014 — as duas consideradas, ou a excluída é recusada |
| Marca de ordem de bytes, fim de linha estilo Windows | FR-072 — tolerados; são formatação e não mudam significado |
| Byte que não é UTF-8 válido | FR-072 — recusado |
| Ligação simbólica dentro da base apontando para fora dela | FR-072 — recusada |
| Arquivo com nome iniciado por ponto, ou diretório de metadados do sistema operacional | FR-072 — ignorado, e a contagem de ignorados é **relatada**, nunca silenciosa |
| Diretório dentro da base sem arquivo algum | FR-001 — proibido pela constituição |

**Consistência entre manifesto e conteúdo**

| Caso | Resolução |
|---|---|
| Manifesto declara ontologia sem conteúdo correspondente | FR-006 — recusado |
| Conteúdo sobre ontologia ausente do manifesto | FR-006 — recusado |
| Arquivo declara versão de esquema que nenhum esquema implementa | FR-057 — recusado, nomeando declarada e existente |
| Arquivo declara versão de esquema diferente do padrão do manifesto | FR-055 — recusado; uma versão viva por esquema |
| Manifesto declara política de validação não estrita | FR-004 — o próprio manifesto é recusado; não existe interruptor |

**Escala e limite**

| Caso | Resolução |
|---|---|
| Mensagem de erro para arquivo com centenas de violações | FR-015 — todas relatadas; parar na primeira transformaria uma correção em muitas rodadas |
| Base com muitos milhares de arquivos: cabe no orçamento de tempo? | **Aberto** — SC-012 fixa o orçamento; o número de arquivos que ele suporta é medição do plano, não decisão da especificação |
| Cadeia de dependências muito profunda, ou grafo muito denso | **Aberto** — mesma razão |

**Segredo**

| Caso | Resolução |
|---|---|
| Valor legítimo com forma de credencial — por exemplo, um exemplo de identificador externo | FR-062 a FR-065 — exceção no próprio arquivo, por campo, com justificativa; nunca em escopo maior |
| Credencial em comentário, e não em valor | FR-024 — comentário é inspecionado |

## Requirements *(mandatory)*

### Functional Requirements

**Estrutura e manifesto**

- **FR-001**: A base de conhecimento MUST existir como diretório versionado do repositório,
  contendo apenas subdiretórios que já tenham conteúdo — diretório vazio criado
  antecipadamente é proibido pela constituição.
- **FR-002**: A base MUST conter um manifesto único que registre nome, versão, idioma
  padrão, versão padrão do esquema de validação, ontologias declaradas, política de validação
  e exigência de proveniência.
- **FR-003**: O manifesto MUST ser ele mesmo validado contra um esquema de validação, com as
  mesmas exigências aplicadas a qualquer outro arquivo da base.
- **FR-004**: A política de validação estrita MUST ser incondicional. Um manifesto que
  declare validação não estrita, ou que não declare rejeição de campo desconhecido, MUST ser
  recusado. Não existe caminho, campo ou variável de ambiente que desligue a validação.
- **FR-005**: A base MUST conter um esquema de validação para cada um dos nove tipos de
  arquivo de conhecimento: ontologia, conceito, relação, mapeamento, pergunta de competência,
  necessidade de informação, medida, glossário e definição de conector.
- **FR-006**: A lista de ontologias do manifesto MUST ser inventário do conteúdo presente na
  base, e a correspondência MUST ser verificada nos **dois** sentidos: ontologia declarada sem
  conteúdo correspondente MUST reprovar, e conteúdo sobre ontologia não declarada MUST
  reprovar. O manifesto MUST NOT registrar intenção futura — o roteiro das ontologias vive na
  constituição e no guia operacional.

**Versão do esquema de validação**

- **FR-055**: Existe exatamente **uma** versão viva de cada esquema de validação. Todo arquivo
  MUST declarar a versão de esquema igual ao padrão do manifesto, e divergência MUST reprovar.
- **FR-056**: Elevar a versão de um esquema MUST migrar todos os arquivos daquele tipo e subir
  o padrão do manifesto no mesmo conjunto de mudanças. O custo aceito é um conjunto de mudanças
  grande quando a base crescer; o que se compra é a impossibilidade de duas formas válidas do
  mesmo tipo conviverem, e de quem lê a base precisar descobrir qual delas está diante.
- **FR-057**: Arquivo que declare versão de esquema que nenhum esquema implementa MUST
  reprovar, e a mensagem MUST nomear a versão declarada e a existente.

**Validação por arquivo**

- **FR-007**: Todo arquivo da base MUST declarar o esquema de validação que segue, a versão
  do seu conteúdo, um identificador estável, suas dependências e sua proveniência. A ausência
  de qualquer um dos cinco MUST reprovar. Campo obrigatório presente com valor vazio, nulo ou
  ausente MUST ser tratado como **violação**, não como ausência, e a mensagem MUST distinguir
  as duas — "campo não declarado" e "campo declarado sem valor" são erros diferentes de quem
  escreve, e confundi-los faz a pessoa procurar no lugar errado.
- **FR-008**: A validação MUST recusar qualquer campo não definido pelo esquema, em qualquer
  nível de aninhamento.
- **FR-009**: A validação MUST recusar arquivo que não seja um documento YAML válido, e MUST
  indicar a posição do erro. Erro de sintaxe MUST NOT ser tratado como arquivo vazio.
- **FR-010**: A validação MUST recusar chave duplicada no mesmo mapeamento, ainda que o
  interpretador de YAML a aceite silenciosamente.
- **FR-011**: A validação MUST aplicar a verificação de campo desconhecido **após** a
  expansão de âncoras, apelidos e chaves de mesclagem, ou MUST recusar o uso desses recursos.
  A alternativa escolhida MUST ser registrada.
- **FR-012**: A validação MUST tratar valor de versão e valor de identificador como texto,
  independentemente de o interpretador de YAML poder coagi-los a número ou booleano, e MUST
  recusar arquivo em que a coerção mudaria o significado declarado.
- **FR-013**: A validação MUST recusar arquivo situado dentro da base cujo local ou tipo não
  seja reconhecido. Arquivo dentro da base MUST NOT ser silenciosamente ignorado. A **única**
  exclusão admitida é a de FR-072, e ela não é silenciosa: os ignorados são contados e relatados.
- **FR-014**: A validação MUST considerar as duas extensões usuais de arquivo YAML, ou MUST
  recusar a que não considerar. Uma extensão silenciosamente ignorada é proibida.
- **FR-015**: A validação MUST relatar todas as violações encontradas em uma execução, não
  apenas a primeira.
- **FR-016**: A validação MUST relatar quantos arquivos verificou, e MUST reprovar quando
  esse número for zero. Aprovação sem ter verificado nada é proibida.
- **FR-017**: A validação MUST terminar com código de falha quando reprovar, e com código de
  sucesso apenas quando tiver efetivamente verificado a base e não encontrado violação.
- **FR-018**: A validação MUST ser resistente a arquivo cuja expansão consuma memória de
  forma descontrolada, recusando-o em vez de esgotar o processo.
- **FR-071**: Um arquivo MUST conter exatamente um documento, com um mapeamento na raiz.
  Múltiplos documentos no mesmo arquivo, arquivo vazio, arquivo com apenas comentários e arquivo
  com apenas o separador de documento MUST reprovar.
- **FR-072**: A validação MUST tolerar marca de ordem de bytes e fim de linha estilo Windows,
  que são formatação e não mudam significado; MUST recusar byte que não seja UTF-8 válido; MUST
  recusar ligação simbólica que aponte para fora da base; e MUST ignorar arquivo cujo nome comece
  por ponto — relatando **quantos** foram ignorados, porque exclusão que não é contada é
  indistinguível de arquivo que não foi encontrado.

**Idioma**

- **FR-058**: Todo rótulo e toda definição MUST declarar o texto em português do Brasil **e**
  em inglês. A ausência de qualquer um dos dois MUST reprovar. A base nasce bilíngue: as
  ontologias de referência são publicadas em inglês, e sem o texto em inglês nenhuma definição
  é conferível contra a fonte que a originou.
- **FR-059**: Os idiomas exigidos MUST ser registrados no manifesto, e a validação MUST derivar
  a exigência desse registro em vez de fixá-la no código.
- **FR-060**: Remover um idioma do conjunto exigido MUST ser classificado como mudança
  incompatível pela comparação entre versões. Sem isso, o registro do manifesto seria um
  interruptor: bastaria retirar o inglês para uma proposta de mudança incompleta passar.
- **FR-061**: Idioma declarado em um arquivo e ausente do registro do manifesto MUST reprovar —
  o campo de rótulo não é dicionário livre.

**Forma e propriedade do identificador estável**

- **FR-051**: Identificador estável MUST usar apenas minúsculas, dígitos, sublinhado e o
  ponto como separador de segmento. Cada segmento MUST começar por letra. Maiúscula, hífen,
  espaço, barra e acento MUST reprovar.
- **FR-052**: A propriedade de um identificador MUST ser determinada pelo campo de ontologia
  declarado no arquivo, e MUST NOT ser inferida do texto do identificador. FR-023 opera sobre
  esse campo.
- **FR-053**: Em arquivo que declara uma ontologia, o primeiro segmento do identificador MUST
  ser igual ao identificador dessa ontologia. Divergência MUST reprovar — um conceito que
  declara pertencer a uma ontologia e se identifica com o prefixo de outra é ambíguo quanto ao
  dono.
- **FR-054**: Arquivo de mapeamento, de necessidade de informação e de medida MUST NOT ser
  obrigado a prefixo de ontologia. Seu primeiro segmento nomeia fornecedor ou domínio, e a
  ontologia alvo é declarada em campo próprio.

**Integridade cruzada e rede de ontologias**

- **FR-019**: A verificação de integridade MUST recusar identificador estável declarado por
  mais de um arquivo, nomeando o identificador e todos os arquivos envolvidos.
- **FR-020**: A verificação MUST recusar referência a identificador que não exista na base,
  nomeando quem referencia e o que foi referenciado.
- **FR-021**: A verificação MUST detectar ciclo na dependência entre ontologias, exibir o
  ciclo completo e reprovar.
- **FR-022**: A verificação MUST recusar dependência entre ontologias em direção proibida
  pela constituição, e MUST aceitar as direções permitidas. Ambos os sentidos MUST ser
  verificados por teste, porque uma verificação que recusa tudo passaria por um teste que só
  cobrisse o caso proibido.
- **FR-023**: A verificação MUST recusar uso de identificador pertencente a ontologia que o
  arquivo não declarou como dependência.

**Segredo**

- **FR-024**: A validação MUST recusar arquivo que contenha valor com forma de token, senha,
  chave privada, credencial ou cadeia de conexão, inclusive em comentário.
- **FR-025**: A mensagem de recusa por suspeita de segredo MUST identificar arquivo e
  posição, e MUST NOT reproduzir o valor suspeito — reproduzi-lo o copiaria para o registro
  de execução, que neste repositório é público.
- **FR-062**: Uma exceção à detecção de segredo MUST ser declarada no próprio arquivo em que o
  valor está, MUST nomear o campo exato, e MUST trazer justificativa. Exceção sem justificativa
  MUST reprovar.
- **FR-063**: O escopo de uma exceção MUST ser um campo de um arquivo. MUST NOT existir exceção
  por arquivo inteiro, por diretório, por padrão textual, nem global. Exceção que possa ser
  aplicada em massa é interruptor com outro nome.
- **FR-064**: Exceção que aponte para campo inexistente MUST reprovar. Exceção órfã é resíduo
  que continua autorizando o que já não precisa de autorização.
- **FR-065**: A validação MUST relatar o total de exceções declaradas na base em cada execução.
  Crescimento do número de exceções MUST ser visível, porque exceção que ninguém conta deixa de
  ser exceção.

**Estado de maturidade**

- **FR-066**: Todo arquivo de conhecimento MUST declarar seu estado de maturidade entre
  **proposto**, **ativo** e **obsoleto**. A ausência MUST reprovar, e nenhum outro valor MUST
  ser aceito.
- **FR-067**: Apenas arquivo **ativo** MUST entrar na base compilada. Proposto e obsoleto são
  validados com o mesmo rigor e MUST NOT ser oferecidos ao runtime. Esta exclusão é deliberada e
  MUST NOT ser confundida com a representação parcial que FR-028 proíbe: parcial é o que sobra
  de uma compilação que falhou; isto é o resultado íntegro de uma compilação que respeitou o
  estado declarado.
- **FR-068**: Arquivo **obsoleto** MUST declarar a versão em que foi descontinuado, a razão, e
  o que o substitui — ou a afirmação explícita de que nada o substitui. Obsoleto sem substituto
  declarado nem afirmação de ausência MUST reprovar.
- **FR-069**: Referência a identificador de arquivo obsoleto MUST reprovar. Conhecimento em
  vigor MUST NOT depender de conhecimento descontinuado.
- **FR-070**: A comparação entre versões MUST sinalizar a remoção de um arquivo que não tenha
  passado pelo estado obsoleto. O caminho de descontinuação existe para avisar quem depende
  antes de quebrar, e pular esse caminho MUST ficar visível.

**Compilação e disponibilidade em execução**

- **FR-026**: A base MUST ser transformada em uma representação consultável em execução.
- **FR-027**: Consulta à base em execução MUST NOT provocar leitura de disco a cada
  requisição.
- **FR-028**: A compilação MUST reprovar quando qualquer arquivo for inválido, e MUST NOT
  produzir representação parcial.
- **FR-029**: A consulta MUST distinguir "identificador não existe" de "existe e não tem
  conteúdo".
- **FR-030**: A estratégia de carregamento MUST ser registrada em ADR, declarando
  explicitamente o custo aceito — invisibilidade de mudança sem recompilar, ou necessidade de
  invalidação explícita.

**Perguntas de competência**

- **FR-031**: A verificação de perguntas de competência MUST recusar pergunta que cite
  conceito ou relação inexistente.
- **FR-032**: A verificação MUST recusar pergunta que cite conceito pertencente a ontologia
  que ela não declara.
- **FR-033**: A verificação MUST relatar o resultado de cada pergunta individualmente, e MUST
  NOT relatar apenas um total — total esconde qual pergunta deixou de se sustentar.
- **FR-034**: A verificação MUST reprovar quando não houver pergunta de competência a
  verificar.
- **FR-035**: A verificação MUST ser **estrutural** nesta feature: ela confere que o
  conhecimento citado por cada pergunta existe e é alcançável, e não que a pergunta seja
  respondível com dados — não há dado nem persistência ontológica. Nenhuma linguagem de regra
  declarativa é construída nesta feature. O relatório MUST declarar essa limitação em seu
  próprio texto, para que ninguém o leia como prova de que a pergunta foi respondida.

**Comparação entre versões**

- **FR-036**: A comparação MUST relatar adição, remoção, renomeação e alteração de conteúdo
  de arquivos de conhecimento.
- **FR-037**: A comparação MUST classificar cada mudança como compatível ou incompatível, e
  MUST tratar remoção ou renomeação de identificador estável como incompatível.
- **FR-038**: A comparação MUST NOT relatar mudança quando a diferença for apenas de
  formatação, ordem de chaves ou comentário.
- **FR-039**: A comparação MUST sinalizar mudança incompatível cuja versão declarada não
  tenha sido elevada de forma condizente.
- **FR-040**: A comparação MUST ser feita entre **duas referências do histórico do
  repositório**, reconstruindo a base em cada uma. A comparação MUST NOT depender de artefato
  gerado e versionado que descreva o estado semântico, porque tal artefato pode ficar
  desatualizado e exigiria sua própria verificação.

**Conteúdo mínimo que a maquinaria verifica**

- **FR-041**: A base MUST conter conteúdo suficiente para exercitar todos os nove esquemas de
  validação pelo caminho de aceitação, e MUST exercitar os três estados de maturidade e os dois
  idiomas obrigatórios. Maquinaria sem sujeito não tem requisito verificável — a mesma classe de
  problema encontrada na feature 001.
- **FR-042**: Esse conteúdo MUST usar um espaço de identificadores reservado que não possa
  colidir com identificador de ontologia real, e MUST ser reconhecível como exemplo por quem
  o encontrar sem contexto.
- **FR-043**: Os casos de recusa MUST ser mantidos fora da base, porque arquivo inválido
  dentro da base faria a verificação obrigatória reprovar permanentemente.
- **FR-044**: O conteúdo de exemplo MUST NOT fazer parte do conhecimento disponível em
  execução, e essa exclusão MUST ser verificada por teste.

**Governança**

- **FR-045**: As três verificações de conhecimento exigidas pela constituição MUST ser
  registradas como verificações obrigatórias de status no servidor, somando-se às cinco já
  existentes.
- **FR-046**: A incorporação MUST ser bloqueada quando qualquer verificação obrigatória
  estiver reprovada, ausente ou pendente.
- **FR-047**: As verificações MUST executar em toda proposta de mudança, independentemente de
  ela tocar arquivo de conhecimento — condicioná-las ao conteúdo criaria o caminho para
  desativá-las.
- **FR-048**: A escolha da biblioteca de interpretação de YAML MUST ser registrada em ADR,
  com pesquisa de manutenção, segurança e compatibilidade, e MUST NOT ratificar por
  conveniência uma biblioteca já presente no projeto como dependência transitiva de
  ferramenta de desenvolvimento.
- **FR-049**: A pesquisa da biblioteca MUST exercitar o caminho que a aplicação realmente
  usa: validação estrita, mensagem de erro localizável, comportamento diante dos casos de
  coerção e de estrutura listados em Edge Cases, e desempenho com muitos arquivos. A feature
  001 concluiu erradamente sobre uma versão de migração por tê-la testado em configuração
  reduzida; a pesquisa MUST NOT repetir isso.
- **FR-050**: A ausência de ontologia implementada MUST continuar verificada por teste. O
  teste que hoje garante a ausência da base de conhecimento MUST ser substituído por um que
  garanta a ausência apenas dos módulos e diretórios de ontologia.

### Key Entities

- **Manifesto**: Registro único do que a base é. Nome, versão, idioma padrão, versão padrão
  do esquema de validação, ontologias declaradas, política de validação, exigência de
  proveniência. É o ponto de entrada e é ele mesmo validado.
- **Esquema de validação**: Descrição da forma exigida de um tipo de arquivo de
  conhecimento. Nove tipos. Estrito por definição: campo não descrito é campo recusado.
- **Arquivo de conhecimento**: Unidade da base. Possui tipo, esquema de validação declarado,
  versão de conteúdo, identificador estável, dependências declaradas e proveniência
  declarada.
- **Identificador estável**: Nome que não muda durante a vida do que ele nomeia. Único em
  toda a base. Minúsculas, dígitos e sublinhado, em segmentos separados por ponto, cada
  segmento começando por letra. Sua remoção ou renomeação é mudança incompatível. **Não** é o
  que determina a quem ele pertence — isso vem do campo de ontologia declarado no arquivo.
- **Declaração de dependência**: Conjunto de ontologias das quais um arquivo depende. Sujeita
  às direções permitidas pela constituição. Lista vazia declarada é diferente de campo
  omitido.
- **Declaração de proveniência**: Origem do que o arquivo afirma — tipo de fonte, documento
  ou referência. Obrigatória em todo arquivo.
- **Grafo de conhecimento declarado**: Relação de dependência entre ontologias e de
  referência entre identificadores, derivada dos arquivos. Acíclico e conforme às direções
  permitidas.
- **Estado de maturidade**: Proposto, ativo ou obsoleto. Declarado por todo arquivo. Só ativo
  chega ao runtime. Obsoleto permanece na base e declara quando foi descontinuado, por quê e o
  que o substitui — é o que dá um passo de aviso antes da remoção.
- **Exceção à detecção de segredo**: Autorização para um valor com forma de credencial em **um**
  campo de **um** arquivo, com justificativa. Não existe em escopo maior que isso.
- **Base compilada**: Representação consultável em execução, produzida a partir dos arquivos
  válidos e **ativos**. Nunca parcial. Não inclui o conteúdo de exemplo, nem o proposto, nem o
  obsoleto.
- **Conjunto de exemplos reservado**: Conteúdo que exercita os nove esquemas pelo caminho de
  aceitação, em espaço de identificadores que não colide com ontologia real, e ausente da
  base compilada.
- **Relatório de diferença semântica**: Lista de mudanças entre duas versões da base, cada
  uma classificada como compatível ou incompatível.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% dos arquivos da base são verificados contra um esquema de validação.
  Nenhum arquivo dentro da base fica sem verificação, e o relatório informa a contagem.
- **SC-002**: Para cada uma das formas de invalidez listadas em Edge Cases existe um caso que
  a exercita e é recusado. A cobertura é declarada caso por caso, e o que não for coberto é
  declarado como não coberto.
- **SC-003**: Nenhuma das cinco declarações obrigatórias — esquema, versão, identificador
  estável, dependências, proveniência — pode ser omitida sem que a validação reprove. Cinco
  casos, cinco recusas.
- **SC-004**: Identificador duplicado e referência inexistente são recusados em 100% dos
  casos exercitados, e a mensagem permite localizar os arquivos envolvidos sem busca manual.
- **SC-005**: Todas as direções de dependência proibidas pela constituição são recusadas, e
  todas as permitidas são aceitas. Ambos os conjuntos são exercitados — recusar tudo não
  passa.
- **SC-006**: Ciclo de dependência é detectado e faz a verificação reprovar, com o ciclo
  completo exibido.
- **SC-007**: Zero credenciais em qualquer arquivo da base, verificado automaticamente, com o
  conjunto de formatos detectados declarado e a taxa de falso positivo medida sobre o
  conteúdo real da base.
- **SC-008**: Cada uma das cinco tarefas de conhecimento tem seu comportamento verificado por
  teste, tanto no caminho de aprovação quanto no de reprovação, e nenhuma delas termina com
  código de sucesso quando não conseguiu fazer o que se propõe. Esta é a classe de defeito
  que a feature 001 encontrou na análise estática.
- **SC-009**: A incorporação é bloqueada quando qualquer uma das três verificações de
  conhecimento está reprovada, ausente ou pendente, provado por tentativa real de
  incorporação — não por leitura de configuração.
- **SC-010**: O número de leituras de disco não cresce com o número de consultas à base em
  execução, medido com um número de consultas grande o bastante para que a diferença seja
  inequívoca.
- **SC-011**: A comparação entre versões classifica corretamente mudança compatível e
  incompatível, e não relata mudança alguma quando a diferença é apenas de formatação.
- **SC-012**: A execução completa dos portões de qualidade, agora com oito verificações,
  continua dentro de dez minutos em ambiente sem cache — o mesmo orçamento estabelecido na
  feature 001, agora com três verificações a mais.
- **SC-013**: A mensagem de recusa permite que uma pessoa localize e corrija o problema
  **sem** abrir o código da validação: nomeia arquivo, posição e o que se esperava.
  Verificado por leitura das mensagens produzidas, não por inspeção do código que as gera.
- **SC-014**: A escolha da biblioteca de YAML e a estratégia de carregamento estão cada uma
  registrada em ADR, com as alternativas consideradas e a medição que sustentou a decisão,
  incluindo o que foi testado e rejeitado.
- **SC-015**: Zero ontologias implementadas nesta entrega, verificado por teste que reprova
  se módulo ou diretório ontológico aparecer.
- **SC-016**: A gramática do identificador é exercitada nos dois sentidos: formas válidas são
  aceitas e cada forma inválida — maiúscula, hífen, espaço, barra, acento, segmento iniciado
  por dígito, e prefixo divergente da ontologia declarada — é recusada. Recusar tudo não passa.
- **SC-017**: Nenhum arquivo da base declara versão de esquema diferente do padrão do
  manifesto, e um arquivo que a declare é recusado. Zero versões de esquema convivendo.
- **SC-018**: 100% dos rótulos e definições da base declaram os dois idiomas exigidos. A
  omissão de qualquer um é recusada, e a remoção de um idioma do conjunto exigido é classificada
  como mudança incompatível.
- **SC-019**: Os três estados de maturidade são exercitados. Proposto e obsoleto são validados
  com o mesmo rigor e estão ausentes da base compilada; obsoleto sem substituto declarado nem
  afirmação de ausência é recusado; referência a obsoleto é recusada; e a remoção que não passou
  por obsoleto é sinalizada pela comparação.
- **SC-020**: Toda exceção à detecção de segredo declarada na base tem justificativa e aponta
  para campo existente. O total de exceções é relatado em cada execução, e é conhecido — não
  estimado.

## Assumptions

Cada suposição abaixo é uma decisão tomada por ausência de definição explícita na descrição,
com a razão registrada. Onde a razão contraria um exemplo do documento de referência, isso
está dito.

- **Conteúdo mínimo**: a maquinaria é exercitada por duas fontes distintas, e não por uma. O
  caminho de aceitação usa conteúdo real dentro da base, em espaço de identificadores
  reservado, porque só assim os nove esquemas são exercitados por algo que a verificação
  obrigatória de fato lê. O caminho de recusa usa material mantido fora da base, porque
  arquivo inválido dentro dela faria a verificação obrigatória reprovar para sempre. Foram
  descartadas: validar apenas o manifesto, que deixaria oito dos nove esquemas sem sujeito; e
  manter tudo fora da base, que deixaria a base entregue praticamente vazia e o caminho de
  aceitação verificado apenas contra material de teste.
- **Exemplos fora do runtime**: o conteúdo de exemplo é lido pela validação e excluído da
  base compilada. A alternativa — incluí-lo — faria a plataforma responder consultas com
  conceitos que não existem no mundo, e faria qualquer indicador derivado deles inválido. A
  exclusão é verificada por teste, porque exclusão não verificada é suposição.
- **Validação estrita incondicional**: o campo de política no manifesto é declarativo, não é
  interruptor. Valor diferente de estrito faz o manifesto ser recusado. A razão é a classe de
  defeito encontrada na feature 001: verificação que pode ser desligada silenciosamente
  termina desligada.
- **Idioma**: o idioma padrão da base é o português do Brasil, e o inglês é **igualmente
  obrigatório** em rótulo e definição — decidido em Clarifications Q6, com o custo aceito
  registrado lá. Identificadores são estáveis e independentes de idioma, e não são traduzidos.
- **Sem extensão por Tenant**: os arquivos de conhecimento são globais, conforme a
  constituição. Nenhum mecanismo de extensão por Tenant é construído nesta feature, e nenhum
  campo é reservado antecipadamente para ele.
- **Orçamento de tempo**: as três novas verificações somam-se às cinco existentes dentro do
  mesmo orçamento de dez minutos. Se a medição mostrar que não cabem, a alternativa a
  considerar é a ordem de execução, nunca reduzir o que é verificado.
- **Uma linha de trabalho**: esta feature entra por uma única linha de trabalho, com uma
  proposta de mudança por história, como a feature 001, e não mistura features independentes.

## Dependencies

- **Feature 001, concluída**: a aplicação, os cinco portões de qualidade, o registro de
  verificações obrigatórias no servidor e a proteção da linha principal já existem. Esta
  feature acrescenta três verificações ao mecanismo existente, não o cria.
- **Constituição, versão 2.0.0**: o princípio VIII define o que a base de conhecimento é; a
  seção Fundamentação Ontológica define as direções de dependência permitidas e proibidas; a
  cláusula `Mantenedor único` torna o registro das verificações obrigatórias no servidor
  indispensável.
- **Nenhuma dependência externa nova além da biblioteca de interpretação de YAML**, cuja
  escolha é objeto de pesquisa e ADR nesta feature.
- **Bloqueia**: feature 003 e todas as features ontológicas. Nenhuma ontologia pode ser
  escrita antes de existir a verificação que impede escrevê-la errado.

## Clarifications

### Sessão 2026-08-05

| # | Pergunta | Decisão | Requisito |
|---|---|---|---|
| Q1 | A lista de ontologias do manifesto é inventário ou roteiro? | **Inventário verificável** | FR-006 |
| Q2 | Contra o que a comparação entre versões compara? | **Duas referências do histórico do repositório** | FR-040 |
| Q3 | O que a verificação de perguntas de competência abrange? | **Só estrutural**, sem linguagem de regra | FR-035 |
| Q4 | Que forma um identificador pode ter, e quem determina a quem ele pertence? | **Gramática fixa; dono pelo campo de ontologia declarado**, não pelo texto do identificador | FR-051 a FR-054 |
| Q5 | A base admite versões diferentes do mesmo esquema convivendo? | **Não. Uma versão viva por esquema**; elevar migra todos os arquivos do tipo | FR-055 a FR-057 |
| Q6 | Rótulo e definição exigem quais idiomas? | **Português do Brasil e inglês, os dois obrigatórios** | FR-058 a FR-061 |
| Q7 | Como se registra exceção à detecção de segredo? | **No próprio arquivo, por campo, com justificativa** — sem exceção por arquivo, diretório, padrão ou global | FR-062 a FR-065 |
| Q8 | Arquivo de conhecimento declara estado de maturidade? | **Sim, nos nove tipos**: proposto, ativo, obsoleto. Só ativo entra na base compilada | FR-066 a FR-070 |

### Registro detalhado: inventário, não roteiro

O documento de referência mostra um manifesto listando as doze ontologias. Nesta feature
nenhuma existe.

Listar doze ontologias inexistentes tornaria impossível verificar mecanicamente a
correspondência entre manifesto e conteúdo: a verificação teria de tolerar declaração sem
conteúdo, e "manifesto declara ontologia que não existe" deixaria de ser detectável para
sempre — não apenas nesta feature. Perder-se-ia metade da verificação em troca de registrar
uma intenção que já está registrada em dois outros lugares.

**Decidido**: a lista é inventário. A correspondência é verificada nos dois sentidos. Cada
feature ontológica acrescenta sua ontologia ao manifesto no mesmo conjunto de mudanças que
acrescenta o conteúdo — o que também dá ao manifesto o papel de registro do que a base
realmente cobre.

**Rejeitado**: listar as doze desde já, pela razão acima. **Rejeitado**: dois campos
separados, um verificável e outro de intenção — resolveria, mas acrescenta ao manifesto um
campo que nada verifica, para duplicar um roteiro que a constituição e o guia operacional já
mantêm.

**Consequência**: o exemplo de manifesto do documento de referência não é seguido
literalmente neste ponto, e a divergência é deliberada.

### Registro detalhado: comparação entre referências do histórico

**Decidido**: a comparação reconstrói a base em duas referências do repositório e confronta
as duas. Isso responde à pergunta que quem revisa faz de fato — "o que esta proposta muda no
significado?" — e não introduz artefato novo a manter em sincronia.

**Rejeitado**: um retrato do estado semântico gravado como artefato versionado. Tem uma
vantagem real, que é ficar visível no próprio diff da proposta de mudança. Foi rejeitado
porque um artefato gerado e versionado pode ficar desatualizado, e detectar isso exigiria uma
verificação a mais — mais uma coisa que pode reprovar silenciosamente, que é a classe de
defeito que esta feature existe para evitar.

**Rejeitado**: comparar apenas os campos de versão declarados nos arquivos. Diria que algo
mudou e nunca o quê, nem detectaria identificador removido — inútil para revisão semântica,
que é a razão de existir da tarefa.

### Registro detalhado: verificação estrutural, e a limitação declarada

**Decidido**: nesta feature a verificação confere que os conceitos e relações citados por
cada pergunta de competência existem e pertencem a ontologias declaradas. Nada mais. O
relatório declara essa limitação no próprio texto.

**Rejeitado**: construir uma linguagem de regra declarativa nesta feature. Projetar uma
linguagem antes de existir conhecimento real para exercitá-la produziria uma linguagem
ajustada a exemplos inventados. Fica para a feature que tiver conteúdo de verdade.

**Rejeitado**: verificar as restrições declaradas nos conceitos. Nesta feature os únicos
conceitos são os do conjunto de exemplos, então a verificação atestaria apenas que os
exemplos são consistentes consigo mesmos.

**Risco aceito e registrado**: a tarefa se chama "verificar perguntas de competência" e não
verifica que alguma pergunta seja respondível. Quem ler o nome sem ler o relatório pode
concluir mais do que a verificação garante. É por isso que FR-035 exige a limitação **dentro
do relatório**, e não apenas nesta especificação.

### Registro detalhado: gramática do identificador e de onde vem a propriedade

O documento de referência tem identificadores que **não** começam por ontologia:
`github.pull_request.to.cmpo.change_request` começa por fornecedor, e
`review.time_to_first_review` por palavra de domínio. Uma regra que exigisse prefixo de
ontologia em todo identificador recusaria três dos nove tipos de arquivo.

**Decidido**: minúsculas, dígitos e sublinhado, em segmentos separados por ponto, cada
segmento começando por letra. A propriedade vem do **campo de ontologia declarado no
arquivo**, não do texto do identificador — é sobre esse campo que FR-023 opera. Onde o arquivo
declara ontologia, o primeiro segmento tem de coincidir com ela; onde não declara, não há
obrigação de prefixo.

**Rejeitado**: exigir que todo primeiro segmento nomeie algo registrado no manifesto,
acrescentando um registro de espaços de fornecedor e de domínio. Fecharia o caso de
identificador órfão nos nove tipos, e foi rejeitado por acrescentar ao manifesto um registro
que a feature 002 não tem conteúdo para exercitar — nenhum fornecedor existe até a feature
024. Fica disponível como reforço futuro.

**Rejeitado**: apenas unicidade, sem gramática. Deixaria FR-023 sem base para operar, e
permitiria `sro.user_story`, `SRO.UserStory` e `sro/user_story` coexistindo como três coisas
distintas. Também deixaria `1.0` como identificador aceitável, que é exatamente o caso de
coerção que FR-012 recusa.

### Registro detalhado: uma versão viva por esquema

**Decidido**: todo arquivo declara a versão de esquema igual ao padrão do manifesto. Elevar um
esquema migra todos os arquivos daquele tipo no mesmo conjunto de mudanças.

**Custo aceito**: quando a base crescer, elevar um esquema produzirá um conjunto de mudanças
grande. **O que se compra**: nunca existem duas formas válidas do mesmo tipo, e quem lê a base
nunca precisa descobrir qual delas está diante — nem o validador, nem a comparação semântica,
nem quem revisa.

**Rejeitado**: janela de convivência declarada no manifesto. Permitiria migração gradual, e foi
rejeitado porque multiplica o número de formas válidas simultâneas por tipo, e a comparação
semântica passaria a comparar arquivos de formas diferentes — onde "mudou de forma" e "mudou de
afirmação" ficam entrelaçados.

**Rejeitado**: não versionar esquema. Contraria o documento de referência e apagaria a distinção
entre mudança de forma e mudança de afirmação, que é justamente o que a comparação semântica
precisa separar.

### Registro detalhado: base bilíngue, com o custo declarado

**Decidido**: português do Brasil e inglês são **os dois** obrigatórios em rótulo e definição.

**Razão**: as ontologias de referência — UFO, SEON e a rede — são publicadas em inglês. Sem o
texto em inglês, nenhuma definição é conferível contra a fonte que a originou, e a revisão
semântica perde seu instrumento principal.

**Custo aceito, e ele é real**: dobra o trabalho de escrita nas doze ontologias, e nenhuma
feature da 003 em diante pode entregar sem tradução revisada. A recomendação apresentada era
exigir só o idioma padrão, justamente por esse custo. **A escolha foi deliberada, contra a
recomendação, e o custo fica registrado aqui para que não seja redescoberto como surpresa na
003.**

**Salvaguarda**: o conjunto de idiomas exigidos vive no manifesto, e retirar um idioma dele é
classificado como mudança incompatível (FR-060). Sem isso, o registro seria um interruptor:
bastaria retirar o inglês para uma proposta de mudança incompleta passar.

**Rejeitado**: rótulo e definição como texto simples, sem chave de idioma. Acrescentar idioma
depois seria mudança incompatível de forma em todo arquivo da base, de uma vez.

### Registro detalhado: exceção de segredo por campo, nunca em massa

**Decidido**: a exceção mora no arquivo em que o valor está, nomeia o campo exato, e traz
justificativa obrigatória. Vale para aquele campo e nada mais.

**Razão**: a exceção fica visível na revisão da própria mudança que a introduz. Não existe
exceção por arquivo, por diretório, por padrão textual nem global — qualquer uma dessas pode ser
aplicada em massa, e o que se aplica em massa é interruptor com outro nome. Neste repositório,
que é público, a falha dessa verificação custa vazamento, não achado.

**Salvaguardas**: exceção que aponte para campo inexistente reprova (FR-064), porque exceção
órfã continua autorizando o que já não precisa de autorização. E a validação relata o total de
exceções da base em cada execução (FR-065), porque exceção que ninguém conta deixa de ser
exceção.

**Rejeitado**: lista central de exceções. É auditável num só lugar, o que é vantagem real, e foi
rejeitada porque quem revisa o arquivo de conhecimento não veria que ele tem exceção — e a lista
envelheceria apontando para campos removidos, exigindo sua própria verificação.

**Rejeitado**: nenhuma exceção. É a regra mais forte e sem contorno, e foi rejeitada porque o
padrão de detecção passaria a limitar o que a base consegue dizer: documentar o formato de
identificador de um fornecedor ficaria restrito a descrição indireta.

### Registro detalhado: estado de maturidade e o caminho de descontinuação

**Decidido**: os nove tipos declaram estado — proposto, ativo ou obsoleto. Só ativo entra na base
compilada. Obsoleto permanece na base, declara em que versão foi descontinuado, por quê, e o que
o substitui.

**Razão**: sem estado, retirar um conceito é remoção direta, e quem dependia dele descobre quando
a verificação reprova. Com estado, existe um passo para avisar antes de quebrar. A comparação
entre versões sinaliza remoção que não passou por obsoleto (FR-070), para que o caminho não seja
apenas disponível, mas o esperado.

**Consequência sobre FR-028**: excluir proposto e obsoleto da base compilada **não** é a
representação parcial que FR-028 proíbe. Parcial é o que sobra de uma compilação que falhou;
isto é o resultado íntegro de uma compilação que respeitou o estado declarado. A distinção está
escrita em FR-067 porque, sem ela, os dois requisitos se contradizem na leitura.

**Rejeitado**: estado só em mapeamento, como no documento de referência. Segue a fonte
literalmente e custa menos campo em oito dos nove esquemas, e foi rejeitado porque deixaria
conceito e relação — o que mais é referenciado, e portanto o que mais quebra ao ser removido —
sem caminho de descontinuação.

**Rejeitado**: sem estado algum. Acrescentá-lo depois seria mudança de forma nos nove esquemas e
em todo arquivo da base, simultaneamente.

## Out of Scope

Registrado explicitamente porque a fronteira desta feature é estreita e fácil de atravessar
sem perceber.

- Qualquer ontologia real: UFO, SEON, EO, SPO, SysSwO, RSRO, CMPO, ROoST, QAPO, OSDEF,
  Continuum, SRO, CIRO e CDRO pertencem à feature 003 em diante. Nenhum conceito, relação ou
  restrição de ontologia real é escrito aqui.
- A infraestrutura comum dos módulos ontológicos, que é a feature 003.
- Qualquer conector, consulta a fornecedor, mapeamento real de fonte externa ou coleta de
  dado. O esquema de validação de mapeamento e de definição de conector é criado; nenhum
  mapeamento real é escrito.
- Qualquer necessidade de informação, medida, indicador ou painel real. Os esquemas são
  criados; o conteúdo pertence às features 031 e 032.
- **Linguagem de regra declarativa** e o diretório de regras da base — decidido em
  Clarifications Q3. Projetar uma linguagem de regra antes de existir conhecimento real para
  exercitá-la a ajustaria a exemplos inventados. Nenhum esquema de validação de regra é criado,
  e o diretório não é criado vazio.
- Extensão de conhecimento por Tenant.
- Qualquer alteração no isolamento por Tenant, na verificação de saúde ou no trabalho
  assíncrono entregues pela feature 001.
- Interface de usuário para a base de conhecimento.
