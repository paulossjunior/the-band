defmodule TheBandWeb.HealthDetailController do
  @moduledoc """
  Verificação de saúde **detalhada**, restrita a operação (FR-002, FR-004).

  Reporta o estado de cada componente. Só é alcançável através de
  `TheBandWeb.Plugs.OperatorSecret`, declarado no roteador.

  ## O corpo carrega apenas nome e estado do componente

  Nada de credencial, host, porta, versão de dependência ou rastro de pilha (FR-004). O
  estado é `up` ou `down` e nada mais: uma mensagem de erro do driver informaria host e às
  vezes usuário, e é justamente o que não deve sair daqui.

  Erro de componente já foi convertido em `:down` por `TheBand.Health`, que não propaga
  exceção. Assim uma dependência quebrada devolve 503 com diagnóstico, e não erro genérico.
  """

  use TheBandWeb, :controller

  def show(conn, _params) do
    report = TheBand.Health.detailed()

    conn
    |> put_status(http_status(report.status))
    |> json(%{
      status: Atom.to_string(report.status),
      components: Map.new(report.components, fn {k, v} -> {k, Atom.to_string(v)} end)
    })
  end

  defp http_status(:healthy), do: 200
  defp http_status(:unhealthy), do: 503
end
