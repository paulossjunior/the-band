defmodule TheBandWeb.Router do
  use TheBandWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TheBandWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Exige o segredo de operação. Existe como pipeline própria para que a proteção seja visível
  # na declaração da rota, e não escondida dentro do controlador.
  pipeline :operator do
    plug :accepts, ["json"]
    plug TheBandWeb.Plugs.OperatorSecret
  end

  scope "/", TheBandWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Verificação de saúde — DOIS caminhos distintos, não um caminho com corpo variável
  # (FR-001 a FR-004, decisão registrada em research.md R9).
  #
  # Separar os caminhos, em vez de variar o corpo conforme autorização, evita que um defeito
  # de autorização exponha o corpo detalhado: o controlador público não sabe produzir o
  # detalhado, então não há como ele escapar por ali.

  scope "/health", TheBandWeb do
    pipe_through :api

    get "/", HealthController, :show
  end

  scope "/health/detail", TheBandWeb do
    pipe_through :operator

    get "/", HealthDetailController, :show
  end
end
