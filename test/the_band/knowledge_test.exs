defmodule TheBand.KnowledgeTest do
  @moduledoc """
  Leva 2 — manifesto, carregador e a API pública.

  O teste que mais importa é o de FR-089: **impedir o carregamento de um esquema por vez** e
  confirmar que a validação reprova. Contar arquivos não fecha esse caminho, e foi exatamente essa a
  falha da feature 001.
  """

  use ExUnit.Case, async: true

  alias TheBand.Knowledge
  alias TheBand.Knowledge.{Loader, Manifest}

  @base_real Path.expand("../../priv/knowledge_base", __DIR__)

  setup do
    tmp = Path.join(System.tmp_dir!(), "kb-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(tmp, "schemas"))
    on_exit(fn -> File.rm_rf!(tmp) end)
    {:ok, base: tmp}
  end

  defp copiar_base_real(destino) do
    File.cp_r!(@base_real, destino)
    destino
  end

  defp escrever(base, rel, conteudo) do
    caminho = Path.join(base, rel)
    File.mkdir_p!(Path.dirname(caminho))
    File.write!(caminho, conteudo)
  end

  describe "a base entregue por esta feature" do
    test "é íntegra" do
      assert {:ok, r} = Knowledge.inspect_base(@base_real)
      assert r.violacoes == []
    end

    test "tem os nove esquemas exigidos, e nenhum ausente" do
      assert Knowledge.esquemas_ausentes(@base_real) == []
      assert length(Knowledge.tipos_exigidos()) == 9
    end

    test "o manifesto declara os dois idiomas exigidos" do
      assert {:ok, m} = Manifest.load(@base_real)
      assert "pt-BR" in m.required_languages
      assert "en" in m.required_languages
    end

    test "o manifesto NÃO declara ontologia alguma, e isso é deliberado" do
      # Clarifications Q1: a lista é INVENTÁRIO do que existe, não roteiro. Nenhuma ontologia foi
      # modelada ainda; listar as doze tornaria impossível detectar "manifesto declara ontologia que
      # não existe", para sempre.
      assert {:ok, m} = Manifest.load(@base_real)
      assert m.ontologies == []
    end
  end

  describe "FR-089 e SC-021 — a verificação que a feature 001 não tinha" do
    test "reprova quando QUALQUER um dos nove esquemas não carrega", %{base: base} do
      copiar_base_real(base)
      assert Knowledge.esquemas_ausentes(base) == []

      for tipo <- Knowledge.tipos_exigidos() do
        caminho = Path.join([base, "schemas", "#{tipo}.schema.yaml"])
        guardado = File.read!(caminho)
        File.rm!(caminho)

        assert tipo in Knowledge.esquemas_ausentes(base), """
        Removi o esquema `#{tipo}` e a base não o reportou como ausente.

        Contar arquivos verificados NÃO fecha este caminho: os arquivos daquele tipo passam a ser
        pulados enquanto a contagem permanece maior que zero, e a validação aprova. É a forma exata
        do defeito da feature 001 — `mix credo` sem compilar, checagem que não carrega, código de
        saída 0.
        """

        File.write!(caminho, guardado)
        assert Knowledge.esquemas_ausentes(base) == []
      end
    end
  end

  describe "FR-016 — aprovar sem ter verificado nada é proibido" do
    test "base vazia é inspecionada, e a contagem é zero", %{base: base} do
      assert {:error, r} = Knowledge.inspect_base(base)
      assert r.arquivos_inspecionados == 0

      # Quem decide que zero é erro é a tarefa Mix; a API entrega o número para que a decisão exista.
      assert r.manifest == nil
    end
  end

  describe "manifesto" do
    test "base sem manifesto reprova nomeando o que se perde", %{base: base} do
      assert {:error, [v]} = Manifest.load(base)
      assert v.message =~ "não tem manifesto"
      assert v.message =~ "ponto de entrada"
    end

    test "FR-004 — política não estrita recusa o PRÓPRIO manifesto", %{base: base} do
      escrever(base, "manifest.yaml", """
      knowledge_base:
        name: teste
        version: 1.0.0
        default_language: pt-BR
        required_languages: [pt-BR]
        default_schema_version: 1
        ontologies: []
        validation:
          strict: false
          reject_unknown_fields: true
        provenance:
          required: true
      """)

      assert {:error, [v]} = Manifest.load(base)
      assert v.message =~ "DECLARATIVO"
      assert v.message =~ "não afrouxa a validação"
    end

    test "FR-007 — campo declarado SEM VALOR é violação, não ausência", %{base: base} do
      escrever(base, "manifest.yaml", """
      knowledge_base:
        name:
        version: 1.0.0
        default_language: pt-BR
        required_languages: [pt-BR]
        default_schema_version: 1
        ontologies: []
        validation:
          strict: true
          reject_unknown_fields: true
        provenance:
          required: true
      """)

      assert {:error, [v]} = Manifest.load(base)
      assert v.message =~ "declara sem valor"

      refute v.message =~ "não declara:",
             "campo vazio e campo ausente são erros diferentes de quem escreve"
    end

    test "idioma padrão fora dos exigidos reprova", %{base: base} do
      escrever(base, "manifest.yaml", """
      knowledge_base:
        name: teste
        version: 1.0.0
        default_language: fr
        required_languages: [pt-BR, en]
        default_schema_version: 1
        ontologies: []
        validation:
          strict: true
          reject_unknown_fields: true
        provenance:
          required: true
      """)

      assert {:error, [v]} = Manifest.load(base)
      assert v.message =~ "não está entre os exigidos"
    end

    test "proveniência opcional reprova, citando o princípio III", %{base: base} do
      escrever(base, "manifest.yaml", """
      knowledge_base:
        name: teste
        version: 1.0.0
        default_language: pt-BR
        required_languages: [pt-BR]
        default_schema_version: 1
        ontologies: []
        validation:
          strict: true
          reject_unknown_fields: true
        provenance:
          required: false
      """)

      assert {:error, [v]} = Manifest.load(base)
      assert v.message =~ "princípio III"
    end
  end

  describe "carregador — FR-071" do
    test "aceita um documento com mapeamento na raiz", %{base: base} do
      assert {:ok, %{"a" => 1}} = Loader.load_source("a: 1\n", "x.yaml")
    end

    test "recusa raiz que não é mapeamento", %{base: _base} do
      assert {:error, [v]} = Loader.load_source("- a\n- b\n", "x.yaml")
      assert v.kind == :not_a_mapping
      assert v.message =~ "lista"
    end

    test "recusa dois documentos, pelo portão", %{base: _base} do
      assert {:error, [v]} = Loader.load_source("a: 1\n---\nb: 2\n", "x.yaml")
      assert v.kind == :multiple_documents
    end

    test "recusa arquivo vazio, pelo portão", %{base: _base} do
      assert {:error, [v]} = Loader.load_source("", "x.yaml")
      assert v.kind == :empty_document
    end

    test "o portão roda ANTES da construção", %{base: _base} do
      # Âncora é recusada pelo portão. Se a construção rodasse primeiro, um arquivo de 814 bytes de
      # apelidos aninhados mataria o processo (research.md R6).
      assert {:error, violacoes} = Loader.load_source("a: &x 1\nb: *x\n", "x.yaml")
      assert :anchor in Enum.map(violacoes, & &1.kind)
    end
  end

  describe "o módulo não usa read_from_string/2" do
    test "e há teste que reprova se alguém o reintroduzir" do
      fonte = File.read!("lib/the_band/knowledge/loader.ex")

      # `read_from_string` devolve APENAS o último documento de um arquivo com vários, descartando os
      # anteriores em silêncio, e devolve %{} para arquivo vazio — indistinguível de mapeamento vazio
      # legítimo (research.md R8). Sem este teste, alguém "simplifica" e reintroduz o descarte.
      chamadas =
        Regex.scan(~r/YamlElixir\.read_from_string/, fonte)
        |> length()

      assert chamadas == 0, """
      `YamlElixir.read_from_string/1,2` apareceu em loader.ex.

      Ele descarta documentos em silêncio e apaga a diferença entre arquivo vazio e mapeamento
      vazio. Use `read_all_from_string/2` e exija lista de tamanho exatamente 1 — isso satisfaz
      FR-071 inteiro numa verificação.
      """
    end
  end

  describe "API pública" do
    test "expõe o que a tela e a tarefa Mix precisam" do
      # `function_exported?/3` devolve false para módulo ainda não carregado, e em `async: true` ele
      # pode não estar. Sem isto o teste reprova por motivo diferente do que verifica.
      Code.ensure_loaded!(Knowledge)

      assert function_exported?(Knowledge, :inspect_base, 1)
      assert function_exported?(Knowledge, :esquemas_ausentes, 1)
      assert function_exported?(Knowledge, :tipos_exigidos, 0)
      assert function_exported?(Knowledge, :load, 2)
    end

    test "o relatório vem completo mesmo quando reprova", %{base: base} do
      copiar_base_real(base)
      escrever(base, "schemas/quebrado.schema.yaml", "a: 1\na: 2\n")

      assert {:error, r} = Knowledge.inspect_base(base)

      # Um erro que descarta o que foi apurado obriga a rodar de novo só para saber o tamanho do
      # problema.
      assert r.arquivos_inspecionados > 0
      assert r.manifest != nil
      assert r.violacoes != []
    end
  end
end
