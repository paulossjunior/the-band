defmodule TheBandWeb.Plugs.OperatorSecret do
  @moduledoc """
  Exige o segredo de operação (FR-003, SC-009).

  ## As três recusas são indistinguíveis

  Sem cabeçalho, com segredo errado, e com segredo ausente da configuração do servidor
  produzem a mesma situação e o mesmo corpo. Distinguir a terceira informaria a quem sonda que
  a instalação está com configuração faltando — exatamente quando ela é mais frágil.

  ## Segredo ausente recusa, nunca libera

  Um plug que libera quando não há segredo configurado transforma erro de implantação em porta
  aberta. Aqui a ausência é tratada como recusa.

  ## Comparação em tempo constante

  `Plug.Crypto.secure_compare/2` para não permitir inferir o segredo por medição de tempo.
  Comparação com `==` sai no primeiro byte diferente, e a diferença é mensurável em rede.
  """

  @behaviour Plug

  import Plug.Conn

  @scheme "Bearer "

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    if authorized?(conn), do: conn, else: refuse(conn)
  end

  defp authorized?(conn) do
    with {:ok, expected} <- configured_secret(),
         {:ok, provided} <- presented_secret(conn) do
      Plug.Crypto.secure_compare(provided, expected)
    else
      :error -> false
    end
  end

  # String vazia é tratada como não configurado: aceitá-la faria um cabeçalho vazio casar e
  # abriria o caminho detalhado.
  defp configured_secret do
    case Application.get_env(:the_band, :operator_secret) do
      secret when is_binary(secret) and secret != "" -> {:ok, secret}
      _ -> :error
    end
  end

  defp presented_secret(conn) do
    case get_req_header(conn, "authorization") do
      [@scheme <> secret] when secret != "" -> {:ok, secret}
      _ -> :error
    end
  end

  defp refuse(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, ~s({"error":"unauthorized"}))
    |> halt()
  end
end
