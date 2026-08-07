defmodule TheBand.Knowledge.Schema do
  @moduledoc """
  Um esquema de validação, carregado do próprio arquivo YAML que o declara.

  ## Os esquemas são dados, não código

  O que cada tipo exige está em `priv/knowledge_base/schemas/*.schema.yaml`, e este módulo apenas os
  lê. Acrescentar um campo obrigatório a conceitos é editar YAML, não Elixir.

  Isso importa porque a base de conhecimento é artefato de **domínio**: quem entende de ontologia
  precisa poder mudar a exigência sem tocar em código. E porque a alternativa — a lista de campos
  espalhada em cláusulas de função — divergiria do arquivo que a documenta.

  ## O que um esquema declara

      root_key    a chave única de raiz que o arquivo precisa ter
      required    campos obrigatórios além dos comuns
      optional      campos permitidos
      translatable  campos cujo texto é declarado por idioma
      common      as cinco declarações comuns a todo arquivo de conhecimento
      references  quais campos são referência a identificador (FR-082)

  Campo fora de `required ++ optional ++ common` é **desconhecido** e reprova (FR-008).
  """

  alias TheBand.Knowledge.Loader
  alias TheBand.Knowledge.TokenGate.Violation

  @enforce_keys [:id, :root_key, :required, :optional, :common, :references]
  defstruct [
    :id,
    :root_key,
    :describes,
    :required,
    :optional,
    :common,
    :references,
    :translatable
  ]

  @type t :: %__MODULE__{}

  @doc """
  Carrega todos os esquemas de uma base, indexados pela chave de raiz.

  Devolve também as violações dos esquemas que não puderam ser lidos. Um esquema ilegível **não** é
  ignorado em silêncio: os arquivos daquele tipo passariam a ser aceitos sem verificação alguma, e a
  contagem continuaria maior que zero (FR-089).
  """
  @spec load_all(Path.t()) :: {%{String.t() => t()}, [Violation.t()]}
  def load_all(base) do
    base
    |> Path.join("schemas/*.schema.yaml")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.reduce({%{}, []}, fn caminho, {mapa, violacoes} ->
      rel = Path.relative_to(caminho, base)

      case carregar(caminho, base, rel) do
        {:ok, esquema} -> {Map.put(mapa, esquema.root_key, esquema), violacoes}
        {:error, v} -> {mapa, violacoes ++ v}
      end
    end)
  end

  defp carregar(caminho, base, rel) do
    case Loader.load_file(caminho, base_dir: base, label: rel) do
      {:ok, %{"schema" => s}} when is_map(s) ->
        {:ok,
         %__MODULE__{
           id: to_string(s["id"] || ""),
           root_key: chave_de_raiz(s),
           describes: to_string(s["describes"] || ""),
           required: lista(s["required"]),
           optional: lista(s["optional"]),
           common: lista(s["common"]),
           references: lista(s["references"]),
           translatable: lista(s["translatable"])
         }}

      {:ok, _outro} ->
        {:error,
         [
           %Violation{
             kind: :not_a_mapping,
             path: rel,
             line: nil,
             column: nil,
             message: "esquema sem a chave de raiz `schema`"
           }
         ]}

      {:error, v} ->
        {:error, v}
    end
  end

  # O identificador do esquema usa hífen — `competency-question` —, e a chave de raiz do arquivo que
  # ele valida usa sublinhado: `competency_question`. Traduzir aqui mantém os nomes de arquivo
  # legíveis e as chaves YAML idiomáticas.
  defp chave_de_raiz(s) do
    (s["root_key"] || s["id"] || "")
    |> to_string()
    |> String.replace("-", "_")
  end

  defp lista(nil), do: []
  defp lista(l) when is_list(l), do: Enum.map(l, &to_string/1)
  defp lista(_), do: []

  @doc "Campos que um arquivo deste tipo pode declarar."
  @spec permitidos(t()) :: [String.t()]
  def permitidos(%__MODULE__{} = s) do
    (s.required ++ s.optional ++ s.common) |> Enum.uniq()
  end

  @doc """
  Campos obrigatórios: os do esquema mais as cinco declarações comuns.
  """
  @spec obrigatorios(t()) :: [String.t()]
  def obrigatorios(%__MODULE__{} = s), do: Enum.uniq(s.required ++ s.common)
end
