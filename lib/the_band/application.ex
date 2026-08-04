defmodule TheBand.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias TheBand.Telemetry.Handler

  @impl true
  def start(_type, _args) do
    # Anexado antes de qualquer processo subir, para que nenhum evento seja perdido no
    # arranque — inclusive falha de conexão com o armazenamento.
    Handler.attach()

    children = [
      TheBandWeb.Telemetry,
      TheBand.Repo,
      {DNSCluster, query: Application.get_env(:the_band, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TheBand.PubSub},
      # Oban vem depois do Repo: precisa da conexão com o armazenamento para ler a fila.
      {Oban, Application.fetch_env!(:the_band, Oban)},
      # Start to serve requests, typically the last entry
      TheBandWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TheBand.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TheBandWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
