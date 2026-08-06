defmodule TheBand.Knowledge.TokenGate.Violation do
  @moduledoc """
  Uma recusa do portão de tokens, com o lugar exato.

  A mensagem tem de permitir que uma pessoa localize e corrija o problema **sem abrir o código da
  validação** — é o critério SC-013. Por isso `line` e `column` não são opcionais por conveniência:
  quando vêm `nil`, é porque a biblioteca não os forneceu, e isso está registrado.

  O único caso medido em que a posição não existe é byte que não é UTF-8 válido: `yaml_elixir`
  devolve `line: :undefined, column: :undefined` (research.md R9). Nesse caso a mensagem nomeia o
  arquivo e a razão, sem posição.
  """

  @type kind ::
          :anchor
          | :alias
          | :duplicate_key
          | :tab_indentation
          | :multiple_documents
          | :empty_document
          | :not_a_mapping
          | :invalid_encoding
          | :too_large
          | :too_slow
          | :syntax
          | :symlink_outside_base

  @type t :: %__MODULE__{
          kind: kind(),
          path: String.t(),
          line: pos_integer() | nil,
          column: pos_integer() | nil,
          message: String.t()
        }

  @enforce_keys [:kind, :path, :message]
  defstruct [:kind, :path, :line, :column, :message]

  @doc """
  Texto de uma linha, no formato que ferramentas de editor e humanos leem igual.

      priv/knowledge_base/x.yaml:12:3: âncora não é permitida na base de conhecimento
  """
  @spec to_line(t()) :: String.t()
  def to_line(%__MODULE__{} = v) do
    posicao =
      case {v.line, v.column} do
        {nil, _} -> ""
        {l, nil} -> ":#{l}"
        {l, c} -> ":#{l}:#{c}"
      end

    "#{v.path}#{posicao}: #{v.message}"
  end
end
