defmodule TheBand.Telemetry.Handler do
  @moduledoc """
  Registro operacional estruturado (FR-028, FR-029, FR-030).

  Campos exigidos por FR-028, quando aplicáveis: `tenant_id`, `correlation_id`, `job_id`,
  `attempt`, `duration`, `status`, `error_code`.

  ## Por que a redação é feita na escrita, não na leitura

  FR-030 proíbe registrar credencial, token ou payload sensível completo. A proteção fica
  aqui, no ponto onde o valor entraria no registro, e não num filtro depois: filtro na
  saída depende de o valor já ter sido escrito em algum lugar, e num repositório e
  infraestrutura públicos isso é tarde.

  A lista de chaves sensíveis é intencionalmente ampla, e a correspondência é por
  **substring** do nome da chave. Falso positivo custa um campo redigido no diagnóstico.
  Falso negativo custa um segredo em registro permanente. A assimetria decide.
  """

  require Logger

  alias TheBand.Telemetry.Correlation

  @sensitive ~w(token secret password passwd senha key credential authorization auth
                cookie session bearer api_key apikey private signature)

  @redacted "[REDACTED]"

  @events [
    [:the_band, :job, :start],
    [:the_band, :job, :stop],
    [:the_band, :job, :exception],
    [:the_band, :tenancy, :scope, :rejected],
    [:the_band, :audit, :event, :recorded],
    [:the_band, :health, :check]
  ]

  @handler_id "the-band-telemetry-handler"

  @doc """
  Anexa os manipuladores. Idempotente: chamar duas vezes não duplica o registro.
  """
  @spec attach() :: :ok
  def attach do
    :telemetry.detach(@handler_id)
    :ok = :telemetry.attach_many(@handler_id, @events, &__MODULE__.handle_event/4, %{})
  end

  @doc false
  @spec handle_event(:telemetry.event_name(), map(), map(), map()) :: :ok
  def handle_event(event, measurements, metadata, _config) do
    fields =
      metadata
      |> Map.merge(measurements)
      |> redact()
      |> Map.put(:event, Enum.join(event, "."))
      |> Map.put(:correlation_id, metadata[:correlation_id] || Correlation.get())

    level = level_for(event)

    Logger.log(level, fn -> format(fields) end)
  end

  @doc """
  Redige valores sob chaves cujo nome sugira conteúdo sensível, recursivamente.

  Aplica-se a mapas e listas em qualquer profundidade. Uma chave sensível cujo valor seja
  um mapa é redigida por inteiro: preservar a estrutura interna vazaria os nomes dos
  campos, que já são informação.

  ## Exemplos

      iex> TheBand.Telemetry.Handler.redact(%{user: "ana", api_token: "abc123"})
      %{user: "ana", api_token: "[REDACTED]"}

      iex> TheBand.Telemetry.Handler.redact(%{args: %{"password" => "x", "id" => 1}})
      %{args: %{"password" => "[REDACTED]", "id" => 1}}
  """
  @spec redact(term()) :: term()
  def redact(map) when is_map(map) and not is_struct(map) do
    Map.new(map, fn {k, v} ->
      if sensitive?(k), do: {k, @redacted}, else: {k, redact(v)}
    end)
  end

  def redact(list) when is_list(list), do: Enum.map(list, &redact/1)
  def redact(other), do: other

  @doc """
  Diz se o nome de uma chave sugere conteúdo sensível.
  """
  @spec sensitive?(term()) :: boolean()
  def sensitive?(key) when is_atom(key), do: key |> Atom.to_string() |> sensitive?()

  def sensitive?(key) when is_binary(key) do
    down = String.downcase(key)
    Enum.any?(@sensitive, &String.contains?(down, &1))
  end

  def sensitive?(_), do: false

  @doc """
  Lista de fragmentos de nome tratados como sensíveis. Exposta para teste.
  """
  @spec sensitive_fragments() :: [String.t()]
  def sensitive_fragments, do: @sensitive

  defp level_for([:the_band, :job, :exception]), do: :error
  defp level_for([:the_band, :tenancy, :scope, :rejected]), do: :warning
  defp level_for(_), do: :info

  defp format(fields) do
    fields
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map_join(" ", fn {k, v} -> "#{k}=#{inspect(v)}" end)
  end
end
