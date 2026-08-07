defmodule TheBand.Knowledge.ValidatorTest do
  @moduledoc """
  Issue #22 — validação estrita de campo por esquema.

  O caminho de aceitação já está provado pelo conjunto reservado: 22 arquivos passam. Estes testes
  provam o **caminho de recusa**, um defeito por caso. Uma validação que só foi vista aceitando não
  foi vista funcionando.
  """

  use ExUnit.Case, async: true

  alias TheBand.Knowledge.{Loader, Manifest, Schema, Validator}

  @base Path.expand("../../../priv/knowledge_base", __DIR__)

  setup_all do
    {esquemas, []} = Schema.load_all(@base)
    {:ok, manifesto} = Manifest.load(@base)
    {:ok, esquemas: esquemas, manifesto: manifesto}
  end

  defp validar(yaml, ctx) do
    {:ok, doc} = Loader.load_source(yaml, "teste.yaml")
    Validator.validate(doc, "teste.yaml", ctx.esquemas, ctx.manifesto)
  end

  defp mensagens(yaml, ctx), do: validar(yaml, ctx) |> Enum.map_join(" | ", & &1.message)

  # Um conceito válido, do qual cada teste remove ou altera UMA coisa.
  defp conceito(extra \\ "") do
    """
    concept:
      id: example.coisa
      schema_version: 1
      version: 1.0.0
      status: active
      ontology: example
      dependencies: []
      label:
        pt-BR: Coisa
        en: Thing
      definition:
        pt-BR: Uma coisa.
        en: A thing.
      classification:
        ufo_category: social_object
      attributes:
        - name: titulo
          type: string
          required: true
      provenance:
        source_type: example
    """ <> extra
  end

  describe "caminho de aceitação" do
    test "o conceito de referência passa sem violação", ctx do
      assert validar(conceito(), ctx) == []
    end

    test "a base entregue não tem violação de campo", ctx do
      # Se este teste reprovar, o conjunto reservado deixou de exercitar o caminho de aceitação — e
      # aí a maquinaria voltaria a não ter sujeito.
      arquivos = Path.wildcard(Path.join(@base, "examples/*.yaml"))
      assert length(arquivos) >= 9

      violacoes =
        Enum.flat_map(arquivos, fn c ->
          rel = Path.relative_to(c, @base)
          {:ok, doc} = Loader.load_file(c, base_dir: @base, label: rel)
          Validator.validate(doc, rel, ctx.esquemas, ctx.manifesto)
        end)

      assert violacoes == [], Enum.map_join(violacoes, "\n", & &1.message)
    end
  end

  describe "FR-008 — campo desconhecido" do
    test "recusa, e diz o que é permitido", ctx do
      m = mensagens(conceito("  campo_inventado: 1\n"), ctx)
      assert m =~ "campo desconhecido `campo_inventado`"
      assert m =~ "permite:"
    end

    test "aceita os campos que o esquema declara como opcionais", ctx do
      assert validar(conceito("  examples:\n    - um exemplo\n"), ctx) == []
    end
  end

  describe "FR-007 — as cinco declarações comuns" do
    for campo <- ~w(schema_version version id dependencies provenance) do
      test "recusa quando falta `#{campo}`", ctx do
        yaml = String.replace(conceito(), ~r/^  #{unquote(campo)}:.*(\n    .*)*/m, "")
        assert mensagens(yaml, ctx) =~ "obrigatório"
      end
    end

    test "campo declarado SEM VALOR é violação, não ausência", ctx do
      yaml = String.replace(conceito(), "  version: 1.0.0", "  version:")
      m = mensagens(yaml, ctx)
      assert m =~ "SEM VALOR"
      refute m =~ "ausente:", "campo vazio e campo ausente são erros diferentes"
    end

    test "`dependencies: []` é legítimo — lista vazia não é ausência", ctx do
      assert validar(conceito(), ctx) == []
    end
  end

  describe "FR-051 e FR-053 — identificador" do
    test "recusa maiúscula", ctx do
      yaml = String.replace(conceito(), "id: example.coisa", "id: example.Coisa")
      assert mensagens(yaml, ctx) =~ "fora da gramática"
    end

    test "recusa hífen", ctx do
      yaml = String.replace(conceito(), "id: example.coisa", "id: example.mi-nha")
      assert mensagens(yaml, ctx) =~ "fora da gramática"
    end

    test "recusa segmento iniciado por dígito", ctx do
      yaml = String.replace(conceito(), "id: example.coisa", "id: example.1coisa")
      assert mensagens(yaml, ctx) =~ "fora da gramática"
    end

    test "recusa prefixo que não bate com a ontologia declarada", ctx do
      yaml = String.replace(conceito(), "id: example.coisa", "id: outra.coisa")
      m = mensagens(yaml, ctx)
      assert m =~ "ambíguo quanto ao dono"
    end

    test "FR-012 — identificador coagido a número é recusado", ctx do
      yaml = String.replace(conceito(), "id: example.coisa", "id: 1.0")
      assert mensagens(yaml, ctx) =~ "interpretado como número"
    end
  end

  describe "FR-055 — uma versão viva por esquema" do
    test "recusa versão de esquema diferente do padrão do manifesto", ctx do
      yaml = String.replace(conceito(), "schema_version: 1", "schema_version: 2")
      m = mensagens(yaml, ctx)
      assert m =~ "UMA versão viva"
    end
  end

  describe "FR-066 e FR-068 — estado de maturidade" do
    test "recusa estado inexistente", ctx do
      yaml = String.replace(conceito(), "status: active", "status: rascunho")
      assert mensagens(yaml, ctx) =~ "não existe"
    end

    test "obsoleto sem substituto declarado reprova", ctx do
      yaml = String.replace(conceito(), "status: active", "status: deprecated")
      m = mensagens(yaml, ctx)
      assert m =~ "deprecated_in"
      assert m =~ "avisar quem depende ANTES de quebrar"
    end

    test "obsoleto completo passa", ctx do
      yaml =
        conceito()
        |> String.replace("status: active", "status: deprecated")
        |> Kernel.<>("""
          deprecated_in: 1.1.0
          superseded_by: example.artifact
          reason:
            pt-BR: motivo
            en: reason
        """)

      assert validar(yaml, ctx) == []
    end
  end

  describe "FR-058 — os dois idiomas exigidos" do
    test "recusa rótulo sem inglês", ctx do
      yaml = String.replace(conceito(), "    en: Thing\n", "")
      assert mensagens(yaml, ctx) =~ "não declara o idioma exigido `en`"
    end

    test "FR-061 — recusa idioma fora do registro do manifesto", ctx do
      yaml = String.replace(conceito(), "    en: Thing", "    en: Thing\n    fr: Chose")
      assert mensagens(yaml, ctx) =~ "não está entre os exigidos"
    end

    test "recusa valor único onde se espera texto por idioma", ctx do
      yaml =
        String.replace(conceito(), "  label:\n    pt-BR: Coisa\n    en: Thing", "  label: Coisa")

      assert mensagens(yaml, ctx) =~ "por idioma"
    end

    test "os campos traduzíveis vêm do ESQUEMA, não do código", ctx do
      # `name` é traduzível numa necessidade de informação e é nome canônico numa ontologia. Uma
      # lista fixa no código errava isso — a validação apontou, e a decisão foi para o esquema.
      assert "label" in ctx.esquemas["concept"].translatable
      refute "name" in ctx.esquemas["ontology"].translatable
      assert "name" in ctx.esquemas["information_need"].translatable
    end
  end

  describe "FR-074 — vocabulário fechado de proveniência" do
    test "recusa tipo de fonte inventado", ctx do
      yaml = String.replace(conceito(), "source_type: example", "source_type: inventado")
      m = mensagens(yaml, ctx)
      assert m =~ "não existe"
      assert m =~ "proveniência FALSA"
    end
  end

  describe "FR-093 e FR-094 — atributos" do
    test "recusa atributo sem tipo", ctx do
      yaml = String.replace(conceito(), "      type: string\n", "")
      m = mensagens(yaml, ctx)
      assert m =~ "não declara type"
      assert m =~ "quem implementa a persistência inventa"
    end

    test "recusa tipo genérico que não mapeia para persistência", ctx do
      yaml = String.replace(conceito(), "type: string", "type: numero")
      m = mensagens(yaml, ctx)
      assert m =~ "não mapeia sem ambiguidade"
    end
  end

  describe "raiz do documento" do
    test "recusa tipo desconhecido", ctx do
      assert mensagens("coisa_inventada:\n  id: x\n", ctx) =~ "tipo desconhecido"
    end

    test "recusa mais de uma chave de raiz", ctx do
      m = mensagens("concept:\n  id: a\nrelation:\n  id: b\n", ctx)
      assert m =~ "precisa de exatamente"
    end
  end
end
