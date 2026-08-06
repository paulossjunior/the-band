defmodule TheBand.Knowledge.TokenGateTest do
  @moduledoc """
  T006 a T015. O portão de tokens recusa antes de qualquer termo ser construído.

  Cada teste aponta o requisito e, quando existe, a medição de `research.md` que o motivou.
  """

  use ExUnit.Case, async: true

  alias TheBand.Knowledge.TokenGate
  alias TheBand.Knowledge.TokenGate.Violation

  @caminho "exemplo.yaml"

  defp recusa(fonte) do
    assert {:error, violacoes} = TokenGate.inspect_source(fonte, @caminho)
    violacoes
  end

  defp tipos(fonte), do: recusa(fonte) |> Enum.map(& &1.kind) |> Enum.uniq() |> Enum.sort()

  describe "caminho de aceitação — o portão não é um recusador indiscriminado" do
    test "documento comum passa" do
      assert :ok =
               TokenGate.inspect_source("concept:\n  id: example.a\n  version: 1.0.0\n", @caminho)
    end

    test "FR-011 — `&` e `*` DENTRO de texto citado passam" do
      # R10 mediu: este arquivo produz ZERO token de âncora. Uma varredura por expressão regular
      # acusaria e travaria conteúdo legítimo. Este teste é o que impede alguém trocar a detecção
      # por token por uma busca textual depois.
      assert :ok = TokenGate.inspect_source(~s(t: "& e * dentro de texto"\n), @caminho)
      assert :ok = TokenGate.inspect_source("t: 'a & b * c'\n", @caminho)
    end

    test "chave repetida em mapeamentos DIFERENTES passa" do
      fonte = "a:\n  id: 1\nb:\n  id: 2\n"
      assert :ok = TokenGate.inspect_source(fonte, @caminho)
    end

    test "FR-072 — marca de ordem de bytes e fim de linha do Windows são tolerados" do
      assert :ok = TokenGate.inspect_source(<<0xEF, 0xBB, 0xBF>> <> "a: 1\n", @caminho)
      assert :ok = TokenGate.inspect_source("a: 1\r\nb: 2\r\n", @caminho)
    end

    test "tabulação DENTRO do texto, fora da indentação, passa" do
      assert :ok = TokenGate.inspect_source("a: \"antes\tdepois\"\n", @caminho)
    end
  end

  describe "FR-011 — âncora e apelido" do
    test "âncora é recusada, com linha e coluna" do
      [v | _] = recusa("a: &x 1\nb: 2\n")
      assert v.kind == :anchor
      assert v.line == 1
      assert is_integer(v.column)
      assert v.message =~ "âncora"
    end

    test "apelido é recusado" do
      assert :alias in tipos("a: &x 1\nb: *x\n")
    end

    test "âncora em estilo de bloco também é recusada" do
      # R5: em bloco os apelidos EXPANDEM de verdade, e é esse caminho que produz a bomba.
      assert :anchor in tipos("base: &b\n  p: 1\nfilho: *b\n")
    end

    test "chave de mesclagem é recusada pelo apelido que ela usa" do
      assert :alias in tipos("d: &x\n  p: 1\ne:\n  <<: *x\n  q: 2\n")
    end
  end

  describe "FR-010 — chave duplicada" do
    test "recusa, e nomeia a posição das DUAS ocorrências" do
      [v] = recusa("a: 1\na: 2\n")
      assert v.kind == :duplicate_key
      assert v.line == 2
      assert v.message =~ ~s("a")
      assert v.message =~ "1:1", "a mensagem tem de apontar também a primeira ocorrência"
    end

    test "recusa duplicata aninhada" do
      [v] = recusa("b:\n  c: 3\n  c: 4\n")
      assert v.kind == :duplicate_key
      assert v.line == 3
    end

    test "recusa três ocorrências como duas violações" do
      violacoes = recusa("a: 1\na: 2\na: 3\n")
      assert length(violacoes) == 2, "FR-015 exige relatar todas, não parar na primeira"
    end
  end

  describe "FR-072 — tabulação na indentação" do
    test "recusa, porque as bibliotecas achatam a estrutura em silêncio" do
      # R7: "a:\n\tb: 1" produz %{"a" => nil, "b" => 1} — `b` virou IRMÃO de `a`.
      [v] = recusa("a:\n\tb: 1\n")
      assert v.kind == :tab_indentation
      assert v.line == 2
      assert v.column == 1
    end

    test "recusa tabulação depois de espaços" do
      [v] = recusa("a:\n  \tb: 1\n")
      assert v.kind == :tab_indentation
      assert v.column == 3
    end
  end

  describe "FR-071 — um documento por arquivo" do
    test "recusa múltiplos documentos" do
      [v] = recusa("a: 1\n---\nb: 2\n")
      assert v.kind == :multiple_documents
      assert v.message =~ "2 documentos"
    end

    test "recusa arquivo vazio" do
      assert [%Violation{kind: :empty_document}] = recusa("")
    end

    test "recusa arquivo com apenas comentários" do
      assert [%Violation{kind: :empty_document}] = recusa("# nada aqui\n# nem aqui\n")
    end

    test "cada caso tem mensagem própria, não uma genérica" do
      [vazio] = recusa("")
      [muitos] = recusa("a: 1\n---\nb: 2\n")
      refute vazio.message == muitos.message
    end
  end

  describe "FR-009 — sintaxe inválida" do
    test "recusa indicando a posição, e não trata como arquivo vazio" do
      [v] = recusa("a: [1, 2\nb: 3\n")
      assert v.kind == :syntax
      assert v.line == 2, "R9 mediu linha 2, coluna 5 para este caso"
      refute v.kind == :empty_document
    end
  end

  describe "FR-072 — codificação" do
    test "recusa byte que não é UTF-8 válido" do
      [v] = recusa(<<"a: ", 0xFF, 0xFE, "\n">>)
      assert v.kind == :invalid_encoding
    end

    test "a limitação medida está registrada na mensagem: sem posição" do
      # R9: yaml_elixir devolve line: :undefined, column: :undefined para esta classe.
      [v] = recusa(<<"a: ", 0xFF, "\n">>)
      assert is_nil(v.line)
      assert v.message =~ "posição não é reportada"
    end
  end

  describe "FR-092 — limite de tamanho e de tempo" do
    test "os limites são os derivados de R11" do
      assert TokenGate.max_bytes() == 256 * 1024
      assert TokenGate.timeout_ms() == 2_000
    end

    test "recusa arquivo acima do limite sem tentar interpretá-lo" do
      grande = "a: " <> String.duplicate("x", TokenGate.max_bytes())
      [v] = recusa(grande)
      assert v.kind == :too_large
      assert v.message =~ "excede o limite"
    end

    test "arquivo exatamente no limite passa" do
      no_limite = String.duplicate("#", TokenGate.max_bytes() - 6) <> "\na: 1\n"
      assert byte_size(no_limite) == TokenGate.max_bytes()
      assert :ok = TokenGate.inspect_source(no_limite, @caminho)
    end
  end

  describe "FR-018 e SC-002 — a bomba de expansão, medida em R6" do
    @tag :integration
    test "o arquivo de 814 bytes que mata o processo é recusado em milissegundos" do
      bomba = bomba_de_expansao(10, 9)

      assert byte_size(bomba) < 1_000,
             "a bomba de R6 tem 814 bytes; se cresceu, o teste deixou de reproduzir a medição"

      {microssegundos, resultado} =
        :timer.tc(fn -> TokenGate.inspect_source(bomba, "bomba.yaml") end)

      assert {:error, violacoes} = resultado
      tipos_encontrados = violacoes |> Enum.map(& &1.kind) |> Enum.uniq()
      assert :anchor in tipos_encontrados

      # O ponto do teste. R6 mediu que a CONSTRUÇÃO deste arquivo não termina em 15 segundos e mata
      # o processo. O portão recusa antes de construir, e por isso é rápido.
      assert microssegundos < 500_000,
             "o portão levou #{div(microssegundos, 1000)} ms. Ele deve recusar antes de construir " <>
               "o termo; se está lento, a recusa está acontecendo tarde demais"
    end

    defp bomba_de_expansao(niveis, fator) do
      base = "l0: &l0 \"x\"\n"

      base <>
        Enum.map_join(1..niveis, "", fn i ->
          itens = Enum.map_join(1..fator, "", fn _ -> "  - *l#{i - 1}\n" end)
          "l#{i}: &l#{i}\n" <> itens
        end)
    end
  end

  describe "FR-015 — todas as violações de uma execução" do
    test "arquivo com defeitos de classes diferentes relata todos" do
      fonte = "a: &x 1\na: 2\nb:\n\tc: 3\n"
      encontrados = tipos(fonte)

      assert :anchor in encontrados
      assert :duplicate_key in encontrados
      assert :tab_indentation in encontrados
    end
  end

  describe "FR-091 — saída determinística" do
    test "duas execuções sobre a mesma fonte produzem violações idênticas" do
      fonte = "a: &x 1\na: 2\nb:\n\tc: 3\n"
      assert recusa(fonte) == recusa(fonte)
    end

    test "as violações vêm ordenadas por posição" do
      fonte = "z:\n\tq: 1\na: &x 1\na: 2\n"
      linhas = recusa(fonte) |> Enum.map(&(&1.line || 0))
      assert linhas == Enum.sort(linhas)
    end
  end

  describe "Violation.to_line/1" do
    test "formata no padrão que editor e humano leem igual" do
      [v] = recusa("a: 1\na: 2\n")
      assert TokenGate.Violation.to_line(v) =~ ~r{^exemplo\.yaml:2:\d+: }
    end

    test "omite a posição quando ela não existe" do
      [v] = recusa(<<"a: ", 0xFF>>)
      assert TokenGate.Violation.to_line(v) == "exemplo.yaml: #{v.message}"
    end
  end
end
