defmodule TheBand.Telemetry.Correlation do
  @moduledoc """
  Identificador de correlação, propagado por requisição e por unidade de trabalho.

  FR-029 exige poder reconstituir a cadeia de execução. Sem um identificador que atravesse
  requisição, trabalho em segundo plano e registro operacional, diagnosticar uma falha vira
  arqueologia de horário: dois eventos próximos no tempo são indistinguíveis.

  O valor vive no dicionário do processo, e não num argumento passado adiante, porque a
  alternativa seria acrescentar um parâmetro a toda função da plataforma. Cada processo é
  responsável por herdar explicitamente o valor de quem o originou — ver `put/1`.
  """

  @key :the_band_correlation_id

  @doc """
  Gera um identificador novo. Não altera o processo atual.
  """
  @spec generate() :: String.t()
  def generate do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  @doc """
  Define o identificador do processo atual e devolve o valor definido.

  Processo em segundo plano precisa chamar isto com o identificador recebido de quem o
  enfileirou: o dicionário do processo não é herdado automaticamente.
  """
  @spec put(String.t()) :: String.t()
  def put(id) when is_binary(id) do
    Process.put(@key, id)
    id
  end

  @doc """
  Devolve o identificador do processo atual, ou `nil` quando não houver.

  Devolve `nil` em vez de gerar sob demanda: gerar aqui produziria identificadores
  diferentes a cada leitura, quebrando exatamente a correlação que o módulo existe para
  garantir. Quem precisa de um valor garantido usa `ensure/0`.
  """
  @spec get() :: String.t() | nil
  def get, do: Process.get(@key)

  @doc """
  Devolve o identificador do processo atual, gerando e definindo um se não houver.
  """
  @spec ensure() :: String.t()
  def ensure do
    case get() do
      nil -> put(generate())
      id -> id
    end
  end

  @doc """
  Remove o identificador do processo atual.

  Necessário em processos reaproveitados de pool: sem limpar, o trabalho seguinte herdaria
  a correlação do anterior e o rastro apontaria para a execução errada.
  """
  @spec clear() :: :ok
  def clear do
    Process.delete(@key)
    :ok
  end

  @doc """
  Nome do cabeçalho HTTP usado para propagar o identificador entre serviços.
  """
  @spec header() :: String.t()
  def header, do: "x-correlation-id"

  @doc """
  Valida um identificador recebido de fora.

  Aceita apenas caracteres seguros para URL e registro, com 8 a 128 caracteres. Um valor
  externo entra em registro operacional; sem validação, quem chama poderia injetar quebra
  de linha e forjar entradas de log.
  """
  @spec valid?(term()) :: boolean()
  def valid?(id) when is_binary(id) do
    byte_size(id) in 8..128 and Regex.match?(~r/\A[A-Za-z0-9_-]+\z/, id)
  end

  def valid?(_), do: false
end
