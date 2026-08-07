defmodule TheBand.Knowledge.Validator do
  @moduledoc """
  Validação estrita de um arquivo de conhecimento contra o esquema que ele declara.

  ## O que esta validação cobre, exatamente

  - **campo desconhecido na raiz do tipo** reprova (FR-008), com a lista do que é permitido;
  - as **cinco declarações comuns** — `schema_version`, `version`, `id`, `dependencies`,
    `provenance` — e campo declarado **sem valor** é violação, não ausência (FR-007);
  - **gramática do identificador**: minúsculas, dígitos, sublinhado, ponto como separador, cada
    segmento começando por letra (FR-051);
  - **propriedade pelo campo de ontologia declarado**, nunca pelo texto do identificador (FR-052), e
    o primeiro segmento tem de coincidir com a ontologia declarada (FR-053);
  - **versão de esquema** igual ao padrão do manifesto (FR-055);
  - **estado de maturidade** entre proposto, ativo e obsoleto, e obsoleto declara substituto (FR-066,
    FR-068);
  - **os dois idiomas exigidos** em todo rótulo e definição (FR-058), derivados do manifesto e não
    fixados no código (FR-059);
  - **proveniência** com tipo de fonte de vocabulário fechado (FR-074);
  - **atributos** com nome, tipo e obrigatoriedade, e tipo de vocabulário fechado (FR-093, FR-094).

  ## O que ela NÃO cobre, e está dito porque omitir seria pior

  **Campo desconhecido em nível aninhado arbitrário.** FR-008 exige qualquer nível; esta versão
  verifica a raiz do tipo e as estruturas cuja forma o esquema descreve — rótulo, definição,
  atributos, proveniência. Um campo inventado dentro de `formula` de uma medida, por exemplo, passa.

  Fechá-lo exige que os esquemas descrevam a forma aninhada, e isso é trabalho próprio. Registrado
  aqui e no relatório em vez de deixar a impressão de cobertura total — porque uma validação que
  promete mais do que verifica é a mentira que esta feature existe para evitar.

  Também não cobre: referência a identificador inexistente e ciclo entre ontologias (issue #24), e
  perguntas de competência (issue #26).
  """

  alias TheBand.Knowledge.{Manifest, Schema}
  alias TheBand.Knowledge.TokenGate.Violation

  # FR-051. Cada segmento começa por letra minúscula; dígitos e sublinhado depois; ponto separa.
  @grafia_do_identificador ~r/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$/

  # FR-066. Vocabulário fechado — qualquer outro valor reprova.
  @estados ~w(proposed active deprecated)

  # FR-074. `example` existe para o conjunto reservado: declará-lo como derivado de ontologia de
  # referência seria proveniência FALSA — pior que ausente, porque passa pela verificação.
  @tipos_de_fonte ~w(reference_ontology thesis standard specification example internal)

  # FR-094. Precisa mapear sem ambiguidade para um tipo de persistência: "número" não serve, porque
  # inteiro, decimal e ponto flutuante têm consequências diferentes em banco.
  @tipos_de_atributo ~w(string text integer decimal float boolean date datetime duration uuid)

  @doc """
  Valida um documento já construído.

  `esquemas` vem de `Schema.load_all/1`, e `manifesto` de `Manifest.load/1` — os dois são dados da
  própria base, não constantes do código.
  """
  @spec validate(map(), Path.t(), %{String.t() => Schema.t()}, Manifest.t()) :: [Violation.t()]
  def validate(documento, path, esquemas, manifesto) do
    case Map.to_list(documento) do
      [{raiz, corpo}] when is_map(corpo) ->
        case Map.fetch(esquemas, raiz) do
          {:ok, esquema} -> validar_corpo(corpo, raiz, path, esquema, manifesto)
          :error -> [v(path, "tipo desconhecido `#{raiz}`. Tipos: #{tipos(esquemas)}")]
        end

      [{raiz, _}] ->
        [v(path, "a chave de raiz `#{raiz}` precisa conter um mapeamento")]

      [] ->
        [v(path, "documento vazio")]

      muitas ->
        chaves = muitas |> Enum.map(&elem(&1, 0)) |> Enum.sort() |> Enum.join(", ")

        [
          v(
            path,
            "o arquivo tem #{length(muitas)} chaves de raiz (#{chaves}), e precisa de exatamente " <>
              "uma — o tipo do arquivo"
          )
        ]
    end
  end

  defp validar_corpo(corpo, raiz, path, esquema, manifesto) do
    Enum.concat([
      desconhecidos(corpo, path, esquema),
      obrigatorios(corpo, path, esquema),
      identificador(corpo, path, raiz),
      versao_de_esquema(corpo, path, manifesto),
      estado(corpo, path),
      idiomas(corpo, path, esquema, manifesto),
      proveniencia(corpo, path),
      atributos(corpo, path)
    ])
  end

  # ── campos ──────────────────────────────────────────────────────────────────────────────────

  defp desconhecidos(corpo, path, esquema) do
    permitidos = Schema.permitidos(esquema)

    # `deprecated_in`, `superseded_by` e `reason` só fazem sentido em arquivo obsoleto, e por isso
    # não estão em nenhum esquema. Permiti-los sempre seria frouxo; a exigência de que apareçam
    # apenas com `status: deprecated` está em `estado/2`.
    extras_de_descontinuacao = ~w(deprecated_in superseded_by reason)

    corpo
    |> Map.keys()
    |> Enum.reject(&(&1 in permitidos or &1 in extras_de_descontinuacao))
    |> Enum.sort()
    |> Enum.map(fn campo ->
      v(
        path,
        "campo desconhecido `#{campo}`. O esquema `#{esquema.id}` permite: " <>
          Enum.join(Enum.sort(permitidos), ", ")
      )
    end)
  end

  defp obrigatorios(corpo, path, esquema) do
    exigidos = Schema.obrigatorios(esquema)

    ausentes =
      exigidos
      |> Enum.reject(&Map.has_key?(corpo, &1))
      |> Enum.map(&v(path, "campo obrigatório ausente: `#{&1}`"))

    vazios =
      exigidos
      |> Enum.filter(&(Map.has_key?(corpo, &1) and vazio?(Map.get(corpo, &1))))
      |> Enum.map(fn campo ->
        # FR-007. Erros diferentes de quem escreve: confundi-los faz procurar no lugar errado.
        v(
          path,
          "campo obrigatório `#{campo}` declarado SEM VALOR. Isto é diferente de campo ausente"
        )
      end)

    ausentes ++ vazios
  end

  # Lista vazia declarada é legítima — `dependencies: []` diz "não depende de nada", e é diferente de
  # omitir o campo (FR-007).
  defp vazio?(nil), do: true
  defp vazio?(""), do: true
  defp vazio?(%{} = m), do: map_size(m) == 0
  defp vazio?(_), do: false

  # ── identificador ───────────────────────────────────────────────────────────────────────────

  defp identificador(corpo, path, _raiz) do
    case Map.get(corpo, "id") do
      nil ->
        []

      id when is_binary(id) ->
        grafia =
          if Regex.match?(@grafia_do_identificador, id), do: [], else: [erro_de_grafia(path, id)]

        grafia ++ prefixo(corpo, path, id)

      outro ->
        # FR-012. `1.0` vira número, e `id: 1.2.3` já é texto por acaso. Tratar sempre como texto
        # torna a coerção detectável em vez de silenciosa.
        [
          v(
            path,
            "o identificador foi interpretado como #{tipo_de(outro)} (#{inspect(outro)}), e " <>
              "identificador é sempre texto. Cite-o entre aspas"
          )
        ]
    end
  end

  defp erro_de_grafia(path, id) do
    v(
      path,
      "identificador `#{id}` fora da gramática: minúsculas, dígitos e sublinhado, em segmentos " <>
        "separados por ponto, cada segmento começando por letra"
    )
  end

  # FR-053. Onde o arquivo declara ontologia, o primeiro segmento tem de coincidir. Mapeamento,
  # necessidade de informação e medida não declaram ontologia própria e não têm essa obrigação
  # (FR-054).
  defp prefixo(corpo, path, id) do
    case Map.get(corpo, "ontology") do
      nil ->
        []

      ontologia when is_binary(ontologia) ->
        primeiro = id |> String.split(".") |> List.first()

        if primeiro == ontologia do
          []
        else
          [
            v(
              path,
              "o identificador começa por `#{primeiro}` e o arquivo declara `ontology: " <>
                "#{ontologia}`. Um conceito que declara pertencer a uma ontologia e se identifica " <>
                "com o prefixo de outra é ambíguo quanto ao dono"
            )
          ]
        end

      _ ->
        []
    end
  end

  # ── versão de esquema, estado, idiomas ──────────────────────────────────────────────────────

  defp versao_de_esquema(corpo, path, manifesto) do
    esperada = manifesto.default_schema_version

    case Map.get(corpo, "schema_version") do
      nil ->
        []

      ^esperada ->
        []

      outra ->
        [
          v(
            path,
            "declara versão de esquema #{inspect(outra)}, e o manifesto define #{inspect(esperada)}. " <>
              "Existe UMA versão viva por esquema: elevar migra todos os arquivos daquele tipo no " <>
              "mesmo conjunto de mudanças"
          )
        ]
    end
  end

  defp estado(corpo, path) do
    case Map.get(corpo, "status") do
      nil ->
        []

      "deprecated" ->
        # FR-068. Obsoleto sem substituto declarado nem afirmação de ausência deixa quem depende sem
        # para onde ir.
        faltando = Enum.reject(~w(deprecated_in superseded_by reason), &Map.has_key?(corpo, &1))

        if faltando == [] do
          []
        else
          [
            v(
              path,
              "arquivo obsoleto precisa declarar #{Enum.join(faltando, ", ")}. O caminho de " <>
                "descontinuação existe para avisar quem depende ANTES de quebrar"
            )
          ]
        end

      estado when estado in @estados ->
        []

      outro ->
        [
          v(
            path,
            "estado de maturidade #{inspect(outro)} não existe. São: #{Enum.join(@estados, ", ")}"
          )
        ]
    end
  end

  # FR-058 e FR-059. Os idiomas vêm do manifesto e os campos traduzíveis vêm do ESQUEMA — nenhum dos
  # dois está fixado no código.
  #
  # A primeira versão usava uma lista fixa aqui, e ela estava errada: `name` é traduzível numa
  # necessidade de informação e é nome canônico numa ontologia. A validação apontou, e a correção foi
  # mover a decisão para onde ela pertence.
  #
  # `reason` acompanha a descontinuação e não está em esquema algum, por isso entra à parte.
  defp idiomas(corpo, path, esquema, manifesto) do
    exigidos = manifesto.required_languages
    campos = esquema.translatable ++ ["reason"]

    campos
    |> Enum.filter(&Map.has_key?(corpo, &1))
    |> Enum.flat_map(&campo_traduzivel(Map.get(corpo, &1), &1, path, exigidos))
  end

  defp campo_traduzivel(%{} = traducoes, campo, path, exigidos) do
    ausentes =
      exigidos
      |> Enum.reject(&Map.has_key?(traducoes, &1))
      |> Enum.map(&v(path, "`#{campo}` não declara o idioma exigido `#{&1}`"))

    # FR-061. O campo de rótulo não é dicionário livre: idioma que o manifesto não registra reprova.
    extras =
      (Map.keys(traducoes) -- exigidos)
      |> Enum.map(
        &v(
          path,
          "`#{campo}` declara o idioma `#{&1}`, que não está entre os exigidos pelo manifesto " <>
            "(#{Enum.join(exigidos, ", ")})"
        )
      )

    ausentes ++ extras
  end

  defp campo_traduzivel(_, campo, path, _exigidos) do
    [v(path, "`#{campo}` precisa declarar o texto por idioma, e não um valor único")]
  end

  # ── proveniência e atributos ────────────────────────────────────────────────────────────────

  defp proveniencia(corpo, path) do
    case Map.get(corpo, "provenance") do
      %{"source_type" => tipo} when tipo in @tipos_de_fonte ->
        []

      %{"source_type" => outro} ->
        [
          v(
            path,
            "tipo de fonte #{inspect(outro)} não existe. São: #{Enum.join(@tipos_de_fonte, ", ")}. " <>
              "O vocabulário é fechado porque declarar exemplo como derivado de ontologia de " <>
              "referência seria proveniência FALSA — pior que ausente, porque passa"
          )
        ]

      %{} ->
        [v(path, "a proveniência não declara `source_type`")]

      nil ->
        []

      _ ->
        [v(path, "a proveniência precisa ser um mapeamento")]
    end
  end

  defp atributos(corpo, path) do
    case Map.get(corpo, "attributes") do
      nil ->
        []

      lista when is_list(lista) ->
        lista
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {attr, i} -> atributo(attr, i, path) end)

      _ ->
        [v(path, "`attributes` precisa ser uma lista")]
    end
  end

  defp atributo(%{} = attr, i, path) do
    faltando = Enum.reject(~w(name type required), &Map.has_key?(attr, &1))

    erros_de_forma =
      if faltando == [],
        do: [],
        else: [
          v(
            path,
            "atributo ##{i} não declara #{Enum.join(faltando, ", ")}. Sem nome, tipo e " <>
              "obrigatoriedade, quem implementa a persistência inventa"
          )
        ]

    erros_de_tipo =
      case Map.get(attr, "type") do
        nil -> []
        t when t in @tipos_de_atributo -> []
        outro -> [erro_de_tipo(path, i, outro)]
      end

    erros_de_forma ++ erros_de_tipo
  end

  defp atributo(_, i, path), do: [v(path, "atributo ##{i} precisa ser um mapeamento")]

  defp erro_de_tipo(path, i, tipo) do
    v(
      path,
      "atributo ##{i} declara tipo #{inspect(tipo)}, que não mapeia sem ambiguidade para " <>
        "persistência. São: #{Enum.join(@tipos_de_atributo, ", ")}"
    )
  end

  # ── auxiliares ──────────────────────────────────────────────────────────────────────────────

  defp tipos(esquemas), do: esquemas |> Map.keys() |> Enum.sort() |> Enum.join(", ")

  defp tipo_de(v) when is_number(v), do: "número"
  defp tipo_de(v) when is_boolean(v), do: "booleano"
  defp tipo_de(v) when is_list(v), do: "lista"
  defp tipo_de(_), do: "outro tipo"

  defp v(path, message) do
    %Violation{kind: :schema, path: path, line: nil, column: nil, message: message}
  end
end
