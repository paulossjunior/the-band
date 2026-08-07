defmodule TheBand.Knowledge.Manifest do
  @moduledoc """
  O manifesto da base de conhecimento, e as regras que só valem para ele.

  ## "Mesmo rigor", nunca "mesma lista de campos"

  FR-003 diz que o manifesto é validado com as mesmas exigências dos demais arquivos. Lido como
  "mesma lista de campos", produz contradição: um manifesto **proposto** ou **obsoleto** não faz
  sentido, e um manifesto com rótulo em dois idiomas é campo cerimonial.

  FR-088 resolve declarando **explicitamente** o que se aplica: o manifesto declara versão, idiomas
  exigidos, política de validação, ontologias presentes e exigência de proveniência. Não declara
  identificador estável, dependências, proveniência própria, estado de maturidade nem rótulo.

  ## A política de validação é declarativa, não é interruptor

  FR-004. Valor diferente de estrito faz o **próprio manifesto** ser recusado — a validação não é
  afrouxada. É a diferença entre um campo que descreve e um campo que controla, e este projeto já
  pagou o preço de confundir os dois: na feature 001, uma checagem de análise estática que não
  carregava saía com código de sucesso.
  """

  alias TheBand.Knowledge.Loader
  alias TheBand.Knowledge.TokenGate.Violation

  @raiz "knowledge_base"

  @obrigatorios ~w(name version default_language required_languages default_schema_version
                   ontologies validation provenance)

  defstruct [
    :name,
    :version,
    :default_language,
    :required_languages,
    :default_schema_version,
    :ontologies,
    :provenance_required
  ]

  @type t :: %__MODULE__{}

  @doc "Caminho do manifesto dentro de uma base."
  @spec path(Path.t()) :: Path.t()
  def path(base), do: Path.join(base, "manifest.yaml")

  @doc """
  Carrega e valida o manifesto de uma base.
  """
  @spec load(Path.t()) :: {:ok, t()} | {:error, [Violation.t()]}
  def load(base) do
    caminho = path(base)
    rotulo = Path.relative_to(caminho, base)

    if File.exists?(caminho) do
      with {:ok, doc} <- Loader.load_file(caminho, base_dir: base, label: rotulo) do
        validar(doc, rotulo)
      end
    else
      {:error,
       [
         v(
           rotulo,
           "a base de conhecimento não tem manifesto. Ele é o ponto de entrada: sem ele não se sabe " <>
             "quais idiomas são exigidos, qual versão de esquema vale, nem quais ontologias a base " <>
             "contém"
         )
       ]}
    end
  end

  defp validar(doc, path) do
    with {:ok, kb} <- raiz(doc, path),
         :ok <- campos_obrigatorios(kb, path),
         :ok <- politica_estrita(kb, path),
         :ok <- idiomas(kb, path),
         :ok <- proveniencia(kb, path) do
      {:ok,
       %__MODULE__{
         name: kb["name"],
         version: to_string(kb["version"]),
         default_language: kb["default_language"],
         required_languages: kb["required_languages"],
         default_schema_version: kb["default_schema_version"],
         ontologies: kb["ontologies"] || [],
         provenance_required: get_in(kb, ["provenance", "required"])
       }}
    end
  end

  defp raiz(%{@raiz => kb}, _path) when is_map(kb), do: {:ok, kb}

  defp raiz(doc, path) do
    chaves = doc |> Map.keys() |> Enum.sort() |> Enum.join(", ")

    {:error,
     [
       v(
         path,
         "o manifesto precisa de uma única chave de raiz `#{@raiz}` com um mapeamento dentro. " <>
           "Encontrado: #{if chaves == "", do: "nada", else: chaves}"
       )
     ]}
  end

  defp campos_obrigatorios(kb, path) do
    faltando = Enum.reject(@obrigatorios, &Map.has_key?(kb, &1))

    vazios =
      Enum.filter(@obrigatorios, fn campo ->
        Map.has_key?(kb, campo) and Map.get(kb, campo) in [nil, ""]
      end)

    cond do
      faltando != [] ->
        {:error, [v(path, "o manifesto não declara: #{Enum.join(faltando, ", ")}")]}

      # Campo declarado sem valor é VIOLAÇÃO, não ausência (FR-007). São erros diferentes de quem
      # escreve, e confundi-los faz a pessoa procurar no lugar errado.
      vazios != [] ->
        {:error,
         [
           v(
             path,
             "o manifesto declara sem valor: #{Enum.join(vazios, ", ")}. " <>
               "Campo declarado sem valor é diferente de campo ausente"
           )
         ]}

      true ->
        :ok
    end
  end

  defp politica_estrita(
         %{"validation" => %{"strict" => true, "reject_unknown_fields" => true}},
         _
       ),
       do: :ok

  defp politica_estrita(%{"validation" => v}, path) do
    {:error,
     [
       v(
         path,
         "a política de validação precisa declarar `strict: true` e `reject_unknown_fields: true`. " <>
           "Encontrado: #{inspect(v)}. Este campo é DECLARATIVO, não um interruptor: valor " <>
           "diferente recusa o próprio manifesto, e não afrouxa a validação (FR-004)"
       )
     ]}
  end

  defp politica_estrita(_, path), do: {:error, [v(path, "a política de validação está ausente")]}

  defp idiomas(%{"required_languages" => idiomas, "default_language" => padrao}, path)
       when is_list(idiomas) do
    cond do
      idiomas == [] ->
        {:error, [v(path, "`required_languages` não pode ser lista vazia")]}

      padrao not in idiomas ->
        {:error,
         [
           v(
             path,
             "o idioma padrão `#{padrao}` não está entre os exigidos #{inspect(idiomas)}. " <>
               "Um padrão que não é exigido não seria escrito em lugar algum"
           )
         ]}

      true ->
        :ok
    end
  end

  defp idiomas(_, path), do: {:error, [v(path, "`required_languages` precisa ser uma lista")]}

  defp proveniencia(%{"provenance" => %{"required" => true}}, _), do: :ok

  defp proveniencia(_, path) do
    {:error,
     [
       v(
         path,
         "a base precisa declarar `provenance.required: true`. A proveniência é o que permite " <>
           "responder de onde veio o que a base afirma, e torná-la opcional esvaziaria o " <>
           "princípio III"
       )
     ]}
  end

  defp v(path, message) do
    %Violation{kind: :syntax, path: path, line: nil, column: nil, message: message}
  end
end
