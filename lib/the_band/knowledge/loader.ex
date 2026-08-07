defmodule TheBand.Knowledge.Loader do
  @moduledoc """
  Segunda passagem: constrói o termo, **depois** que o portão de tokens deixou passar.

  ## Sempre `read_all_from_string/2`, nunca `read_from_string/2`

  Medido em `research.md` R8, e a diferença não é estilo:

      "a: 1\\n---\\nb: 2"
        read_from_string      -> {:ok, %{"b" => 2}}            DESCARTA o primeiro em silêncio
        read_all_from_string  -> {:ok, [%{"a" => 1}, %{...}]}

      ""
        read_from_string      -> {:ok, %{}}                    indistinguível de mapeamento vazio
        read_all_from_string  -> {:ok, []}                     distingue

  Exigir lista de tamanho exatamente 1 satisfaz FR-071 inteiro numa verificação: um documento por
  arquivo, arquivo vazio recusado, arquivo só com comentário recusado.

  Há teste que reprova se `read_from_string` aparecer neste módulo. Sem ele, alguém "simplifica" e
  reintroduz o descarte silencioso.
  """

  alias TheBand.Knowledge.TokenGate
  alias TheBand.Knowledge.TokenGate.Violation

  @doc """
  Carrega um arquivo: portão de tokens, depois construção.

  A ordem importa e é o desenho da ADR-0005 — o portão recusa **antes** de qualquer termo ser
  construído, porque um arquivo de 814 bytes de apelidos aninhados mata o processo na construção.
  """
  @spec load_file(Path.t(), keyword()) :: {:ok, map()} | {:error, [Violation.t()]}
  def load_file(path, opts \\ []) do
    rotulo = Keyword.get(opts, :label, path)

    with :ok <- TokenGate.inspect_file(path, opts),
         {:ok, bytes} <- ler(path, rotulo) do
      construir(bytes, rotulo)
    end
  end

  @doc """
  Carrega conteúdo bruto. `path` só serve para as mensagens.
  """
  @spec load_source(binary(), Path.t()) :: {:ok, map()} | {:error, [Violation.t()]}
  def load_source(bytes, path) do
    with :ok <- TokenGate.inspect_source(bytes, path) do
      construir(bytes, path)
    end
  end

  defp construir(bytes, path) do
    case YamlElixir.read_all_from_string(bytes) do
      {:ok, [documento]} when is_map(documento) ->
        {:ok, documento}

      {:ok, [outro]} ->
        {:error,
         [
           v(
             :not_a_mapping,
             path,
             "a raiz do documento é #{tipo(outro)}, e todo arquivo da base tem um mapeamento na raiz"
           )
         ]}

      {:ok, []} ->
        # O portão já recusa isto. Chegar aqui significa que o portão e o construtor discordam sobre
        # quantos documentos existem — e discordância silenciosa entre as duas passagens é pior que
        # qualquer uma delas errar sozinha.
        {:error,
         [
           v(
             :empty_document,
             path,
             "o construtor não encontrou documento algum, e o portão de tokens deixou passar. " <>
               "As duas passagens discordam — isto é defeito da validação, não do arquivo"
           )
         ]}

      {:ok, muitos} ->
        {:error,
         [
           v(
             :multiple_documents,
             path,
             "o construtor encontrou #{length(muitos)} documentos, e o portão de tokens deixou " <>
               "passar. As duas passagens discordam — isto é defeito da validação"
           )
         ]}

      {:error, %{__struct__: _} = erro} ->
        {:error, [de_erro_do_interpretador(erro, path)]}
    end
  rescue
    e in YamlElixir.ParsingError ->
      {:error, [de_erro_do_interpretador(e, path)]}
  end

  defp de_erro_do_interpretador(erro, path) do
    linha = posicao(Map.get(erro, :line))
    coluna = posicao(Map.get(erro, :column))
    tipo = Map.get(erro, :type, :desconhecido)

    %Violation{
      kind: :syntax,
      path: path,
      line: linha,
      column: coluna,
      message: "documento YAML inválido: #{tipo}"
    }
  end

  # A biblioteca devolve `:undefined` quando não sabe a posição — medido em R9 para byte que não é
  # UTF-8 válido. Traduzir para `nil` mantém a distinção "não tem posição" explícita.
  defp posicao(n) when is_integer(n), do: n
  defp posicao(_), do: nil

  defp tipo(v) when is_list(v), do: "uma lista"
  defp tipo(v) when is_binary(v), do: "um texto"
  defp tipo(v) when is_number(v), do: "um número"
  defp tipo(nil), do: "vazia"
  defp tipo(_), do: "de outro tipo"

  defp ler(path, rotulo) do
    case File.read(path) do
      {:ok, bytes} ->
        {:ok, bytes}

      {:error, motivo} ->
        {:error, [v(:syntax, rotulo, "não foi possível ler: #{:file.format_error(motivo)}")]}
    end
  end

  defp v(kind, path, message) do
    %Violation{kind: kind, path: path, line: nil, column: nil, message: message}
  end
end
