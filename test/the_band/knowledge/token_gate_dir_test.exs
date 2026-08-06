defmodule TheBand.Knowledge.TokenGateDirTest do
  @moduledoc """
  T012 e T013 — varredura de diretório: ligação simbólica para fora da base, e exclusão **contada**.

  O relatório sempre informa quantos arquivos foram inspecionados e quantos foram ignorados.
  Exclusão que não é contada é indistinguível de arquivo que não foi encontrado, e "não encontrei
  nada" com aprovação é a classe de defeito que a feature 001 encontrou.
  """

  use ExUnit.Case, async: true

  alias TheBand.Knowledge.TokenGate

  setup do
    base = Path.join(System.tmp_dir!(), "kb-#{System.unique_integer([:positive])}")
    File.mkdir_p!(base)
    on_exit(fn -> File.rm_rf!(base) end)
    {:ok, base: base}
  end

  defp escrever(base, rel, conteudo) do
    caminho = Path.join(base, rel)
    File.mkdir_p!(Path.dirname(caminho))
    File.write!(caminho, conteudo)
    caminho
  end

  describe "contagem" do
    test "relata quantos arquivos inspecionou", %{base: base} do
      escrever(base, "a.yaml", "a: 1\n")
      escrever(base, "sub/b.yaml", "b: 2\n")

      assert {:ok, relatorio} = TokenGate.inspect_dir(base)
      assert relatorio.inspecionados == 2
      assert relatorio.ignorados == []
    end

    test "considera as DUAS extensões usuais — FR-014", %{base: base} do
      escrever(base, "a.yaml", "a: 1\n")
      escrever(base, "b.yml", "b: 2\n")

      assert {:ok, %{inspecionados: 2}} = TokenGate.inspect_dir(base)
    end

    test "arquivo iniciado por ponto é ignorado E CONTADO", %{base: base} do
      escrever(base, "a.yaml", "a: 1\n")
      escrever(base, ".DS_Store", "lixo do sistema")
      escrever(base, ".oculto.yaml", "x: 1\n")

      assert {:ok, relatorio} = TokenGate.inspect_dir(base)
      assert relatorio.inspecionados == 1

      assert ".DS_Store" in relatorio.ignorados
      assert ".oculto.yaml" in relatorio.ignorados

      assert length(relatorio.ignorados) == 2, """
      Os ignorados têm de aparecer no relatório. Se a lista vier vazia, quem lê não distingue
      "ignorei dois arquivos de propósito" de "não encontrei arquivo algum".
      """
    end

    test "arquivo dentro de diretório oculto é ignorado", %{base: base} do
      escrever(base, "a.yaml", "a: 1\n")
      escrever(base, ".git/config.yaml", "x: 1\n")

      assert {:ok, relatorio} = TokenGate.inspect_dir(base)
      assert relatorio.inspecionados == 1
      assert ".git/config.yaml" in relatorio.ignorados
    end

    test "arquivo que não é YAML é ignorado e contado", %{base: base} do
      escrever(base, "a.yaml", "a: 1\n")
      escrever(base, "leiame.md", "# nota")

      assert {:ok, relatorio} = TokenGate.inspect_dir(base)
      assert relatorio.inspecionados == 1
      assert "leiame.md" in relatorio.ignorados
    end
  end

  describe "violações" do
    test "reprova nomeando o caminho relativo à base", %{base: base} do
      escrever(base, "bom.yaml", "a: 1\n")
      escrever(base, "sub/ruim.yaml", "a: 1\na: 2\n")

      assert {:error, relatorio} = TokenGate.inspect_dir(base)
      assert relatorio.inspecionados == 2
      assert [v] = relatorio.violacoes
      assert v.path == "sub/ruim.yaml"
      assert v.kind == :duplicate_key
    end

    test "a ordem dos arquivos é estável entre execuções — FR-091", %{base: base} do
      escrever(base, "z.yaml", "a: 1\na: 2\n")
      escrever(base, "a.yaml", "b: 1\nb: 2\n")

      {:error, um} = TokenGate.inspect_dir(base)
      {:error, dois} = TokenGate.inspect_dir(base)

      assert Enum.map(um.violacoes, & &1.path) == Enum.map(dois.violacoes, & &1.path)
    end
  end

  describe "FR-072 — ligação simbólica" do
    @tag :integration
    test "recusa ligação que aponta para fora da base", %{base: base} do
      fora = Path.join(System.tmp_dir!(), "fora-#{System.unique_integer([:positive])}.yaml")
      File.write!(fora, "segredo: talvez\n")
      on_exit(fn -> File.rm_rf!(fora) end)

      File.ln_s!(fora, Path.join(base, "atalho.yaml"))

      assert {:error, relatorio} = TokenGate.inspect_dir(base)
      assert [v] = relatorio.violacoes
      assert v.kind == :symlink_outside_base
    end

    @tag :integration
    test "aceita ligação que aponta para dentro da base", %{base: base} do
      escrever(base, "real.yaml", "a: 1\n")
      File.ln_s!(Path.join(base, "real.yaml"), Path.join(base, "atalho.yaml"))

      assert {:ok, _} = TokenGate.inspect_dir(base)
    end
  end

  describe "base sem arquivo algum" do
    test "relata inspecionados igual a zero em vez de aprovar em silêncio", %{base: base} do
      # O portão não decide se zero arquivos é erro — isso é FR-016, e pertence a
      # `mix knowledge.validate`, no PR C. O que o portão garante é que o número aparece, para que
      # quem decidir tenha o dado.
      assert {:ok, relatorio} = TokenGate.inspect_dir(base)
      assert relatorio.inspecionados == 0
    end
  end
end
