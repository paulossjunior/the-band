# Pesquisa — Feature 002, infraestrutura da base de conhecimento YAML

**Data**: 2026-08-06

**Método**: projeto Mix separado, fora do The Band. `mix.exs` do projeto **não foi tocado**. Cada
resultado abaixo é saída de execução, não leitura de documentação.

FR-049 exige exercitar o caminho que a aplicação realmente usa. A feature 001 concluiu erradamente
que a migração v12 do Oban bastava por tê-la testado em configuração reduzida; com plugins ativos o
arranque exigia v14. Esta pesquisa foi desenhada contra esse erro.

Ambiente: Elixir 1.20.2, Erlang/OTP 29, macOS. `yaml_elixir` 2.12.2, `yamerl` 0.10.0,
`fast_yaml` 1.0.40.

---

## R1 — `fast_yaml` não compila. Exige biblioteca C do sistema

```text
===> Compiling .../deps/fast_yaml/c_src/fast_yaml.c
===> .../c_src/fast_yaml.c:18:10: fatal error: 'yaml.h' file not found
   18 | #include <yaml.h>
1 error generated.
** (Mix) Could not compile dependency :fast_yaml
```

Confirmado que a biblioteca do sistema está ausente:

```text
$ ls /opt/homebrew/include/yaml.h /usr/local/include/yaml.h /usr/include/yaml.h
ls: No such file or directory   (os três)
$ brew list libyaml
Error: No such keg: /opt/homebrew/Cellar/libyaml
```

`fast_yaml` é NIF sobre `libyaml`. Adotá-lo exige instalar pacote de sistema em **toda** máquina de
desenvolvimento e em **todo** executor de verificação. O `README.md` promete "nenhum passo manual
além destes", e SC-001 da feature 001 mediu inicialização em 24 segundos partindo de repositório
recém-clonado. Um NIF sobre biblioteca de sistema quebra as duas coisas.

**Não instalei `libyaml` para medir o desempenho dele.** Instalar pacote de sistema na máquina de
quem opera é efeito colateral que ninguém pediu. O resultado registrado é o que se observa numa
máquina limpa, que é a condição que importa.

**Descartada.**

## R2 — `yaml_elixir` envolve `yamerl`. Não são alternativas independentes

`yaml_elixir` depende de `yamerl` e delega a análise a ele. Escolher `yaml_elixir` **é** escolher
`yamerl` mais uma camada de conveniência. Isto elimina a comparação de desempenho entre os dois
como critério — medida abaixo confirma.

## R3 — Coerção de tipo: uma previsão da especificação confirmada, uma **errada**

| Fonte | `yaml_elixir` | `yamerl` |
|---|---|---|
| `version: 1.0` | `1.0` (número) | `1.0` |
| `version: '1.0'` | `"1.0"` (texto) | `"1.0"` |
| **`version: 1.10`** | **`1.1`** | **`1.1`** |
| `label: no` | `"no"` (**texto**) | `"no"` |
| `label: yes` | `"yes"` (**texto**) | `"yes"` |
| `label: on` | `"on"` (**texto**) | `"on"` |
| `id: 1.2.3` | `"1.2.3"` (texto) | `"1.2.3"` |
| `a:` | `nil` | `:null` |
| `a: ~` | `nil` | `:null` |

**Confirmado**: `version: 1.10` e `version: 1.1` produzem o **mesmo valor**. Duas versões diferentes
tornam-se indistinguíveis. FR-012 é necessário.

**A especificação estava errada** ao afirmar que `no`, `yes`, `on` e `off` "são interpretados como
booleano por interpretadores que seguem a versão 1.1 da especificação". **Estas duas bibliotecas não
os coagem** — devolvem texto. O caso permanece registrado em Edge Cases porque troca de biblioteca ou
de versão pode reintroduzi-lo, mas agora com a medição ao lado, em vez da suposição.

Registrado como correção da especificação por medição, não como acerto.

## R4 — Chave duplicada: aceita em silêncio, e as duas bibliotecas **discordam**

```text
fonte: "a: 1\na: 2"

yaml_elixir  ->  %{"a" => 1}      mantém a PRIMEIRA
yamerl       ->  [{"a", 2}]       mantém a ÚLTIMA
```

Nenhuma das duas reprova. Nenhuma opção testada muda isso: `[]`, `[:str_node_as_binary]`,
`[{:schema, :core}]` — todas aceitam.

O mesmo documento produz **dados diferentes** conforme a camada usada. Isto é pior que aceitar em
silêncio: é aceitar em silêncio de duas formas incompatíveis.

## R5 — Âncora em estilo de fluxo produz dado **errado**. Em bloco funciona

Primeira medição, e a conclusão apressada que ela quase me fez registrar:

```text
fonte: "d: &x {p: 1}\ne: *x"          (estilo de FLUXO)
yaml_elixir -> %{"d" => %{"p" => 1}, "e" => "p"}          ERRADO
                                            ^^^^ apelido virou o texto "p"

fonte: "d: &x {p: 1}\ne:\n  <<: *x\n  q: 2"
yaml_elixir -> %{"e" => %{"<<1" => "p", ...}}             LIXO
```

Segunda medição, em estilo de bloco:

```text
fonte: "base: &b\n  p: 1\n  q: 2\nfilho: *b"     (estilo de BLOCO)
yaml_elixir -> %{"base" => %{"p" => 1, "q" => 2},
                 "filho" => %{"p" => 1, "q" => 2}}       CORRETO
```

**O defeito é específico de âncora sobre coleção em estilo de fluxo.** Eu quase registrei "apelidos
estão quebrados", que seria falso e teria distorcido a decisão. A correção veio de rodar o segundo
caso, não de reler o primeiro.

## R6 — Bomba de expansão: **814 bytes matam o processo**

O primeiro teste de bomba usou estilo de fluxo e não expandiu — **por causa do defeito de R5, não por
proteção**. Refeito em estilo de bloco, com processo isolado, monitor e limite de 15 segundos:

| Fonte | Níveis × fator | Nós teóricos | Tempo | Resultado |
|---|---|---|---|---|
| 204 B | 4 × 5 | 625 | 2 ms | termo de 4.312 palavras |
| 348 B | 6 × 6 | 46.656 | 2 ms | termo de 302.352 palavras |
| **588 B** | 8 × 8 | 16.777.216 | **786 ms** | termo de **101.348.108 palavras** (~800 MB) |
| **814 B** | 10 × 9 | 3.486.784.401 | **>15 s** | **não terminou — processo morto** |

Nenhuma das bibliotecas oferece limite de nós, de profundidade ou de fator de expansão.

**Este repositório é público e aceita propostas de mudança.** Um arquivo de 814 bytes numa proposta
derruba a verificação obrigatória de status. Não é hipótese: está medido acima.

FR-018 não tem como ser satisfeito por configuração de biblioteca. Precisa de recusa **antes** da
construção do termo.

## R7 — Tabulação na indentação: estrutura corrompida em silêncio

**Caso ausente da especificação, encontrado por medição.**

```text
fonte: "a:\n\tb: 1"        (tabulação antes de b)
yaml_elixir -> %{"a" => nil, "b" => 1}
```

`b` deveria estar **dentro** de `a`. Virou irmão. A especificação YAML proíbe tabulação na
indentação, e as duas bibliotecas aceitam e reestruturam o documento sem avisar.

Um arquivo assim passa por qualquer validação de esquema, porque o esquema recebe uma árvore
válida — só não é a árvore que quem escreveu enxergou no editor.

## R8 — Múltiplos documentos: `read_from_string` descarta os anteriores em silêncio

```text
fonte: "a: 1\n---\nb: 2"

YamlElixir.read_from_string      -> {:ok, %{"b" => 2}}            perde o primeiro
YamlElixir.read_all_from_string  -> {:ok, [%{"a" => 1}, %{"b" => 2}]}
```

E `read_all_from_string` distingue o vazio:

```text
""            -> {:ok, []}
"# comentario" -> {:ok, []}     (read_from_string devolve %{} — indistinguível de mapeamento vazio)
"a: 1"        -> {:ok, [%{"a" => 1}]}
```

**Consequência de projeto**: usar `read_all_from_string` e exigir lista de tamanho exatamente 1
satisfaz FR-071 inteiro — um documento por arquivo, arquivo vazio recusado, arquivo só com
comentário recusado. `read_from_string` **não** serve: apaga a diferença.

## R9 — Mensagem de erro: `yaml_elixir` dá linha, coluna e razão tipada. Com uma exceção

```text
fonte: "a: [1, 2\nb: 3"
%YamlElixir.ParsingError{line: 2, column: 5, type: :unfinished_flow_collection}

fonte: <<"a: ", 0xFF, 0xFE>>
%YamlElixir.ParsingError{line: :undefined, column: :undefined, type: :invalid_unicode}
```

`yamerl` **lança** `{:yamerl_exception, ...}` em vez de devolver erro.

FR-009 exige linha e coluna. `yaml_elixir` entrega nos erros de sintaxe, e **não entrega** no erro de
codificação — `:undefined` nos dois campos. Limitação real: para byte inválido a mensagem nomeia o
arquivo e a razão, não a posição. Registrada em vez de contornada, porque a posição de um byte
inválido é obtenível por conta própria se algum dia importar.

## R10 — Fluxo de tokens resolve o que a construção não resolve

`:yamerl_parser.string/2` com a opção `{:token_fun, fun}` entrega o fluxo de tokens **antes** da
construção do termo. Medido com `"a: 1\na: 2\nb:\n  c: 3\n  c: 4\n"` — 27 tokens:

```text
yamerl_mapping_key         linha 1 col 1
yamerl_scalar              linha 1 col 1  valor="a"
yamerl_scalar              linha 1 col 4  valor="1"
yamerl_mapping_key         linha 2 col 1
yamerl_scalar              linha 2 col 1  valor="a"     <- duplicada, com posição
yamerl_scalar              linha 2 col 4  valor="2"
yamerl_mapping_key         linha 3 col 1
yamerl_scalar              linha 3 col 1  valor="b"
yamerl_collection_start    linha 4 col 3
yamerl_mapping_key         linha 4 col 3
yamerl_scalar              linha 4 col 3  valor="c"
yamerl_scalar              linha 4 col 6  valor="3"
yamerl_mapping_key         linha 5 col 3
yamerl_scalar              linha 5 col 3  valor="c"     <- duplicada aninhada, com posição
yamerl_scalar              linha 5 col 6  valor="4"
yamerl_collection_end      linha 5 col 7
```

E âncora e apelido são tokens próprios, com **zero falso positivo** para `&` e `*` dentro de texto:

| Fonte | Tokens de âncora/apelido |
|---|---|
| `a: &x 1\nb: *x` | `[:yamerl_anchor, :yamerl_alias]` |
| `a: &z\n  p: 1\nb: *z` | `[:yamerl_anchor, :yamerl_alias]` |
| `a: 1\nb: 2` | `[]` |
| `t: "& e * dentro de texto"` | `[]` |

Isto é o achado que decide o desenho. Detecção por expressão regular sobre o texto acusaria o último
caso; detecção por token não. E o fluxo de tokens acontece **antes** da construção, que é onde a
bomba de R6 precisa ser barrada.

## R11 — Desempenho: idêntico, e folgado

Arquivo realista de conceito, 766 bytes, com rótulo e definição bilíngues, atributos, relações,
classificação e proveniência.

| Biblioteca | 100 arquivos | 1.000 | 5.000 | por arquivo |
|---|---|---|---|---|
| `yaml_elixir` | 26 ms | 263 ms | **1.360 ms** | 0,27 ms |
| `yamerl` | 27 ms | 276 ms | **1.320 ms** | 0,26 ms |

Idênticos, como R2 previa — é a mesma análise por baixo.

**Responde a pergunta que SC-012 deixou aberta.** Cinco mil arquivos custam 1,4 segundo de análise.
O orçamento dos portões é de dez minutos. A análise de YAML não é o gargalo desta feature, e não
será por uma ordem de grandeza.

## O que a pesquisa mudou

| Achado | Efeito |
|---|---|
| R1 | `fast_yaml` descartada por medição, não por preferência |
| R3 | **Especificação corrigida**: `no`/`yes`/`on` não são coagidos por estas bibliotecas |
| R4 | Chave duplicada exige detecção própria; as bibliotecas discordam entre si |
| R5 | Conclusão apressada minha, corrigida por segunda medição |
| R6 | **814 bytes matam o processo.** Recusa de âncora deixa de ser preferência e passa a ser defesa |
| R7 | **Caso novo**: tabulação na indentação corrompe estrutura em silêncio |
| R8 | `read_from_string` é inadequado; `read_all_from_string` satisfaz FR-071 inteiro |
| R9 | Limitação registrada: sem linha e coluna para byte inválido |
| R10 | Fluxo de tokens é o mecanismo para FR-010, FR-011 e FR-018 |
| R11 | Volume que SC-012 deixou aberto: 5.000 arquivos em 1,4 s |

## Erros meus durante a pesquisa, com a causa

Registrados porque a causa se reaproveita.

1. **Quase registrei "apelidos estão quebrados"** com base num único caso em estilo de fluxo. Falso.
   O defeito é restrito a âncora sobre coleção em fluxo. Corrigido rodando o caso em bloco.
2. **O primeiro teste de bomba não expandiu, e eu quase li isso como proteção.** Não era: era o
   defeito de R5 impedindo a expansão. Refeito em bloco, a bomba é real e grave.
3. **`mix run --no-start`** no script de demonstração da aplicação: o Repo não subiu,
   `could not lookup Ecto repo`. Erro de invocação, não de código.
4. Duas tentativas erradas de ler o fluxo de tokens — opção com nome inventado
   (`{:detailed_constr, true}` no parser, que só existe no construtor) e retorno errado da função de
   token (`{:ok, t}` em vez de `:ok`). Nenhuma era limitação da biblioteca.
