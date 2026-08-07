defmodule TheBandWeb.KnowledgeLiveTest do
  @moduledoc """
  A tela da base de conhecimento — leva 2.

  O caso que prova a fatia inteira: um arquivo inválido aparece **na tela**, com arquivo, linha e
  coluna. Sem isso a maquinaria de validação só seria verificável por teste, e quem opera não teria
  como olhar.
  """

  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @rota "/dev/conhecimento"
  @base_real Path.expand("../../../priv/knowledge_base", __DIR__)

  setup do
    original = Application.get_env(:the_band, :knowledge_base_dir)
    on_exit(fn -> Application.put_env(:the_band, :knowledge_base_dir, original) end)
    :ok
  end

  defp usar_base(caminho), do: Application.put_env(:the_band, :knowledge_base_dir, caminho)

  defp base_temporaria do
    tmp = Path.join(System.tmp_dir!(), "kb-live-#{System.unique_integer([:positive])}")
    File.cp_r!(@base_real, tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)
    tmp
  end

  describe "base íntegra" do
    setup do
      usar_base(@base_real)
      :ok
    end

    test "mostra que a base está íntegra e quantos arquivos inspecionou", %{conn: conn} do
      {:ok, view, _} = live(conn, @rota)
      estado = element(view, "#estado") |> render()

      assert estado =~ "Base íntegra"
      assert estado =~ "arquivos inspecionados"
    end

    test "mostra o que o manifesto declara", %{conn: conn} do
      {:ok, view, _} = live(conn, @rota)
      m = element(view, "#manifesto") |> render()

      assert m =~ "the-band"
      assert m =~ "pt-BR"
      assert m =~ "en"
    end

    test "mostra apenas o espaço de exemplos entre as ontologias", %{conn: conn} do
      # Q1: a lista é inventário, não roteiro. `example` está lá porque o conjunto reservado existe;
      # as doze da rede não, porque nenhuma foi modelada.
      {:ok, view, _} = live(conn, @rota)
      m = element(view, "#manifesto") |> render()

      assert m =~ "example"
      refute m =~ "cmpo", "nenhuma ontologia da rede foi modelada ainda"
    end

    test "lista os nove esquemas", %{conn: conn} do
      {:ok, view, _} = live(conn, @rota)
      assert element(view, "#contagem-esquemas") |> render() =~ "9 de 9"

      for tipo <- TheBand.Knowledge.tipos_exigidos() do
        assert has_element?(view, "#esquema-#{tipo}"), "o esquema #{tipo} não aparece na tela"
      end
    end

    test "não mostra bloco de violações quando não há nenhuma", %{conn: conn} do
      {:ok, view, _} = live(conn, @rota)
      refute has_element?(view, "#violacoes")
    end

    test "declara o que a verificação AINDA NÃO cobre", %{conn: conn} do
      # Uma tela que dissesse só "base válida" afirmaria mais do que a verificação garante.
      {:ok, view, _} = live(conn, @rota)
      limitacao = element(view, "#limitacao") |> render()

      assert limitacao =~ "NÃO"
      assert limitacao =~ "#22"
    end

    test "avisa que é tela de desenvolvimento sem controle de acesso", %{conn: conn} do
      {:ok, _view, html} = live(conn, @rota)
      assert html =~ "sem controle de acesso"
    end
  end

  describe "base com arquivo inválido — o caso que prova a fatia" do
    test "a violação aparece na tela, com arquivo, linha e coluna", %{conn: conn} do
      base = base_temporaria()
      File.write!(Path.join(base, "schemas/z-quebrado.schema.yaml"), "a: 1\na: 2\n")
      usar_base(base)

      {:ok, view, _} = live(conn, @rota)

      assert element(view, "#estado") |> render() =~ "violação"

      v = element(view, "#violacao-0") |> render()
      assert v =~ "z-quebrado.schema.yaml"
      assert v =~ "2", "a linha da segunda ocorrência precisa aparecer"
      assert v =~ "chave", "a mensagem precisa dizer o que está errado"
    end

    test "a tela mostra a tabulação na indentação, que corrompe estrutura em silêncio", %{
      conn: conn
    } do
      base = base_temporaria()
      File.write!(Path.join(base, "schemas/z-tab.schema.yaml"), "a:\n\tb: 1\n")
      usar_base(base)

      {:ok, view, _} = live(conn, @rota)
      assert element(view, "#violacoes") |> render() =~ "tabulação"
    end

    test "esquema ausente aparece como bloco próprio, não misturado às violações", %{conn: conn} do
      base = base_temporaria()
      File.rm!(Path.join(base, "schemas/concept.schema.yaml"))
      usar_base(base)

      {:ok, view, _} = live(conn, @rota)
      ausentes = element(view, "#esquemas-ausentes") |> render()

      assert ausentes =~ "concept"

      assert ausentes =~ "pulados",
             "a tela precisa dizer POR QUE um esquema ausente é grave: os arquivos daquele tipo " <>
               "seriam pulados enquanto a contagem permanece maior que zero"
    end

    test "manifesto ilegível tem bloco próprio", %{conn: conn} do
      base = base_temporaria()
      File.write!(Path.join(base, "manifest.yaml"), "sem_a_raiz_certa: 1\n")
      usar_base(base)

      {:ok, view, _} = live(conn, @rota)
      assert element(view, "#sem-manifesto") |> render() =~ "ponto de entrada"
    end
  end

  describe "revalidar" do
    test "relê a base do disco, e o efeito aparece sem reiniciar", %{conn: conn} do
      base = base_temporaria()
      usar_base(base)

      {:ok, view, _} = live(conn, @rota)
      assert element(view, "#estado") |> render() =~ "Base íntegra"

      # Quebra o arquivo com a tela já aberta.
      File.write!(Path.join(base, "schemas/z-novo.schema.yaml"), "a: 1\na: 2\n")

      view |> element("#revalidar") |> render_click()

      assert element(view, "#estado") |> render() =~ "violação",
             "revalidar precisa reler o disco; sem isso quem escreve YAML não vê o efeito"
    end
  end
end
