defmodule TheBandWeb.Plugs.CorrelationId do
  @moduledoc """
  Propaga o identificador de correlação por requisição (FR-029).

  Reaproveita o valor recebido no cabeçalho quando ele é válido, para que a cadeia
  atravesse a fronteira entre serviços. Gera um novo quando o cabeçalho está ausente ou
  o valor é inaceitável — um valor externo termina em registro operacional, e aceitá-lo
  sem validar permitiria injetar quebra de linha e forjar entradas de log.

  O valor sempre volta na resposta, para que quem chamou consiga correlacionar do seu lado.
  """

  @behaviour Plug

  alias TheBand.Telemetry.Correlation

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    id =
      case Plug.Conn.get_req_header(conn, Correlation.header()) do
        [received | _] ->
          if Correlation.valid?(received), do: received, else: Correlation.generate()

        [] ->
          Correlation.generate()
      end

    Correlation.put(id)

    # Também vai para os metadados do Logger, para que qualquer linha registrada durante a
    # requisição carregue a correlação sem precisar passá-la adiante.
    Logger.metadata(correlation_id: id)

    conn
    |> Plug.Conn.put_resp_header(Correlation.header(), id)
    |> Plug.Conn.assign(:correlation_id, id)
  end
end
