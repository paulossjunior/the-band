import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/the_band start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :the_band, TheBandWeb.Endpoint, server: true
end

alias TheBand.Config, as: Env

config :the_band, TheBandWeb.Endpoint, http: [port: Env.get_env_integer("PORT", 4000)]

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :the_band, TheBandWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/the_band_web/router\.ex$"E,
        ~r"lib/the_band_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  # FR-007 — nenhuma variável obrigatória tem valor padrão em produção.
  #
  # `Env.require_env!/2` levanta nomeando a variável ausente. A alternativa — cair num
  # padrão — faria a plataforma subir com configuração que ninguém escolheu, que é o modo
  # de falha que este requisito existe para impedir.
  #
  # Em desenvolvimento e teste, `DATABASE_URL` e `SECRET_KEY_BASE` têm padrão declarado em
  # `config/dev.exs` e `config/test.exs`. Isso é deliberado: exigir as variáveis ali
  # adicionaria atrito à inicialização local sem proteger nada, porque o padrão de
  # desenvolvimento é público por construção e não alcança produção. Por isso a verificação
  # de FR-007 no roteiro de validação é executada com `MIX_ENV=prod`.
  database_url =
    Env.require_env!("DATABASE_URL", hint: "Formato esperado: ecto://USUARIO:SENHA@HOST/BASE")

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :the_band, TheBand.Repo,
    # ssl: true,
    url: database_url,
    pool_size: Env.get_env_integer("POOL_SIZE", 10),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  secret_key_base =
    Env.require_env!("SECRET_KEY_BASE", hint: "Gere um valor com: mix phx.gen.secret")

  # Sem padrão: `example.com` como padrão faria a plataforma gerar URLs erradas em silêncio.
  host = Env.require_env!("PHX_HOST", hint: "Ex.: the-band.example.org")

  config :the_band, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :the_band, TheBandWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :the_band, TheBandWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :the_band, TheBandWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
