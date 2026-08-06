# ADR-0005 — `yaml_elixir` para construir, e um portão de tokens antes dela

- **Status**: aceita
- **Data**: 2026-08-06
- **Feature**: 002 — Infraestrutura da base de conhecimento YAML
- **Requisitos**: FR-009, FR-010, FR-011, FR-012, FR-018, FR-048, FR-049, FR-071, FR-072, FR-092
- **Decide**: qual biblioteca interpreta os YAMLs da base de conhecimento, e o que ela **não** resolve
- **Evidência**: [research.md](../../specs/002-knowledge-base-infrastructure/research.md), R1 a R11

## Contexto

A base de conhecimento é artefato de domínio, validada no fluxo de verificação obrigatória e revisada
como código. A biblioteca que a interpreta é a fundação de tudo que a feature promete.

`yaml_elixir` e `yamerl` já estavam presentes no projeto como dependências **transitivas de
desenvolvimento** da ferramenta de auditoria. FR-048 proíbe explicitamente ratificar por conveniência
uma biblioteca que chegou por acidente, e o `mix.exs` já registrava esse aviso desde a feature 001.
Esta decisão precisou ser tomada por medição.

FR-049 exige exercitar o caminho que a aplicação realmente usa. A feature 001 concluiu erradamente
sobre a versão de migração do Oban por tê-la testado em configuração reduzida.

## Decisão

**Duas passagens, e nenhuma biblioteca sozinha satisfaz os requisitos.**

### Passagem 1 — portão de tokens, antes de qualquer termo ser construído

`:yamerl_parser.string/2` com a opção `{:token_fun, fun}`, que entrega o fluxo de tokens **antes** da
construção do termo. O portão recusa, com linha e coluna:

| Recusa | Requisito | Por que precisa ser aqui |
|---|---|---|
| âncora ou apelido (`&`, `*`, `<<:`) | FR-011 | R6: um arquivo de **814 bytes** não terminou em 15 segundos e o processo foi morto. Barrar depois da construção é barrar depois do estrago |
| chave duplicada no mesmo mapeamento | FR-010 | R4: as duas bibliotecas aceitam em silêncio, e **discordam** — `yaml_elixir` mantém a primeira, `yamerl` mantém a última |
| tabulação na indentação | FR-072 | R7: `"a:\n\tb: 1"` produz `%{"a" => nil, "b" => 1}` — `b` deveria estar dentro de `a`. Estrutura corrompida em silêncio |
| mais de um documento no arquivo | FR-071 | R8 |

O portão é a razão central desta ADR. **Detecção por token, nunca por expressão regular sobre o
texto.** Medido em R10: `t: "& e * dentro de texto"` produz **zero** token de âncora, enquanto
`a: &x 1` produz `:yamerl_anchor` e `:yamerl_alias`. Uma varredura textual acusaria o primeiro caso e
travaria conteúdo legítimo.

### Passagem 2 — construção com `yaml_elixir`

`YamlElixir.read_all_from_string/2`, **nunca** `read_from_string/2`.

R8 mediu a diferença: `read_from_string` sobre `"a: 1\n---\nb: 2"` devolve `%{"b" => 2}` e **descarta o
primeiro documento em silêncio**; sobre arquivo vazio devolve `%{}`, indistinguível de um mapeamento
vazio legítimo. `read_all_from_string` devolve `[]` para arquivo vazio e para arquivo só com
comentário, e uma lista com dois elementos para dois documentos. Exigir lista de tamanho exatamente 1
satisfaz FR-071 inteiro numa só verificação.

`yaml_elixir` foi escolhida sobre `yamerl` puro por três razões medidas: devolve
`%YamlElixir.ParsingError{line:, column:, type:}` em vez de **lançar** `{:yamerl_exception, ...}`
(R9), o que FR-009 exige; produz mapas com chaves binárias em vez de listas de pares com charlists;
e o desempenho é idêntico (R11) porque `yaml_elixir` **envolve** `yamerl` — não são alternativas
independentes (R2).

### Validação de esquema: sem biblioteca nova

A validação estrita é escrita em Elixir sobre os mapas construídos. Nenhuma biblioteca de validação é
introduzida.

Razão: o princípio VI da constituição proíbe introduzir tecnologia nova quando a atual basta, e
nenhuma biblioteca de esquema disponível resolve o que esta feature precisa — vocabulário fechado de
tipo de fonte, reciprocidade entre conceito e relação, direções permitidas de dependência entre
ontologias, correspondência nos dois sentidos entre manifesto e conteúdo. Tudo isso seria escrito à
mão de qualquer forma, e uma biblioteca cobriria a parte fácil enquanto acrescentaria uma dependência.

## Alternativas rejeitadas

**`fast_yaml`** — descartada por medição, não por preferência. R1: não compila. É NIF sobre `libyaml`,
e a biblioteca do sistema está ausente numa máquina limpa:

```text
fatal error: 'yaml.h' file not found
** (Mix) Could not compile dependency :fast_yaml
```

Adotá-la exigiria instalar pacote de sistema em toda máquina de desenvolvimento e todo executor de
verificação. O `README.md` promete "nenhum passo manual além destes" e SC-001 da feature 001 mediu
inicialização em 24 segundos partindo de repositório recém-clonado. **Não instalei `libyaml` para
medir o desempenho dela** — instalar pacote de sistema na máquina de quem opera é efeito colateral
que ninguém pediu, e o resultado que importa é o de uma máquina limpa.

**`yamerl` puro** — rejeitada. Lança em vez de devolver erro, entrega charlists, e não é melhor em
nada que importa: é a mesma análise que `yaml_elixir` usa por baixo. Continua presente como
dependência transitiva, e o portão de tokens usa o parser dela diretamente — que é o único lugar onde
`yaml_elixir` não expõe o que precisamos.

**Confiar na configuração da biblioteca para os casos perigosos** — rejeitada por medição. Nenhuma
opção testada faz `yamerl` recusar chave duplicada: `[]`, `[:str_node_as_binary]` e
`[{:schema, :core}]` todas aceitam (R4). E nenhuma das duas oferece limite de nós, de profundidade ou
de fator de expansão contra a bomba de R6.

## Consequências

**Aceitas:**

- **duas passagens por arquivo**, e o custo é irrelevante: R11 mediu 0,27 ms por arquivo, 1,36 s para
  cinco mil arquivos, contra um orçamento de dez minutos nos portões. A análise de YAML não é o
  gargalo desta feature e não será por uma ordem de grandeza;
- **âncoras e apelidos ficam proibidos na base**, não desencorajados. Perde-se reuso declarativo
  dentro de um arquivo. R6 justifica: a alternativa é aceitar que 814 bytes derrubem a verificação
  obrigatória num repositório público que aceita propostas de mudança. E R5 mostrou que âncora sobre
  coleção em estilo de fluxo produz **dado errado** em silêncio — o recurso é perigoso **e** defeituoso;
- o portão depende de `:yamerl_parser`, que é interface interna de `yamerl` e não parte da API pública
  de `yaml_elixir`. **Isto é acoplamento a detalhe de implementação de dependência**, e uma atualização
  de `yamerl` pode quebrá-lo. Mitigação: teste que reprova se o fluxo de tokens deixar de expor
  `:yamerl_anchor`, `:yamerl_alias` ou `:yamerl_mapping_key` — o portão nunca deve degradar para
  "não detectou nada" com código de saída zero, que é a classe de defeito da feature 001.

**Limitação registrada, não contornada:** FR-009 exige linha e coluna. R9 mediu que
`yaml_elixir` entrega nos erros de sintaxe e **não entrega** no erro de codificação — `:undefined` nos
dois campos para byte que não é UTF-8 válido. Nesse caso a mensagem nomeia arquivo e razão, sem
posição.

**A especificação foi corrigida por esta pesquisa.** R3: a especificação afirmava que `no`, `yes`,
`on` e `off` são coagidos a booleano. **Estas duas bibliotecas não os coagem** — devolvem texto. O caso
permanece em Edge Cases porque troca de biblioteca pode reintroduzi-lo, agora com a medição ao lado em
vez da suposição. Registrado como correção por medição, não como acerto.

## Como verificar

- os quatro casos do portão recusam, com linha e coluna, e `t: "& e * dentro de texto"` **passa**;
- o arquivo de bomba de 814 bytes de R6 é recusado pelo portão em milissegundos, sem construir termo;
- `"a:\n\tb: 1"` é recusado, e não silenciosamente reestruturado;
- arquivo vazio, arquivo só com comentário e arquivo com dois documentos são recusados, cada um com
  mensagem própria;
- teste que reprova se os tipos de token de que o portão depende desaparecerem.
