import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
# Host, usuário e senha vêm do ambiente para que o fluxo de verificação automática aponte
# para o serviço PostgreSQL que ele mesmo provisiona (FR-034), mantendo os padrões locais.
config :the_band, TheBand.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  port: String.to_integer(System.get_env("POSTGRES_PORT", "5432")),
  database: "the_band_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :the_band, TheBandWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  # Mesmo motivo de `config/dev.exs`: valor legível em vez de string aleatória, para não
  # parecer credencial vazada num repositório público. Só assina cookie em teste.
  secret_key_base: "test-only-signing-salt-not-a-secret-never-used-outside-mix-test-1",
  server: false

# Oban em modo manual: nenhum trabalho executa sozinho durante os testes. Cada teste
# enfileira e drena explicitamente o que quer verificar.
config :the_band, Oban, testing: :manual

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
